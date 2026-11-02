package agent

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/hub"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

func transcriptLine(uuid, text string) string {
	b, _ := json.Marshal(map[string]any{"type": "user", "uuid": uuid, "timestamp": time.Now().UTC().Format(time.RFC3339Nano), "cwd": "/src/x", "sessionId": "s",
		"message": map[string]any{"role": "user", "content": text}})
	return string(b) + "\n"
}

func TestTranscriptsSyncToTheHubAndCatchUp(t *testing.T) {
	quiet := slog.New(slog.NewTextHandler(io.Discard, nil))
	st, err := store.Open(filepath.Join(t.TempDir(), "hub.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	h, err := hub.New(hub.Config{Token: "secret", Version: "test", Log: quiet, DataDir: t.TempDir(), HistoryRedact: true}, st)
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(h.Handler())
	defer srv.Close()

	projects := t.TempDir()
	id := "cccccccc-0000-4000-8000-000000000003"
	path := filepath.Join(projects, "-src-x", id+".jsonl")
	_ = os.MkdirAll(filepath.Dir(path), 0o755)
	_ = os.WriteFile(path, []byte(transcriptLine("u1", "first message")+transcriptLine("u2", "second message")+`{"type":"user","uuid":"u3","message":{"content":"half a li`), 0o644)
	sub := filepath.Join(projects, "-src-x", id, "subagents", "agent-1.jsonl")
	_ = os.MkdirAll(filepath.Dir(sub), 0o755)
	_ = os.WriteFile(sub, []byte(transcriptLine("s1", "subagent work")), 0o644)

	a, err := New(Config{HubURL: "ws" + strings.TrimPrefix(srv.URL, "http") + "/ws", Token: "secret", Node: "laptop", ProjectsDir: projects,
		Claude: "true-not-installed", ScratchDir: filepath.Join(t.TempDir(), "scratch"), Log: quiet})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := a.index.Scan(); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = a.session(ctx) }()

	page := func(q string) *v1.HistoryPage {
		t.Helper()
		var p *v1.HistoryPage
		for i := 0; i < 100; i++ {
			p = &v1.HistoryPage{}
			rec := httptest.NewRecorder()
			req := httptest.NewRequest("GET", "/api/v1/history/sessions/"+id+q, nil)
			req.Header.Set("Authorization", "Bearer secret")
			h.Handler().ServeHTTP(rec, req)
			_ = protojson.Unmarshal(rec.Body.Bytes(), p)
			if len(p.Events) > 0 {
				return p
			}
			time.Sleep(50 * time.Millisecond)
		}
		return p
	}
	waitFor := func(n int, q string) *v1.HistoryPage {
		t.Helper()
		for i := 0; i < 100; i++ {
			if p := page(q); len(p.Events) >= n {
				return p
			}
			time.Sleep(50 * time.Millisecond)
		}
		return page(q)
	}

	// The connect asks for everything; the half-written line waits.
	p := waitFor(2, "")
	if len(p.Events) != 2 || p.Events[0].Text != "first message" || p.Events[1].Text != "second message" || p.Events[0].Node != "laptop" {
		t.Fatalf("after the first sync: %v", p.Events)
	}
	if p := waitFor(3, "?subagents=1"); len(p.Events) != 3 {
		t.Fatalf("the subagent's transcript wasn't synced: %v", p.Events)
	}

	// The line is finished and more is written: only the rest goes up.
	f, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o644)
	_, _ = f.WriteString(`ne"}}` + "\n" + transcriptLine("u4", "fourth with api_key=sk-test-1234567890abcdef"))
	f.Close()
	syncNow(t, h)
	p = waitFor(4, "")
	if len(p.Events) != 4 || p.Events[2].Text != "half a line" || !strings.Contains(p.Events[3].Text, "[REDACTED") {
		t.Fatalf("after appending: %v", p.Events)
	}

	// Compacted: the file now starts differently, so it goes again from the start.
	_ = os.WriteFile(path, []byte(transcriptLine("c1", "compacted summary")), 0o644)
	syncNow(t, h)
	time.Sleep(200 * time.Millisecond)
	p = page("")
	if len(p.Events) != 1 || p.Events[0].Text != "compacted summary" {
		t.Fatalf("after a rewrite: %v", p.Events)
	}
}

// syncNow has the hub ask the agent to sync, as it does every few minutes.
func syncNow(t *testing.T, h *hub.Hub) {
	t.Helper()
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/api/v1/history/sync", nil)
	req.Header.Set("Authorization", "Bearer secret")
	h.Handler().ServeHTTP(rec, req)
	if rec.Code != 200 {
		t.Fatalf("sync: %d %s", rec.Code, rec.Body)
	}
}
