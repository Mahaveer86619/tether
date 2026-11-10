package hub

import (
	"crypto/rand"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/Mahaveer86619/tether/server/internal/store"
)

// The files a remote project needs that git must not hold: .env, config.json
// and the like. They are sealed in the hub like the codebase vault, written
// from the app or tetherctl, and handed to a device only when the owner has
// allowed that device for that project. See docs/plans/remote-projects.md.

const maxProjectFile = 256 << 10

type projectFileInfo struct {
	Path      string   `json:"path"`
	Keys      []string `json:"keys,omitempty"`
	UpdatedMs int64    `json:"updated_ms"`
}

type projectFileContent struct {
	Path    string `json:"path"`
	Content string `json:"content"`
}

func (h *Hub) projectFileRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/projects/{repo}/files", h.authed(h.projectFilesList))
	mux.HandleFunc("PUT /api/v1/projects/{repo}/files", h.authed(h.projectFilePut))
	mux.HandleFunc("DELETE /api/v1/projects/{repo}/files", h.authed(h.projectFileDelete))
	mux.HandleFunc("GET /api/v1/projects/{repo}/files/content", h.projectFilesContent)
	mux.HandleFunc("GET /api/v1/projects/{repo}/devices", h.authed(h.projectDevices))
	mux.HandleFunc("POST /api/v1/projects/{repo}/devices", h.authed(h.projectDeviceSet))
}

func cleanProjectPath(p string) (string, bool) {
	p = strings.ReplaceAll(strings.TrimSpace(p), `\`, "/")
	if p == "" || strings.HasPrefix(p, "/") || strings.Contains(p, ":") || strings.Contains("/"+p+"/", "/../") || strings.HasPrefix(p, ".git/") || p == ".git" {
		return "", false
	}
	return p, true
}

func (h *Hub) internalErr(w http.ResponseWriter, err error) {
	h.log.Warn("project files", "err", err)
	writeError(w, &opError{"internal", "the vault could not do that", http.StatusInternalServerError})
}

// projectFilesList names the files and the keys in them, never a value.
func (h *Hub) projectFilesList(w http.ResponseWriter, r *http.Request) {
	repo := r.PathValue("repo")
	if !repoID.MatchString(repo) {
		writeError(w, invalid("unknown project"))
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	files, err := h.store.ProjectFiles(repo)
	if err != nil {
		h.internalErr(w, err)
		return
	}
	key, err := h.secretsKey()
	if err != nil {
		h.internalErr(w, err)
		return
	}
	gcm, err := newGCM(key)
	if err != nil {
		h.internalErr(w, err)
		return
	}
	out := []projectFileInfo{}
	for _, f := range files {
		info := projectFileInfo{Path: f.Path, UpdatedMs: f.UpdatedMs}
		if plain, err := gcm.Open(nil, f.Nonce, f.Sealed, []byte(repo+"/"+f.Path)); err == nil {
			for _, k := range envKeys(key, string(plain)) {
				info.Keys = append(info.Keys, k.Name)
			}
		}
		out = append(out, info)
	}
	writeJSONPlain(w, http.StatusOK, map[string]any{"files": out})
}

func (h *Hub) projectFilePut(w http.ResponseWriter, r *http.Request) {
	repo := r.PathValue("repo")
	var in projectFileContent
	if !repoID.MatchString(repo) || json.NewDecoder(http.MaxBytesReader(w, r.Body, maxProjectFile+4096)).Decode(&in) != nil {
		writeError(w, invalid("a project and a file are required"))
		return
	}
	path, ok := cleanProjectPath(in.Path)
	if !ok || len(in.Content) > maxProjectFile {
		writeError(w, invalid("the path must be inside the project, and the file under 256 KB"))
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	key, err := h.secretsKey()
	if err != nil {
		h.internalErr(w, err)
		return
	}
	gcm, err := newGCM(key)
	if err != nil {
		h.internalErr(w, err)
		return
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		h.internalErr(w, err)
		return
	}
	sealed := gcm.Seal(nil, nonce, []byte(in.Content), []byte(repo+"/"+path))
	if err := h.store.PutProjectFile(store.SealedFile{Repo: repo, Path: path, Nonce: nonce, Sealed: sealed, UpdatedMs: time.Now().UnixMilli()}); err != nil {
		h.internalErr(w, err)
		return
	}
	h.audit(clientName(r), "project-file", repo+"/"+path, "stored", true)
	writeJSONPlain(w, http.StatusOK, map[string]any{"ok": true, "path": path})
}

func (h *Hub) projectFileDelete(w http.ResponseWriter, r *http.Request) {
	repo := r.PathValue("repo")
	path, ok := cleanProjectPath(r.URL.Query().Get("path"))
	if !repoID.MatchString(repo) || !ok {
		writeError(w, invalid("a project and a file are required"))
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if err := h.store.DeleteProjectFile(repo, path); err != nil {
		h.internalErr(w, err)
		return
	}
	h.audit(clientName(r), "project-file", repo+"/"+path, "deleted", true)
	writeJSONPlain(w, http.StatusOK, map[string]any{"ok": true})
}

// projectFilesContent hands a project's files, values and all, to a device
// the owner has allowed: for the agent that has just pulled the project.
func (h *Hub) projectFilesContent(w http.ResponseWriter, r *http.Request) {
	id, aerr := h.auth(r, true)
	if aerr != nil {
		writeError(w, aerr)
		return
	}
	repo := r.PathValue("repo")
	node := r.URL.Query().Get("node")
	if id.kind == kindNode && id.device != nil {
		node = id.device.Name
	}
	if !repoID.MatchString(repo) || node == "" {
		writeError(w, invalid("a project and a device are required"))
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	nodes, err := h.store.ProjectNodes(repo)
	if err != nil {
		h.internalErr(w, err)
		return
	}
	allowed := false
	for _, n := range nodes {
		allowed = allowed || n == node
	}
	if !allowed {
		writeError(w, &opError{"forbidden", node + " is not allowed to receive this project's files", http.StatusForbidden})
		return
	}
	files, err := h.store.ProjectFiles(repo)
	if err != nil {
		h.internalErr(w, err)
		return
	}
	key, err := h.secretsKey()
	if err != nil {
		h.internalErr(w, err)
		return
	}
	gcm, err := newGCM(key)
	if err != nil {
		h.internalErr(w, err)
		return
	}
	out := []projectFileContent{}
	for _, f := range files {
		plain, err := gcm.Open(nil, f.Nonce, f.Sealed, []byte(repo+"/"+f.Path))
		if err != nil {
			continue
		}
		out = append(out, projectFileContent{Path: f.Path, Content: string(plain)})
	}
	h.audit(node, "project-file", repo, "served", true)
	writeJSONPlain(w, http.StatusOK, map[string]any{"files": out})
}

func (h *Hub) projectDevices(w http.ResponseWriter, r *http.Request) {
	repo := r.PathValue("repo")
	h.mu.Lock()
	defer h.mu.Unlock()
	nodes, err := h.store.ProjectNodes(repo)
	if err != nil {
		h.internalErr(w, err)
		return
	}
	writeJSONPlain(w, http.StatusOK, map[string]any{"nodes": nodes})
}

func (h *Hub) projectDeviceSet(w http.ResponseWriter, r *http.Request) {
	repo := r.PathValue("repo")
	var in struct {
		Node  string `json:"node"`
		Allow bool   `json:"allow"`
	}
	if !repoID.MatchString(repo) || json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBody)).Decode(&in) != nil || in.Node == "" {
		writeError(w, invalid("a project and a device are required"))
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if err := h.store.SetProjectNode(repo, in.Node, in.Allow); err != nil {
		h.internalErr(w, err)
		return
	}
	h.audit(clientName(r), "project-device", repo+"/"+in.Node, map[bool]string{true: "allowed", false: "revoked"}[in.Allow], true)
	writeJSONPlain(w, http.StatusOK, map[string]any{"ok": true})
}

