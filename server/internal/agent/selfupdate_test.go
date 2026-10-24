package agent

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestSelfUpdateSwapsTheBinaryAndKeepsThePrevious(t *testing.T) {
	quiet := slog.New(slog.NewTextHandler(io.Discard, nil))
	dir := t.TempDir()
	exe := filepath.Join(dir, "tether-agent")
	if err := os.WriteFile(exe, []byte("old"), 0o755); err != nil {
		t.Fatal(err)
	}
	newBin := []byte("new binary")
	sum := sha256.Sum256(newBin)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer secret" || r.URL.Path != "/api/v1/updates/files/0.18.0/tether-agent-linux-amd64" {
			http.Error(w, "no", http.StatusNotFound)
			return
		}
		_, _ = w.Write(newBin)
	}))
	defer srv.Close()
	runCheck = func(string, string) error { return nil }
	defer func() { runCheck = checkRuns }()

	restarted := false
	a := &Agent{cfg: Config{HubURL: "ws" + srv.URL[len("http"):] + "/ws", Token: "secret", Version: "0.17.0", Log: quiet,
		SelfUpdate: true, Exe: exe, Restart: func() { restarted = true }}, log: quiet, runs: map[string]*run{}}
	u := &v1.AgentCommand_SelfUpdate{Version: "0.18.0", Asset: &v1.UpdateAsset{
		Name: "tether-agent-linux-amd64", Url: "/api/v1/updates/files/0.18.0/tether-agent-linux-amd64", Sha256: hex.EncodeToString(sum[:]),
	}}

	// Busy with a headless run: nothing happens.
	a.runs["s"] = &run{}
	a.selfUpdate(u)
	if restarted {
		t.Fatal("updated while a session was running")
	}
	delete(a.runs, "s")

	a.selfUpdate(u)
	if !restarted {
		t.Fatal("no restart after the update")
	}
	if b, _ := os.ReadFile(exe); string(b) != "new binary" {
		t.Fatalf("exe is %q", b)
	}
	if b, _ := os.ReadFile(exe + ".prev"); string(b) != "old" {
		t.Fatalf("prev is %q", b)
	}

	// A wrong checksum is refused and leaves the binary alone.
	restarted = false
	u.Asset.Sha256 = "00"
	a.selfUpdate(u)
	if restarted {
		t.Fatal("restarted after a bad download")
	}
	if b, _ := os.ReadFile(exe); string(b) != "new binary" {
		t.Fatalf("exe changed to %q", b)
	}

	// A binary that doesn't run is refused too.
	u.Asset.Sha256 = hex.EncodeToString(sum[:])
	runCheck = func(string, string) error { return errors.New("exec format error") }
	a.selfUpdate(u)
	if restarted {
		t.Fatal("restarted with a binary that doesn't run")
	}
}

func TestAnUpdateThatKeepsFailingIsRolledBack(t *testing.T) {
	quiet := slog.New(slog.NewTextHandler(io.Discard, nil))
	dir := t.TempDir()
	exe := filepath.Join(dir, "tether-agent")
	_ = os.WriteFile(exe, []byte("new"), 0o755)
	_ = os.WriteFile(exe+".prev", []byte("old"), 0o755)
	_ = os.WriteFile(markerPath(exe), []byte(`{"from":"0.17.0","to":"0.18.0"}`), 0o644)

	for i := 0; i < maxUpdateStarts; i++ {
		if CheckUpdate(exe, "0.18.0", quiet) {
			t.Fatalf("rolled back after %d starts", i+1)
		}
	}
	if !CheckUpdate(exe, "0.18.0", quiet) {
		t.Fatal("no rollback after too many starts")
	}
	if b, _ := os.ReadFile(exe); string(b) != "old" {
		t.Fatalf("exe is %q after the rollback", b)
	}
	if _, err := os.Stat(markerPath(exe)); !os.IsNotExist(err) {
		t.Fatal("the marker should be gone")
	}

	// Reaching the hub confirms an update.
	_ = os.WriteFile(markerPath(exe), []byte(`{"from":"0.17.0","to":"0.18.0"}`), 0o644)
	a := &Agent{cfg: Config{Exe: exe, Version: "0.18.0"}, log: quiet}
	a.commitUpdate()
	if CheckUpdate(exe, "0.18.0", quiet) {
		t.Fatal("rolled back a confirmed update")
	}
}
