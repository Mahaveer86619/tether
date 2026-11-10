package hub

import (
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/Mahaveer86619/tether/server/internal/gitsync"
)

func TestARepoIsServedToDevicesWithTheToken(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git is not installed")
	}
	srv := newTestHub(t)
	if code, _ := call(t, srv, "POST", "/api/v1/repos", "", `{"id":"tether"}`); code != http.StatusUnauthorized {
		t.Fatalf("no token: %d", code)
	}
	if code, _ := call(t, srv, "POST", "/api/v1/repos", "secret", `{"id":"../x"}`); code != http.StatusBadRequest {
		t.Fatalf("a bad id: %d", code)
	}
	code, body := call(t, srv, "POST", "/api/v1/repos", "secret", `{"id":"tether"}`)
	if code != http.StatusOK {
		t.Fatalf("create: %d %s", code, body)
	}
	if code, _ := call(t, srv, "POST", "/api/v1/repos", "secret", `{"id":"tether"}`); code != http.StatusOK {
		t.Fatalf("creating twice: %d", code)
	}
	if code, _ := call(t, srv, "GET", "/git/tether.git/info/refs?service=git-upload-pack", "", ""); code != http.StatusUnauthorized {
		t.Fatalf("reading without a token: %d", code)
	}
	if code, _ := call(t, srv, "GET", "/git/nothere.git/info/refs?service=git-upload-pack", "secret", ""); code != http.StatusNotFound {
		t.Fatalf("a repo that does not exist: %d", code)
	}

	remote := gitsync.Remote{URL: srv.URL + "/git/tether.git", Token: "secret"}
	a, b := t.TempDir(), t.TempDir()
	if err := os.WriteFile(filepath.Join(a, "main.go"), []byte("package main"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := gitsync.Snapshot(a, "chat-1", "first"); err != nil {
		t.Fatal(err)
	}
	if err := gitsync.Push(a, remote, "chat-1"); err != nil {
		t.Fatalf("push over the hub: %v", err)
	}
	if err := gitsync.Pull(b, remote, "chat-1"); err != nil {
		t.Fatalf("pull over the hub: %v", err)
	}
	if got, _ := os.ReadFile(filepath.Join(b, "main.go")); string(got) != "package main" {
		t.Fatalf("the code did not arrive: %q", got)
	}
	if err := gitsync.Push(a, gitsync.Remote{URL: remote.URL, Token: "wrong"}, "chat-1"); err == nil {
		t.Fatal("a push with a wrong token went through")
	}
}
