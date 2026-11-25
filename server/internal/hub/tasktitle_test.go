package hub

import (
	"strings"
	"testing"
)

func TestATaskSessionIsTitledByTheLeadOrFromItsPromptNeverByItsWholeMessage(t *testing.T) {
	if got := taskTitle("  Run   the sync check ", "long prompt"); got != "Run the sync check" {
		t.Fatalf("given title: %q", got)
	}
	if got := taskTitle(strings.Repeat("word ", 30), "x"); len([]rune(got)) > 61 || !strings.HasSuffix(got, "…") {
		t.Fatalf("a long given title is cut: %q", got)
	}
	long := "Please clean up the repo and re-run step 7.\nThen report which files are older copies, with a table of paths and what each one is, and anything you did not touch."
	if got := taskTitle("", long); got != "Clean up the repo and re-run step 7" {
		t.Fatalf("made from the prompt: %q", got)
	}
}

func TestStartSessionFromAChatPassesTheTitleToTheAgent(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"lead","target":{"node":"laptop","cwd":"/src/tether"}}`)
	nextCommand(t, agent, ctx, isStart)
	out, err := h.mcpStartSession(map[string]any{"prompt": "a very long first message that must not become the title of the task", "title": "Check v2 sync", "node": "laptop", "cwd": "/src/tether", "chat": c.Id})
	if err != nil {
		t.Fatal(err)
	}
	start := nextCommand(t, agent, ctx, isStart).GetStart()
	if start.Name != "Check v2 sync" {
		t.Fatalf("start %v (%s)", start, out)
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if got := h.sessions[start.Session].Title; got != "Check v2 sync" {
		t.Fatalf("session title %q", got)
	}
}
