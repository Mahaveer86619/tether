package hub

import (
	"encoding/json"
	"net/http"
	"net/http/cgi"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

// Git repositories the hub keeps for remote projects (docs/plans/remote-projects.md).
// Each is a bare repository under <data>/repos, served to the owner's
// devices over HTTP by git's own http-backend, with the hub's token as the
// password: `git -c http.extraHeader="Authorization: Bearer <token>" clone
// <hub>/git/<id>.git`.

var repoID = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,62}$`)

func (h *Hub) reposDir() string { return filepath.Join(h.cfg.DataDir, "repos") }

// ensureRepo makes the bare repository for a project if there is not one,
// and returns its folder.
func (h *Hub) ensureRepo(id string) (string, error) {
	dir := filepath.Join(h.reposDir(), id+".git")
	if _, err := os.Stat(filepath.Join(dir, "HEAD")); err == nil {
		return dir, nil
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", err
	}
	for _, args := range [][]string{
		{"init", "--bare", "--initial-branch=main", dir},
		{"-C", dir, "config", "http.receivepack", "true"},
		{"-C", dir, "config", "http.uploadpack", "true"},
		{"-C", dir, "config", "receive.denyDeletes", "true"},
	} {
		if out, err := exec.Command("git", args...).CombinedOutput(); err != nil {
			return "", &gitError{args: args, out: strings.TrimSpace(string(out)), err: err}
		}
	}
	return dir, nil
}

type gitError struct {
	args []string
	out  string
	err  error
}

func (e *gitError) Error() string { return "git " + strings.Join(e.args, " ") + ": " + e.out + " (" + e.err.Error() + ")" }

func (h *Hub) repoRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v1/repos", h.repoCreate)
	mux.HandleFunc("/git/", h.repoServe)
}

// repoCreate makes a project's repository: {"id":"tether"} answers with the
// path to clone from.
func (h *Hub) repoCreate(w http.ResponseWriter, r *http.Request) {
	if _, err := h.auth(r, true); err != nil {
		writeError(w, err)
		return
	}
	var in struct {
		ID string `json:"id"`
	}
	if json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBody)).Decode(&in) != nil || !repoID.MatchString(in.ID) {
		writeError(w, invalid("id must be lowercase letters, digits and dashes"))
		return
	}
	if _, err := h.ensureRepo(in.ID); err != nil {
		h.log.Warn("repo", "id", in.ID, "err", err)
		writeError(w, &opError{"internal", "could not make the repository", http.StatusInternalServerError})
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"id": in.ID, "path": "/git/" + in.ID + ".git"})
}

// repoServe runs git's http-backend for /git/<id>.git/..., for a request
// with a token. The repository has to exist: push does not make one.
func (h *Hub) repoServe(w http.ResponseWriter, r *http.Request) {
	if _, err := h.auth(r, true); err != nil {
		writeError(w, err)
		return
	}
	id, _, _ := strings.Cut(strings.TrimPrefix(r.URL.Path, "/git/"), ".git")
	if !repoID.MatchString(id) {
		http.NotFound(w, r)
		return
	}
	if _, err := os.Stat(filepath.Join(h.reposDir(), id+".git", "HEAD")); err != nil {
		http.NotFound(w, r)
		return
	}
	gitPath, err := exec.LookPath("git")
	if err != nil {
		http.Error(w, "git is not installed on the hub", http.StatusServiceUnavailable)
		return
	}
	(&cgi.Handler{
		Path: gitPath,
		Args: []string{"http-backend"},
		Root: "/git",
		Env:  []string{"GIT_PROJECT_ROOT=" + h.reposDir(), "GIT_HTTP_EXPORT_ALL=1", "REMOTE_USER=tether"},
		Dir:  h.reposDir(),
	}).ServeHTTP(w, r)
}
