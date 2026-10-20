package agent

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"testing"
)

func TestBackupSendsOnlyChangedSessionsWithTheirSubagents(t *testing.T) {
	projects := filepath.Join(t.TempDir(), "projects")
	dir := filepath.Join(projects, "-work-app")
	if err := os.MkdirAll(filepath.Join(dir, "s1", "subagents"), 0o755); err != nil {
		t.Fatal(err)
	}
	line := `{"type":"user","cwd":"/work/app","message":{"content":"hi"}}` + "\n"
	for _, id := range []string{"s1", "s2"} {
		if err := os.WriteFile(filepath.Join(dir, id+".jsonl"), []byte(line), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "s1", "subagents", "agent-a.jsonl"), []byte(line), 0o644); err != nil {
		t.Fatal(err)
	}

	var mu sync.Mutex
	var got []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		session, _ := url.QueryUnescape(r.Header.Get("X-Session"))
		path, _ := url.QueryUnescape(r.Header.Get("X-Path"))
		origin, _ := url.QueryUnescape(r.Header.Get("X-Origin"))
		_, _ = io.Copy(io.Discard, r.Body)
		mu.Lock()
		got = append(got, session+" "+origin+" "+path)
		mu.Unlock()
		w.WriteHeader(200)
	}))
	defer srv.Close()

	a := &Agent{cfg: Config{ProjectsDir: projects, HubURL: "ws" + strings.TrimPrefix(srv.URL, "http") + "/ws"},
		log: slog.New(slog.NewTextHandler(io.Discard, nil)), index: NewIndex(projects)}
	if _, err := a.index.Scan(); err != nil {
		t.Fatal(err)
	}
	// The hub already has s2 as it is.
	a.backup(map[string]int64{"s2": int64(len(line))})
	sort.Strings(got)
	want := []string{"s1 backup meta.json", "s1 backup subagents/agent-a.jsonl", "s1 backup transcript"}
	if strings.Join(got, "|") != strings.Join(want, "|") {
		t.Fatalf("uploads: %q", got)
	}

	got = nil
	a.backup(map[string]int64{"s1": int64(len(line)), "s2": int64(len(line))})
	if len(got) != 0 {
		t.Fatalf("nothing changed, nothing to send: %q", got)
	}
}
