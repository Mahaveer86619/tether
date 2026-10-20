package agent

import (
	"io"
	"log/slog"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/hub"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

func write(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestSnapshotAndRestoreACodebaseWithItsEnvFiles(t *testing.T) {
	quiet := slog.New(slog.NewTextHandler(io.Discard, nil))
	st, err := store.Open(filepath.Join(t.TempDir(), "hub.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	data := t.TempDir()
	h, err := hub.New(hub.Config{Token: "secret", Version: "test", Log: quiet, DataDir: data}, st)
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(h.Handler())
	defer srv.Close()

	root := t.TempDir()
	code := filepath.Join(root, "shop")
	write(t, filepath.Join(code, "server", "main.go"), "package main\n")
	write(t, filepath.Join(code, "server", ".env"), "DB_URL=postgres://u:p@db/shop\n# a comment\nexport API_KEY=\"k-123\"\n")
	write(t, filepath.Join(code, "web", "index.html"), "<h1>shop</h1>")
	write(t, filepath.Join(code, "web", ".env.local"), "NEXT_PUBLIC_API=http://localhost:8080\n")
	write(t, filepath.Join(code, "web", ".env.example"), "NEXT_PUBLIC_API=\n")
	write(t, filepath.Join(code, "web", "node_modules", "react", "index.js"), "module.exports = {}")

	a, err := New(Config{HubURL: "ws" + strings.TrimPrefix(srv.URL, "http") + "/ws", Token: "secret", Node: "laptop", ScratchDir: filepath.Join(t.TempDir(), "scratch"), Log: quiet})
	if err != nil {
		t.Fatal(err)
	}
	c := &v1.Codebase{Id: "cb1", Node: "laptop", Path: code, Name: "shop"}
	if err := st.PutCodebase(c); err != nil {
		t.Fatal(err)
	}
	if err := a.snapshot(c, ""); err != nil {
		t.Fatal(err)
	}

	// The codebase got its Tether files.
	if _, err := os.Stat(filepath.Join(code, ".tetherignore")); err != nil {
		t.Fatal("a default .tetherignore should be written")
	}
	if b, _ := os.ReadFile(filepath.Join(code, ".tether", "codebase.json")); !strings.Contains(string(b), `"cb1"`) {
		t.Fatalf("codebase.json: %s", b)
	}

	// Apps see the codebase and its .env keys, never their values.
	req := httptest.NewRequest("GET", "/api/v1/codebases", nil)
	req.Header.Set("Authorization", "Bearer secret")
	rec := httptest.NewRecorder()
	h.Handler().ServeHTTP(rec, req)
	if strings.Contains(rec.Body.String(), "postgres://") || strings.Contains(rec.Body.String(), "k-123") {
		t.Fatalf("a value leaked: %s", rec.Body)
	}
	list := &v1.CodebaseList{}
	if err := protojson.Unmarshal(rec.Body.Bytes(), list); err != nil || len(list.Codebases) != 1 {
		t.Fatalf("codebases: %s", rec.Body)
	}
	got := list.Codebases[0]
	if got.Snapshot == "" || got.Files != 5 { // main.go, index.html, .env.example, .tetherignore, .tether/codebase.json
		t.Fatalf("want a snapshot of 5 files, got %d (%v)", got.Files, got)
	}
	if len(got.Env) != 2 || got.Env[0].Path != "server/.env" || len(got.Env[0].Keys) != 2 || got.Env[0].Keys[1].Name != "API_KEY" {
		t.Fatalf("env: %v", got.Env)
	}

	// The hub's machine restores it, .env files included, where they were.
	dir := filepath.Join(t.TempDir(), "cb1")
	if err := a.restoreCodebase("cb1", got.Snapshot, dir); err != nil {
		t.Fatal(err)
	}
	for rel, want := range map[string]string{
		"server/main.go":   "package main\n",
		"web/index.html":   "<h1>shop</h1>",
		"server/.env":      "DB_URL=postgres://u:p@db/shop\n# a comment\nexport API_KEY=\"k-123\"\n",
		"web/.env.local":   "NEXT_PUBLIC_API=http://localhost:8080\n",
		"web/.env.example": "NEXT_PUBLIC_API=\n",
	} {
		if b, err := os.ReadFile(filepath.Join(dir, filepath.FromSlash(rel))); err != nil || string(b) != want {
			t.Errorf("%s: %q, %v", rel, b, err)
		}
	}
	if _, err := os.Stat(filepath.Join(dir, "web", "node_modules")); err == nil {
		t.Error("ignored folders must not be copied")
	}

	// A second snapshot sends only what changed, and a restore removes what's gone.
	if err := os.Remove(filepath.Join(code, "web", "index.html")); err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(code, "server", "util.go"), "package main\n// util\n")
	if err := a.snapshot(c, ""); err != nil {
		t.Fatal(err)
	}
	cs, _ := st.Codebases()
	if err := a.restoreCodebase("cb1", cs[0].Snapshot, dir); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "web", "index.html")); err == nil {
		t.Error("a file deleted at the source should go from the copy")
	}
	if _, err := os.Stat(filepath.Join(dir, "server", "util.go")); err != nil {
		t.Error("a new file should be restored")
	}
	if snaps, _ := st.Snapshots("cb1", 10); len(snaps) != 2 || snaps[0].Parent != snaps[1].Id {
		t.Errorf("want two snapshots in a chain, got %v", snaps)
	}
}
