package hub

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

// Codebases the hub keeps copies of, their snapshots, and the .env vault;
// see docs/plan.md#codebases-on-the-hub. Snapshot files live in the same
// content-addressed blob store as artifacts, so unchanged files are stored
// once however many snapshots list them.

const secretsKeyFile = "secrets.key"

// samePath compares folder paths from one node, ignoring case and slash
// direction for Windows paths.
func normPath(p string) string {
	p = strings.TrimRight(strings.ReplaceAll(p, `\`, "/"), "/")
	if len(p) > 1 && p[1] == ':' {
		p = strings.ToLower(p)
	}
	return p
}

// relPath is cwd relative to dir, with forward slashes, if cwd is inside it.
func relPath(dir, cwd string) (string, bool) {
	d, c := normPath(dir), normPath(cwd)
	if c == d {
		return "", true
	}
	if strings.HasPrefix(c, d+"/") {
		return strings.ReplaceAll(cwd, `\`, "/")[len(d)+1:], true
	}
	return "", false
}

// codebaseFor finds the codebase a folder on a node belongs to. A folder
// directly inside a workspace root, or below one, is registered as one the
// first time it's seen. Caller holds h.mu.
func (h *Hub) codebaseFor(node, cwd string) *v1.Codebase {
	if cwd == "" {
		return nil
	}
	list, err := h.store.Codebases()
	if err != nil {
		h.log.Error("list codebases", "err", err)
		return nil
	}
	var best *v1.Codebase
	for _, c := range list {
		if c.Node == node {
			if _, ok := relPath(c.Path, cwd); ok && (best == nil || len(c.Path) > len(best.Path)) {
				best = c
			}
		}
	}
	if best != nil {
		return best
	}
	for _, r := range h.workspaces().Roots {
		if r.Node != node {
			continue
		}
		rel, ok := relPath(r.Path, cwd)
		if !ok || rel == "" {
			continue
		}
		name, _, _ := strings.Cut(rel, "/")
		sep := "/"
		if strings.Contains(r.Path, `\`) {
			sep = `\`
		}
		c := &v1.Codebase{Id: uuid.NewString(), Node: node, Path: strings.TrimRight(r.Path, `\/`) + sep + name, Name: name, CreatedMs: time.Now().UnixMilli()}
		if err := h.store.PutCodebase(c); err != nil {
			h.log.Error("store codebase", "err", err)
			return nil
		}
		return c
	}
	return nil
}

func (h *Hub) codebase(id string) (*v1.Codebase, *opError) {
	list, err := h.store.Codebases()
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	for _, c := range list {
		if c.Id == id {
			return c, nil
		}
	}
	return nil, &opError{"not_found", "unknown codebase", http.StatusNotFound}
}

// codebases lists them for apps: keys of .env files, never their content.
// Caller holds h.mu.
func (h *Hub) codebases() (*v1.CodebaseList, *opError) {
	list, err := h.store.Codebases()
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	for _, c := range list {
		env, err := h.store.Env(c.Id)
		if err != nil {
			return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
		c.Env = nil
		for _, e := range env {
			c.Env = append(c.Env, e.Info)
		}
	}
	return &v1.CodebaseList{Codebases: list}, nil
}

// requestSnapshot asks the codebase's node to snapshot it. Caller holds h.mu.
func (h *Hub) requestSnapshot(c *v1.Codebase, session string) *opError {
	agent := h.agents[c.Node]
	if agent == nil {
		return errNodeOffline
	}
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Snapshot{Snapshot: &v1.AgentCommand_SnapshotCodebase{
		Codebase: proto.Clone(c).(*v1.Codebase), Session: session,
	}}}))
	return nil
}

// snapshotSession snapshots the codebase a session works in, if it has one,
// and remembers it on the session. Caller holds h.mu.
func (h *Hub) snapshotSession(info *v1.SessionInfo) {
	c := h.codebaseFor(info.Node, info.Cwd)
	if c == nil {
		return
	}
	if info.Codebase != c.Id {
		n := proto.Clone(info).(*v1.SessionInfo)
		n.Codebase = c.Id
		h.putSession(n)
	}
	if err := h.requestSnapshot(c, info.Id); err != nil {
		h.log.Warn("snapshot", "codebase", c.Name, "err", err.Message)
	}
}

// scanRoots asks a node to report the codebases under its workspace roots.
// Caller holds h.mu.
func (h *Hub) scanRoots(node string) {
	agent := h.agents[node]
	if agent == nil {
		return
	}
	var roots []string
	for _, r := range h.workspaces().Roots {
		if r.Node == node {
			roots = append(roots, r.Path)
		}
	}
	if len(roots) > 0 {
		agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Scan{Scan: &v1.AgentCommand_ScanCodebases{Roots: roots}}}))
	}
}

// foundCodebases registers what an agent's scan found, keeping existing
// entries (and their ids) and refreshing their git details. Caller holds h.mu.
func (h *Hub) foundCodebases(f *v1.FoundCodebases) *opError {
	list, err := h.store.Codebases()
	if err != nil {
		return &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	have := map[string]*v1.Codebase{}
	for _, c := range list {
		if c.Node == f.Node {
			have[normPath(c.Path)] = c
		}
	}
	for _, found := range f.Codebases {
		c := have[normPath(found.Path)]
		if c == nil {
			c = &v1.Codebase{Id: uuid.NewString(), Node: f.Node, Path: found.Path, CreatedMs: time.Now().UnixMilli()}
		}
		c.Name = firstNonEmpty(found.Name, filepath.Base(strings.ReplaceAll(found.Path, `\`, "/")))
		c.GitRemote, c.GitBranch, c.GitHead = found.GitRemote, found.GitBranch, found.GitHead
		if err := h.store.PutCodebase(c); err != nil {
			return &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
	}
	return nil
}

// missingBlobs answers a manifest with the hashes the hub doesn't have.
func (h *Hub) missingBlobs(m *v1.SnapshotManifest) *v1.MissingBlobs {
	out := &v1.MissingBlobs{}
	seen := map[string]bool{}
	for _, f := range m.Files {
		if seen[f.Sha256] {
			continue
		}
		seen[f.Sha256] = true
		if _, err := os.Stat(h.blobPath(f.Sha256)); err != nil {
			out.Sha256 = append(out.Sha256, f.Sha256)
		}
	}
	return out
}

var shaRe = regexp.MustCompile(`^[0-9a-f]{64}$`)

// putSnapshotBlob stores one file of a snapshot, checking it is what its
// hash says.
func (h *Hub) putSnapshotBlob(sha string, r io.Reader) *opError {
	if !shaRe.MatchString(sha) {
		return invalid("not a sha256")
	}
	_, _, err := h.putBlob(r, sha)
	return err
}

// recordSnapshot stores a snapshot once all its files are in. Caller holds h.mu.
func (h *Hub) recordSnapshot(c *v1.Codebase, m *v1.SnapshotManifest) (*v1.Snapshot, *opError) {
	if missing := h.missingBlobs(m); len(missing.Sha256) > 0 {
		return nil, invalid(fmt.Sprintf("%d files haven't been uploaded", len(missing.Sha256)))
	}
	sort.Slice(m.Files, func(i, j int) bool { return m.Files[i].Path < m.Files[j].Path })
	b, err := proto.Marshal(m)
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	sha, _, oerr := h.putBlob(bytes.NewReader(b), "")
	if oerr != nil {
		return nil, oerr
	}
	sn := &v1.Snapshot{
		Id: uuid.NewString(), Codebase: c.Id, Session: m.Session, Parent: c.Snapshot, CreatedMs: time.Now().UnixMilli(),
		Files: int32(len(m.Files)), GitHead: m.GitHead, Skipped: int32(len(m.Skipped)), ManifestSha256: sha,
	}
	for _, f := range m.Files {
		sn.Bytes += f.Size
	}
	if err := h.store.PutSnapshot(sn); err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	c.Snapshot, c.SnapshotMs, c.Files, c.Bytes, c.Error = sn.Id, sn.CreatedMs, sn.Files, sn.Bytes, ""
	c.GitRemote, c.GitBranch, c.GitHead = m.GitRemote, m.GitBranch, m.GitHead
	if err := h.store.PutCodebase(c); err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	if info := h.sessions[m.Session]; info != nil {
		n := proto.Clone(info).(*v1.SessionInfo)
		n.Codebase, n.Snapshot = c.Id, sn.Id
		h.putSession(n)
	}
	return sn, nil
}

func (h *Hub) manifest(snapshotID string) (*v1.SnapshotManifest, *opError) {
	sn, err := h.store.Snapshot(snapshotID)
	if err != nil || sn == nil {
		return nil, &opError{"not_found", "unknown snapshot", http.StatusNotFound}
	}
	b, err := os.ReadFile(h.blobPath(sn.ManifestSha256))
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	m := &v1.SnapshotManifest{}
	if err := proto.Unmarshal(b, m); err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	return m, nil
}

// ---- the .env vault ----

// secretsKey is the vault's key, made on first use and kept only on the hub
// machine.
func (h *Hub) secretsKey() ([]byte, error) {
	path := filepath.Join(h.cfg.DataDir, secretsKeyFile)
	if b, err := os.ReadFile(path); err == nil && len(b) == 32 {
		return b, nil
	}
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(h.cfg.DataDir, 0o700); err != nil {
		return nil, err
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		// Someone else just made it.
		if b, rerr := os.ReadFile(path); rerr == nil && len(b) == 32 {
			return b, nil
		}
		return nil, err
	}
	defer f.Close()
	if _, err := f.Write(key); err != nil {
		return nil, err
	}
	return key, nil
}

var envLine = regexp.MustCompile(`^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_.-]*)\s*=\s*(.*)$`)

// envKeys reads the key names of a .env file, each with a keyed hash of its
// value, so a change shows without the value.
func envKeys(key []byte, content string) []*v1.EnvKey {
	var out []*v1.EnvKey
	for _, line := range strings.Split(content, "\n") {
		m := envLine.FindStringSubmatch(strings.TrimRight(line, "\r"))
		if m == nil || strings.HasPrefix(strings.TrimSpace(line), "#") {
			continue
		}
		mac := hmac.New(sha256.New, key)
		mac.Write([]byte(m[1] + "=" + strings.TrimSpace(m[2])))
		out = append(out, &v1.EnvKey{Name: m[1], Fingerprint: hex.EncodeToString(mac.Sum(nil))[:8]})
	}
	return out
}

// storeEnv seals each .env file into the vault and drops the ones that are
// gone. Caller holds h.mu.
func (h *Hub) storeEnv(c *v1.Codebase, files *v1.EnvFiles) *opError {
	key, err := h.secretsKey()
	if err != nil {
		return &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	gcm, err := newGCM(key)
	if err != nil {
		return &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	var paths []string
	for _, f := range files.Files {
		p := strings.ReplaceAll(f.Path, `\`, "/")
		if p == "" || strings.HasPrefix(p, "/") || strings.Contains("/"+p+"/", "/../") {
			return invalid("env paths are relative to the codebase")
		}
		nonce := make([]byte, gcm.NonceSize())
		if _, err := rand.Read(nonce); err != nil {
			return &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
		info := &v1.EnvFile{Path: p, Keys: envKeys(key, f.Content), UpdatedMs: time.Now().UnixMilli()}
		sealed := gcm.Seal(nil, nonce, []byte(f.Content), []byte(c.Id+"/"+p))
		if err := h.store.PutEnv(c.Id, store.SealedEnv{Info: info, Nonce: nonce, Sealed: sealed}); err != nil {
			return &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
		paths = append(paths, p)
	}
	if err := h.store.DeleteEnvExcept(c.Id, paths); err != nil {
		return &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	return nil
}

// openEnv gives back a codebase's .env files, for its restore on the hub's
// machine only. Caller holds h.mu.
func (h *Hub) openEnv(c *v1.Codebase) (*v1.EnvFiles, *opError) {
	key, err := h.secretsKey()
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	gcm, err := newGCM(key)
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	sealed, err := h.store.Env(c.Id)
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	out := &v1.EnvFiles{}
	for _, e := range sealed {
		plain, err := gcm.Open(nil, e.Nonce, e.Sealed, []byte(c.Id+"/"+e.Info.Path))
		if err != nil {
			return nil, &opError{"internal", "a sealed .env file couldn't be opened: " + err.Error(), http.StatusInternalServerError}
		}
		f := proto.Clone(e.Info).(*v1.EnvFile)
		f.Content = string(plain)
		out.Files = append(out.Files, f)
	}
	return out, nil
}

func newGCM(key []byte) (cipher.AEAD, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	return cipher.NewGCM(block)
}

// ---- routes ----

// codebaseRoutes registers the codebase API. Apps list codebases and ask for
// snapshots; agents send manifests, files and .env files, and the hub's own
// agent reads them back to restore a codebase.
func (h *Hub) codebaseRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/codebases", h.api(func(r *http.Request) (proto.Message, *opError) {
		return h.codebases()
	}))
	mux.HandleFunc("POST /api/v1/codebases/{id}/snapshot", h.api(func(r *http.Request) (proto.Message, *opError) {
		c, err := h.codebase(r.PathValue("id"))
		if err != nil {
			return nil, err
		}
		return &v1.Ack{}, h.requestSnapshot(c, "")
	}))
	mux.HandleFunc("GET /api/v1/codebases/{id}/snapshots", h.api(func(r *http.Request) (proto.Message, *opError) {
		list, err := h.store.Snapshots(r.PathValue("id"), 100)
		if err != nil {
			return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
		return &v1.SnapshotList{Snapshots: list}, nil
	}))

	mux.HandleFunc("POST /api/v1/codebases/found", h.nodeAPI(func(r *http.Request, _ identity) (proto.Message, *opError) {
		f := &v1.FoundCodebases{}
		if err := decode(r, f); err != nil {
			return nil, err
		}
		return &v1.Ack{}, h.foundCodebases(f)
	}))
	mux.HandleFunc("POST /api/v1/codebases/{id}/manifest", h.nodeAPI(func(r *http.Request, _ identity) (proto.Message, *opError) {
		m := &v1.SnapshotManifest{}
		if err := decodeLarge(r, m); err != nil {
			return nil, err
		}
		return h.missingBlobs(m), nil
	}))
	mux.HandleFunc("POST /api/v1/codebases/{id}/snapshots", h.nodeAPI(func(r *http.Request, _ identity) (proto.Message, *opError) {
		c, err := h.codebase(r.PathValue("id"))
		if err != nil {
			return nil, err
		}
		m := &v1.SnapshotManifest{}
		if err := decodeLarge(r, m); err != nil {
			return nil, err
		}
		return h.recordSnapshot(c, m)
	}))
	mux.HandleFunc("POST /api/v1/codebases/{id}/error", h.nodeAPI(func(r *http.Request, _ identity) (proto.Message, *opError) {
		c, err := h.codebase(r.PathValue("id"))
		if err != nil {
			return nil, err
		}
		e := &v1.Error{}
		if err := decode(r, e); err != nil {
			return nil, err
		}
		c.Error = e.Message
		if err := h.store.PutCodebase(c); err != nil {
			return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
		return &v1.Ack{}, nil
	}))
	mux.HandleFunc("PUT /api/v1/codebases/{id}/env", h.nodeAPI(func(r *http.Request, _ identity) (proto.Message, *opError) {
		c, err := h.codebase(r.PathValue("id"))
		if err != nil {
			return nil, err
		}
		files := &v1.EnvFiles{}
		if err := decode(r, files); err != nil {
			return nil, err
		}
		return &v1.Ack{}, h.storeEnv(c, files)
	}))
	// Values leave the vault only for the agent on the hub's own machine.
	mux.HandleFunc("GET /api/v1/codebases/{id}/env/files", h.nodeAPI(func(r *http.Request, _ identity) (proto.Message, *opError) {
		if !localIP(remoteIP(r)) {
			return nil, &opError{"forbidden", ".env values are only given to the hub's own machine", http.StatusForbidden}
		}
		c, err := h.codebase(r.PathValue("id"))
		if err != nil {
			return nil, err
		}
		return h.openEnv(c)
	}))
	mux.HandleFunc("GET /api/v1/snapshots/{id}/manifest", h.nodeAPI(func(r *http.Request, _ identity) (proto.Message, *opError) {
		return h.manifest(r.PathValue("id"))
	}))
	mux.HandleFunc("PUT /api/v1/blobs/{sha}", func(w http.ResponseWriter, r *http.Request) {
		if _, err := h.auth(r, true); err != nil {
			writeError(w, err)
			return
		}
		// Written outside h.mu: blobs are content-addressed and land by rename.
		if err := h.putSnapshotBlob(r.PathValue("sha"), r.Body); err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, &v1.Ack{})
	})
	mux.HandleFunc("GET /api/v1/blobs/{sha}", func(w http.ResponseWriter, r *http.Request) {
		if _, err := h.auth(r, true); err != nil {
			writeError(w, err)
			return
		}
		sha := r.PathValue("sha")
		if !shaRe.MatchString(sha) {
			writeError(w, invalid("not a sha256"))
			return
		}
		http.ServeFile(w, r, h.blobPath(sha))
	})
}

// nodeAPI is h.api for routes agents call as well as apps.
func (h *Hub) nodeAPI(fn func(*http.Request, identity) (proto.Message, *opError)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := h.auth(r, true)
		if err != nil {
			writeError(w, err)
			return
		}
		h.mu.Lock()
		msg, err := fn(r, id)
		h.mu.Unlock()
		if err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, msg)
	}
}

// A manifest lists every file of a codebase, so it's allowed more than other bodies.
const maxManifest = 64 << 20

func decodeLarge(r *http.Request, m proto.Message) *opError {
	r.Body = http.MaxBytesReader(nil, r.Body, maxManifest)
	b, err := io.ReadAll(r.Body)
	if err != nil {
		return invalid("the manifest is too large")
	}
	if err := jsonIn.Unmarshal(b, m); err != nil {
		return invalid(err.Error())
	}
	return nil
}
