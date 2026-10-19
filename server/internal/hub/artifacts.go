package hub

import (
	"bytes"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"mime"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/render"
)

// The central artifact store: files sessions read or write, and files
// people attach. Content is stored once per SHA-256 under
// <data dir>/artifacts/<sha[:2]>/<sha>; the artifacts table holds the rest.
// Nothing deletes artifacts on its own: they outlive the files they came
// from, for the app and the second brain. See docs/plan.md.

const (
	defaultLinkTTL = time.Hour
	maxLinkTTL     = 7 * 24 * time.Hour
	linkKeyName    = "artifact_link_key"
)

func (h *Hub) blobPath(sha string) string {
	return filepath.Join(h.cfg.DataDir, "artifacts", sha[:2], sha)
}

// uploadArtifact serves POST /api/v1/artifacts. The body is the file, of
// any size; X-Name, X-Session, X-Origin, X-Path, X-Tool-Use-Id, X-Node and
// X-Note describe it, and X-Sha256, if set, must match it.
func (h *Hub) uploadArtifact(w http.ResponseWriter, r *http.Request, id identity) {
	a, oerr := artifactFromHeaders(r, id)
	if oerr != nil {
		writeError(w, oerr)
		return
	}
	sha, n, oerr := h.putBlob(r.Body, a.Sha256)
	if oerr != nil {
		writeError(w, oerr)
		return
	}
	a.Sha256, a.Size = sha, n
	h.mu.Lock()
	oerr = h.addArtifact(a)
	if oerr == nil && wantsDelivery(r) {
		h.deliverAttachment(a)
	}
	h.mu.Unlock()
	if oerr != nil {
		writeError(w, oerr)
		return
	}
	writeJSON(w, http.StatusOK, a)
}

// artifactFromHeaders reads what describes an upload; Sha256 is the hash
// the client expects, if it sent one.
func artifactFromHeaders(r *http.Request, id identity) (*v1.Artifact, *opError) {
	header := func(k string) string {
		v, _ := url.QueryUnescape(r.Header.Get(k))
		return strings.TrimSpace(v)
	}
	name := filepath.Base(strings.ReplaceAll(header("X-Name"), `\`, "/"))
	if name == "" || name == "." || name == "/" {
		return nil, invalid("X-Name is required")
	}
	want := strings.ToLower(header("X-Sha256"))
	if want != "" && !shaRe.MatchString(want) {
		return nil, invalid("X-Sha256 is not a sha256")
	}
	node := header("X-Node")
	if id.kind == kindNode {
		node = id.device.Name
	}
	return &v1.Artifact{
		Sha256: want, Name: name, Mime: mimeOf(r.Header.Get("Content-Type"), name),
		Session: header("X-Session"), Node: node, Origin: firstNonEmpty(header("X-Origin"), "upload"),
		Path: header("X-Path"), ToolUseId: header("X-Tool-Use-Id"), Note: header("X-Note"),
	}, nil
}

// wantsDelivery: X-Deliver asks for the file in the session's folder now,
// rather than with a later message.
func wantsDelivery(r *http.Request) bool { return r.Header.Get("X-Deliver") == "1" }

// putBlob stores content under its SHA-256, once. If want is set the
// content must hash to it.
func (h *Hub) putBlob(r io.Reader, want string) (string, int64, *opError) {
	dir := filepath.Join(h.cfg.DataDir, "artifacts")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", 0, internalError(err)
	}
	tmp, err := os.CreateTemp(dir, "upload-*")
	if err != nil {
		return "", 0, internalError(err)
	}
	defer os.Remove(tmp.Name())
	sum := sha256.New()
	n, err := io.Copy(io.MultiWriter(tmp, sum), r)
	if cerr := tmp.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return "", 0, writeFailure(err)
	}
	sha := hex.EncodeToString(sum.Sum(nil))
	if want != "" && sha != want {
		return "", 0, &opError{"checksum", "the file doesn't match its sha256; upload it again", http.StatusUnprocessableEntity}
	}
	if err := h.keepBlob(tmp.Name(), sha); err != nil {
		return "", 0, internalError(err)
	}
	return sha, n, nil
}

// keepBlob moves a finished file into the store, unless the store has that
// content already.
func (h *Hub) keepBlob(path, sha string) error {
	blob := h.blobPath(sha)
	if _, err := os.Stat(blob); err == nil {
		return os.Remove(path)
	}
	if err := os.MkdirAll(filepath.Dir(blob), 0o755); err != nil {
		return err
	}
	return os.Rename(path, blob)
}

func internalError(err error) *opError {
	return &opError{"internal", err.Error(), http.StatusInternalServerError}
}

// writeFailure tells a full disk apart from a client that went away.
func writeFailure(err error) *opError {
	if errors.Is(err, syscall.ENOSPC) {
		return &opError{"no_space", "the hub's disk is full", http.StatusInsufficientStorage}
	}
	return invalid("the upload was cut off: " + err.Error())
}

// addArtifact records stored content and tells every client. Caller holds
// h.mu.
func (h *Hub) addArtifact(a *v1.Artifact) *opError {
	a.Id, a.CreatedMs = uuid.NewString(), time.Now().UnixMilli()
	if err := h.store.PutArtifact(a); err != nil {
		return internalError(err)
	}
	h.broadcast(&v1.Frame{Body: &v1.Frame_ArtifactAdded{ArtifactAdded: proto.Clone(a).(*v1.Artifact)}})
	return nil
}

// deliverAttachment has the session's node fetch a file attached to it, so
// Claude can read it from the session's folder. Files sent with a message
// go with the message instead. Caller holds h.mu.
func (h *Hub) deliverAttachment(a *v1.Artifact) {
	if a.Session == "" {
		return
	}
	s := h.sessions[a.Session]
	if s == nil || s.Cwd == "" {
		return
	}
	if agent := h.agents[s.Node]; agent != nil {
		agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Fetch{Fetch: &v1.AgentCommand_FetchAttachment{
			Session: s.Id, Cwd: s.Cwd, Artifact: proto.Clone(a).(*v1.Artifact),
		}}}))
	}
}

func mimeOf(contentType, name string) string {
	mt := strings.TrimSpace(strings.Split(contentType, ";")[0])
	if mt == "" || mt == "application/octet-stream" {
		if byExt := mime.TypeByExtension(strings.ToLower(filepath.Ext(name))); byExt != "" {
			return byExt
		}
		return "application/octet-stream"
	}
	return mt
}

// Long messages go to the session as a file rather than as typed text:
// typing thousands of keys into a terminal is slow and can lose some.
const longMessage = 1500

// fileLongText stores a long message as an attachment and returns the short
// note to send instead, plus the attachment. Caller holds h.mu.
func (h *Hub) fileLongText(session, text string) (string, *v1.Artifact, *opError) {
	if len(text) <= longMessage {
		return text, nil, nil
	}
	name := "message-" + time.Now().Format("20060102-150405") + ".md"
	sha, n, err := h.putBlob(strings.NewReader(text), "")
	if err != nil {
		return "", nil, err
	}
	a := &v1.Artifact{Sha256: sha, Name: name, Mime: "text/markdown", Size: n, Session: session, Origin: "attachment"}
	if err := h.addArtifact(a); err != nil {
		return "", nil, err
	}
	return "My message is long, so it is in the attached file " + name + ". Read it and respond to it.", a, nil
}

var longNote = regexp.MustCompile(`^My message is long, so it is in the attached file (message-[\w-]+\.md)\. Read it and respond to it\.`)

// expandLongText puts a long message back in place of the note that was sent
// for it, so the chat shows what was written. Caller holds h.mu.
func (h *Hub) expandLongText(session string, items []*v1.TimelineItem) {
	for _, it := range items {
		u := it.GetUser()
		if u == nil || u.AttachmentId != "" {
			continue
		}
		m := longNote.FindStringSubmatch(u.Text)
		if m == nil {
			continue
		}
		list, err := h.store.Artifacts(session, 1000)
		if err != nil {
			continue
		}
		for _, a := range list {
			if a.Name != m[1] || a.Origin != "attachment" {
				continue
			}
			if b, err := os.ReadFile(h.blobPath(a.Sha256)); err == nil {
				u.Text, u.AttachmentId = string(b), a.Id
			}
			break
		}
	}
}

// artifactContent serves the file to a token holder, or to anyone with a
// valid signed link.
func (h *Hub) artifactContent(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if q := r.URL.Query(); q.Get("sig") != "" {
		exp, _ := strconv.ParseInt(q.Get("exp"), 10, 64)
		if time.Now().UnixMilli() > exp || !hmac.Equal([]byte(q.Get("sig")), []byte(h.sign(id, exp))) {
			writeError(w, &opError{"expired", "this link has expired or is not valid", http.StatusForbidden})
			return
		}
	} else if _, err := h.auth(r, true); err != nil {
		writeError(w, err)
		return
	}
	h.mu.Lock()
	a, err := h.store.Artifact(id)
	h.mu.Unlock()
	if err != nil || a == nil {
		writeError(w, &opError{"not_found", "unknown artifact", http.StatusNotFound})
		return
	}
	f, err := os.Open(h.blobPath(a.Sha256))
	if err != nil {
		writeError(w, &opError{"not_found", "the file is missing from the store", http.StatusNotFound})
		return
	}
	defer f.Close()
	disposition := "inline"
	if r.URL.Query().Get("download") == "1" {
		disposition = "attachment"
	}
	w.Header().Set("Content-Type", a.Mime)
	w.Header().Set("Content-Disposition", mime.FormatMediaType(disposition, map[string]string{"filename": a.Name}))
	// Content-addressed, so the hash is a strong validator: ServeContent
	// then answers Range and If-Range, which is how downloads resume.
	w.Header().Set("ETag", `"`+a.Sha256+`"`)
	w.Header().Set("X-Sha256", a.Sha256)
	w.Header().Set("Cache-Control", "private, max-age=31536000, immutable")
	http.ServeContent(w, r, a.Name, time.UnixMilli(a.CreatedMs), f)
}

// artifactLink signs a link to an artifact. Caller holds h.mu.
func (h *Hub) artifactLink(id string, ttl time.Duration) (*v1.ArtifactLink, *opError) {
	if a, err := h.store.Artifact(id); err != nil || a == nil {
		return nil, &opError{"not_found", "unknown artifact", http.StatusNotFound}
	}
	if ttl <= 0 {
		ttl = defaultLinkTTL
	}
	exp := time.Now().Add(min(ttl, maxLinkTTL)).UnixMilli()
	return &v1.ArtifactLink{
		Url:       fmt.Sprintf("/api/v1/artifacts/%s/content?exp=%d&sig=%s", id, exp, h.sign(id, exp)),
		ExpiresMs: exp,
	}, nil
}

// deleteArtifact removes an artifact, and its content if nothing else uses
// it. Caller holds h.mu.
func (h *Hub) deleteArtifact(id string) *opError {
	a, err := h.store.Artifact(id)
	if err != nil || a == nil {
		return &opError{"not_found", "unknown artifact", http.StatusNotFound}
	}
	shared, err := h.store.DeleteArtifact(id, a.Sha256)
	if err != nil {
		return &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	if !shared {
		_ = os.Remove(h.blobPath(a.Sha256))
	}
	return nil
}

// sign makes a link signature with a key the hub keeps in its database.
func (h *Hub) sign(id string, exp int64) string {
	h.keyOnce.Do(func() {
		key, _ := h.store.Get(linkKeyName)
		if len(key) == 0 {
			key = make([]byte, 32)
			_, _ = rand.Read(key)
			_ = h.store.Put(linkKeyName, key)
		}
		h.linkKey = key
	})
	m := hmac.New(sha256.New, h.linkKey)
	fmt.Fprintf(m, "%s|%d", id, exp)
	return hex.EncodeToString(m.Sum(nil))
}

// attachments looks up artifacts sent with a message. Caller holds h.mu.
func (h *Hub) attachments(ids []string) ([]*v1.Artifact, *opError) {
	var out []*v1.Artifact
	for _, id := range ids {
		a, err := h.store.Artifact(id)
		if err != nil || a == nil {
			return nil, &opError{"not_found", "unknown attachment " + id, http.StatusNotFound}
		}
		out = append(out, a)
	}
	return out, nil
}

// keepImages stores pictures pasted into user messages, linked to the
// message, once each. Caller holds h.mu.
func (h *Hub) keepImages(session, node string, images []render.Image) {
	for i, img := range images {
		sum := sha256.Sum256(img.Data)
		sha := hex.EncodeToString(sum[:])
		if has, err := h.store.HasArtifact(session, img.ItemID, sha); err != nil || has {
			continue
		}
		if _, _, err := h.putBlob(bytes.NewReader(img.Data), sha); err != nil {
			h.log.Error("store pasted image", "session", session, "err", err.Message)
			continue
		}
		ext := imageExt(img.Mime)
		a := &v1.Artifact{
			Sha256: sha, Name: fmt.Sprintf("pasted-image-%d%s", i+1, ext), Mime: firstNonEmpty(img.Mime, "image/png"), Size: int64(len(img.Data)),
			Session: session, Node: node, Origin: "attachment", ToolUseId: img.ItemID,
		}
		if err := h.addArtifact(a); err != nil {
			h.log.Error("record pasted image", "session", session, "err", err.Message)
		}
	}
}

// imageExt avoids mime's alphabetical first pick, which gives ".jfif" for JPEG.
func imageExt(m string) string {
	switch m {
	case "image/jpeg":
		return ".jpg"
	case "", "image/png":
		return ".png"
	}
	if exts, _ := mime.ExtensionsByType(m); len(exts) > 0 {
		return exts[len(exts)-1]
	}
	return ".png"
}
