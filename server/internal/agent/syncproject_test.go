package agent

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func vaultHub(t *testing.T, status int, files any) (*Agent, *int) {
	t.Helper()
	calls := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if r.Header.Get("Authorization") != "Bearer tok" || r.URL.Query().Get("node") != "minipc" || !strings.HasSuffix(r.URL.Path, "/projects/p-1/files/content") {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		w.WriteHeader(status)
		_ = json.NewEncoder(w).Encode(files)
	}))
	t.Cleanup(srv.Close)
	return &Agent{cfg: Config{HubURL: "ws" + strings.TrimPrefix(srv.URL, "http") + "/ws", Token: "tok", Node: "minipc", Log: slog.Default()}}, &calls
}

func TestAProjectsVaultFilesAreWrittenAndKeptOutOfGit(t *testing.T) {
	a, _ := vaultHub(t, 200, map[string]any{"files": []map[string]string{
		{"path": ".env", "content": "KEY=1"},
		{"path": "conf/config.json", "content": "{}"},
		{"path": "../escape", "content": "x"},
	}})
	dir := t.TempDir()
	if err := a.writeProjectFiles(dir, "p-1"); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(dir, ".env")); string(b) != "KEY=1" {
		t.Fatalf(".env: %q", b)
	}
	if b, _ := os.ReadFile(filepath.Join(dir, "conf", "config.json")); string(b) != "{}" {
		t.Fatalf("config.json: %q", b)
	}
	if _, err := os.Stat(filepath.Join(filepath.Dir(dir), "escape")); err == nil {
		t.Fatal("a path outside the folder was written")
	}
	ex, _ := os.ReadFile(filepath.Join(dir, ".git", "info", "exclude"))
	if !strings.Contains(string(ex), ".env") || !strings.Contains(string(ex), "conf/config.json") {
		t.Fatalf("the files are not excluded from git: %q", ex)
	}
}

func TestADeviceThatIsNotAllowedJustGetsTheCode(t *testing.T) {
	a, _ := vaultHub(t, 403, map[string]string{"code": "forbidden"})
	dir := t.TempDir()
	if err := a.writeProjectFiles(dir, "p-1"); err != nil {
		t.Fatalf("a refusal is not a failure: %v", err)
	}
	if _, err := os.Stat(filepath.Join(dir, ".env")); err == nil {
		t.Fatal("a file was written without permission")
	}
}
