package hub

import (
	"context"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func TestScreenAndKeysGoThroughTheNode(t *testing.T) {
	h, srv := newTestHubWith(t)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	agent, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	defer agent.Close(nil)
	_ = agent.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_AgentHello{AgentHello: &v1.AgentHello{Token: "secret", Status: &v1.NodeStatus{Node: "laptop"}}}})
	for i := 0; i < 50 && !h.agentOnline("laptop"); i++ {
		time.Sleep(10 * time.Millisecond)
	}
	next := func() *v1.AgentCommand {
		for {
			f, err := agent.Read(ctx)
			if err != nil {
				t.Fatal(err)
			}
			if c := f.GetAgentCommand(); c != nil && (c.GetKeys() != nil || c.GetCapture() != nil) {
				return c
			}
		}
	}

	if status, body := call(t, srv, "POST", "/api/v1/sessions/s1/keys", "secret", `{"keys":["Down","Enter"],"text":"hi"}`); status != 200 {
		t.Fatalf("keys: %d %s", status, body)
	}
	if k := next().GetKeys(); k.Session != "s1" || strings.Join(k.Keys, ",") != "Down,Enter" || k.Text != "hi" {
		t.Fatalf("keys reached the node as %v", k)
	}
	if status, _ := call(t, srv, "POST", "/api/v1/sessions/s1/keys", "secret", `{}`); status != 400 {
		t.Fatalf("no keys should be refused, got %d", status)
	}

	got := make(chan string, 1)
	go func() {
		_, body := call(t, srv, "GET", "/api/v1/sessions/s1/screen", "secret", "")
		got <- body
	}()
	if c := next().GetCapture(); c.Session != "s1" {
		t.Fatalf("capture for %q", c.Session)
	}
	_ = agent.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_ScreenSnapshot{ScreenSnapshot: &v1.ScreenSnapshot{Session: "s1", Text: "❯ 1. Yes\n  2. No", CapturedMs: 5}}})
	snap := &v1.ScreenSnapshot{}
	if err := protojson.Unmarshal([]byte(<-got), snap); err != nil || snap.Text != "❯ 1. Yes\n  2. No" {
		t.Fatalf("screen: %v %v", snap, err)
	}

	// Another node can't post screens for this session.
	h.mu.Lock()
	h.noteScreen("minipc", &v1.ScreenSnapshot{Session: "s1", Text: "forged"})
	text := h.screens["s1"].Text
	h.sessions["s1"].Host = v1.SessionHost_SESSION_HOST_HEADLESS
	h.mu.Unlock()
	if text == "forged" {
		t.Fatal("a screen from the wrong node was kept")
	}
	if status, _ := call(t, srv, "POST", "/api/v1/sessions/s1/keys", "secret", `{"keys":["Enter"]}`); status != 400 {
		t.Fatalf("a headless run has no terminal, got %d", status)
	}
}

func TestPromptApprovalsHaveNoToolPreview(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.onAgent("laptop", &v1.Frame{Body: &v1.Frame_ApprovalRequested{ApprovalRequested: &v1.ApprovalRequest{
		ApprovalId: "p1", Session: "s1", Kind: v1.ApprovalRequest_KIND_PROMPT, ToolName: "Claude Code prompt",
		Options: []string{"Yes", "No"}, InputJson: "{}",
	}}})
	h.mu.Lock()
	defer h.mu.Unlock()
	if a := h.approvals["p1"]; a == nil || a.Preview != nil || len(a.Options) != 2 || a.Node != "laptop" {
		t.Fatalf("prompt approval: %v", a)
	}
}
