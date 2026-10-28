package agent

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

// Feeding the hub's central artifact store: files a session reads or writes
// that are worth keeping (images, documents, media) are uploaded, linked to
// the tool call; files attached in the app are fetched into the session's
// folder. Code files are left alone.

// maxUpload caps what's kept on its own from tool calls; files attached
// on purpose have no cap.
const maxUpload = 1 << 30

// stallTimeout ends a transfer that has moved no bytes for this long.
// Nothing caps a whole transfer: several GB can take hours.
const stallTimeout = 2 * time.Minute

var (
	// Read: what Claude looks at that isn't text the transcript already has.
	keepOnRead = extSet(".png .jpg .jpeg .gif .webp .bmp .pdf .mp3 .wav .m4a .ogg .mp4 .mov .webm")
	// Write: outputs, not source code.
	keepOnWrite = extSet(".png .jpg .jpeg .gif .webp .bmp .svg .pdf .html .htm .csv .xlsx .docx .pptx .mp3 .wav .m4a .ogg .mp4 .mov .webm")
)

func extSet(list string) map[string]bool {
	m := map[string]bool{}
	for _, e := range strings.Fields(list) {
		m[e] = true
	}
	return m
}

// noteToolFile uploads the file behind a finished Read or Write, if it's
// one worth keeping. Each version of a file is uploaded once.
func (a *Agent) noteToolFile(in hookInput) {
	var input struct {
		FilePath string `json:"file_path"`
	}
	if in.Event != "PostToolUse" || json.Unmarshal(in.ToolInput, &input) != nil || input.FilePath == "" {
		return
	}
	path := input.FilePath
	if !filepath.IsAbs(path) && in.Cwd != "" {
		path = filepath.Join(in.Cwd, path)
	}
	ext := strings.ToLower(filepath.Ext(path))
	origin, stored := "", path
	page, isPage := pagePath(path)
	switch {
	case isPage && (in.ToolName == "Write" || in.ToolName == "Edit" || in.ToolName == "MultiEdit"):
		origin, stored = "page", page
	case in.ToolName == "Read" && keepOnRead[ext]:
		origin = "read"
	case in.ToolName == "Write" && keepOnWrite[ext]:
		origin = "write"
	default:
		return
	}
	st, err := os.Stat(path)
	if err != nil || st.IsDir() {
		return
	}
	if st.Size() > maxUpload {
		a.log.Info("not keeping a large file", "path", path, "bytes", st.Size())
		return
	}
	key := fmt.Sprintf("%s|%s|%d|%d", in.SessionID, path, st.Size(), st.ModTime().UnixNano())
	a.mu.Lock()
	seen := a.uploaded[key]
	a.uploaded[key] = true
	a.mu.Unlock()
	if seen {
		return
	}
	go func() {
		if err := a.uploadFile(path, map[string]string{
			"X-Session": in.SessionID, "X-Origin": origin, "X-Path": stored, "X-Tool-Use-Id": in.ToolUseID,
		}); err != nil {
			a.log.Warn("upload artifact", "path", path, "err", err)
		}
	}()
}

// pagePath reports "<name>/<file>" for a file of a generated page, one
// under .tether/pages/<name>/ (see docs/plan.md#generated-pages).
func pagePath(path string) (string, bool) {
	p := strings.ReplaceAll(path, `\`, "/")
	_, rest, ok := strings.Cut(p, "/.tether/pages/")
	if !ok {
		return "", false
	}
	name, file, ok := strings.Cut(rest, "/")
	if !ok || name == "" || file == "" {
		return "", false
	}
	return name + "/" + file, true
}

func (a *Agent) hubRequest(ctx context.Context, method, path string, body io.Reader) (*http.Request, error) {
	req, err := http.NewRequestWithContext(ctx, method, wire.HTTPBase(a.cfg.HubURL)+path, body)
	if err != nil {
		return nil, err
	}
	if a.cfg.Token != "" {
		req.Header.Set("Authorization", "Bearer "+a.cfg.Token)
	}
	return req, nil
}

// hubClient has no overall timeout: large files take a while; callers set
// a deadline on the request instead.
func (a *Agent) hubClient() *http.Client {
	c := wire.HTTPClient(a.cfg.HubFingerprint)
	c.Timeout = 0
	return c
}

func (a *Agent) uploadFile(path string, headers map[string]string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return err
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	req, err := a.hubRequest(ctx, http.MethodPost, "/api/v1/artifacts", watchdog(f, cancel))
	if err != nil {
		return err
	}
	req.ContentLength = st.Size()
	req.Header.Set("X-Name", url.QueryEscape(filepath.Base(path)))
	req.Header.Set("X-Node", a.cfg.Node)
	for k, v := range headers {
		req.Header.Set(k, url.QueryEscape(v))
	}
	res, err := a.hubClient().Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(io.LimitReader(res.Body, 512))
		return fmt.Errorf("hub said %s: %s", res.Status, b)
	}
	return nil
}

// fetchAttachments downloads artifacts into <cwd>/.tether/attachments and
// returns the text to add to the message, which lists their paths.
func (a *Agent) fetchAttachments(cwd string, list []*v1.Artifact) (string, error) {
	if len(list) == 0 {
		return "", nil
	}
	dir := filepath.Join(cwd, ".tether", "attachments")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	var paths []string
	for _, art := range list {
		name := filepath.Base(strings.ReplaceAll(art.Name, `\`, "/"))
		dst := filepath.Join(dir, name)
		if err := a.fetchArtifact(art, dst); err != nil {
			return "", fmt.Errorf("fetch %s: %w", name, err)
		}
		paths = append(paths, "- "+filepath.ToSlash(filepath.Join(".tether", "attachments", name)))
	}
	return "\n\nAttached files (in this folder):\n" + strings.Join(paths, "\n"), nil
}

// fetchAttachment puts a file attached to a session in its folder.
func (a *Agent) fetchAttachment(f *v1.AgentCommand_FetchAttachment) {
	cwd := firstNonEmpty(a.index.Cwd(f.Session), f.Cwd)
	if st, err := os.Stat(cwd); err != nil || !st.IsDir() {
		a.log.Warn("fetch attachment: no folder for the session", "session", f.Session, "cwd", cwd)
		return
	}
	if _, err := a.fetchAttachments(cwd, []*v1.Artifact{f.Artifact}); err != nil {
		a.log.Warn("fetch attachment", "session", f.Session, "err", err)
		return
	}
	a.log.Info("fetched attachment", "session", f.Session, "name", f.Artifact.Name, "bytes", f.Artifact.Size)
}

// fetchArtifact downloads an artifact to dst unless dst already holds it.
func (a *Agent) fetchArtifact(art *v1.Artifact, dst string) error {
	if st, err := os.Stat(dst); err == nil && st.Size() == art.Size && art.Sha256 != "" {
		if sum, err := fileSHA256(dst); err == nil && sum == art.Sha256 {
			return nil
		}
	}
	return a.download(art.Id, art.Sha256, dst)
}

// download fetches an artifact into dst+".part", resuming after a broken
// connection, then checks it against sha (if known) and moves it into place.
func (a *Agent) download(id, sha, dst string) error {
	part := dst + ".part"
	var err error
	for attempt := range 6 {
		if attempt > 0 {
			time.Sleep(time.Duration(attempt) * 2 * time.Second)
		}
		var retry bool
		if retry, err = a.downloadPart(id, sha, part); err == nil || !retry {
			break
		}
		a.log.Info("download interrupted, resuming", "artifact", id, "err", err)
	}
	if err != nil {
		return err
	}
	if sha != "" {
		got, err := fileSHA256(part)
		if err != nil {
			return err
		}
		if got != sha {
			_ = os.Remove(part)
			return fmt.Errorf("downloaded file doesn't match its sha256")
		}
	}
	return os.Rename(part, dst)
}

// downloadPart appends what part lacks, and reports whether a failure is
// worth retrying.
func (a *Agent) downloadPart(id, sha, part string) (bool, error) {
	var have int64
	if st, err := os.Stat(part); err == nil {
		have = st.Size()
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	req, err := a.hubRequest(ctx, http.MethodGet, "/api/v1/artifacts/"+url.PathEscape(id)+"/content", nil)
	if err != nil {
		return false, err
	}
	if have > 0 && sha != "" {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-", have))
		req.Header.Set("If-Range", `"`+sha+`"`)
	}
	res, err := a.hubClient().Do(req)
	if err != nil {
		return true, err
	}
	defer res.Body.Close()
	flags := os.O_WRONLY | os.O_CREATE
	switch res.StatusCode {
	case http.StatusPartialContent:
		flags |= os.O_APPEND
	case http.StatusOK:
		flags |= os.O_TRUNC
	case http.StatusRequestedRangeNotSatisfiable:
		// part is already whole.
		return false, nil
	default:
		return res.StatusCode >= 500, fmt.Errorf("hub said %s", res.Status)
	}
	f, err := os.OpenFile(part, flags, 0o644)
	if err != nil {
		return false, err
	}
	_, err = io.Copy(f, watchdog(res.Body, cancel))
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	return err != nil, err
}

func fileSHA256(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// watchdog calls cancel once r has given no bytes for stallTimeout.
func watchdog(r io.Reader, cancel context.CancelFunc) io.Reader {
	return &stallReader{r: r, t: time.AfterFunc(stallTimeout, cancel)}
}

type stallReader struct {
	r io.Reader
	t *time.Timer
}

func (s *stallReader) Read(p []byte) (int, error) {
	n, err := s.r.Read(p)
	if n > 0 {
		s.t.Reset(stallTimeout)
	}
	if err != nil {
		s.t.Stop()
	}
	return n, err
}

// Claude Code keeps a folder's sessions in ~/.claude/projects/<the folder's
// path with every character but letters and digits turned into "-">.
var notAlnum = regexp.MustCompile(`[^a-zA-Z0-9]`)

// restoreTranscript puts a transcript copy where Claude Code looks for
// session id when it runs in cwd, so --resume finds it.
func (a *Agent) restoreTranscript(artifact, cwd, id string) error {
	dir := filepath.Join(a.cfg.ProjectsDir, notAlnum.ReplaceAllString(cwd, "-"))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	return a.download(artifact, "", filepath.Join(dir, id+".jsonl"))
}

// uploadTranscript sends a session's whole transcript to the artifact
// store, for a global session.
func (a *Agent) uploadTranscript(session string) {
	path := a.index.Path(session)
	if path == "" {
		a.log.Warn("upload transcript: not indexed", "session", session)
		return
	}
	if err := a.uploadFile(path, map[string]string{"X-Session": session, "X-Origin": "transcript"}); err != nil {
		a.log.Warn("upload transcript", "session", session, "err", err)
	}
}

// forgetScratch deletes a hub session's scratch folder and transcript. It
// only ever deletes inside the scratch folder.
func (a *Agent) forgetScratch(session string) {
	cwd := a.index.Cwd(session)
	rel, err := filepath.Rel(a.cfg.ScratchDir, cwd)
	if cwd == "" || err != nil || rel == "." || strings.HasPrefix(rel, "..") {
		a.log.Warn("forget: not a scratch session", "session", session, "cwd", cwd)
		return
	}
	if err := os.RemoveAll(cwd); err != nil {
		a.log.Warn("forget: remove folder", "session", session, "err", err)
	}
	if path := a.index.Path(session); path != "" {
		_ = os.Remove(path)
	}
	a.log.Info("forgot scratch session", "session", session)
}
