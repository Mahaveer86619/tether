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

func TestForkRemembersWhereItCameFrom(t *testing.T) {
	h, srv := newTestHubWith(t)
	// The fork command goes to the session's node, so one must be connected.
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
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

	status, body := call(t, srv, "POST", "/api/v1/sessions/s1/messages", "secret", `{"text":"try another way","fork":true}`)
	ack := &v1.Ack{}
	if status != 200 || protojson.Unmarshal([]byte(body), ack) != nil || ack.Session == "s1" {
		t.Fatalf("fork: %d %s", status, body)
	}

	h.mu.Lock()
	fork := h.sessions[ack.Session]
	h.mu.Unlock()
	// The test hub's s1 timeline ends with item "b".
	if fork.Parent != "s1" || fork.ForkPoint != "b" || fork.Lineage != "fork" {
		t.Fatalf("lineage: %v", fork)
	}

	// The agent later reports the session without lineage; the hub keeps it.
	h.mu.Lock()
	h.mergeSession(&v1.SessionInfo{Id: ack.Session, Node: "laptop", Title: "renamed"})
	kept := h.sessions[ack.Session].Parent
	h.mu.Unlock()
	if kept != "s1" {
		t.Fatalf("an agent update dropped the parent: %q", kept)
	}

	_, body = call(t, srv, "GET", "/api/v1/sessions/s1/lineage", "secret", "")
	events := &v1.LineageEvents{}
	if err := protojson.Unmarshal([]byte(body), events); err != nil || len(events.Events) != 1 {
		t.Fatalf("events: %s", body)
	}
	if e := events.Events[0]; e.Kind != "fork" || e.Session != ack.Session || e.ForkPoint != "b" || e.By == "" {
		t.Fatalf("event: %v", e)
	}
}

func (h *Hub) agentOnline(node string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.agents[node] != nil
}

func TestScratchRetentionAndGlobalSessions(t *testing.T) {
	h, srv := newTestHubWith(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
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
			if c := f.GetAgentCommand(); c != nil && c.GetSyncHistory() == nil {
				return c
			}
		}
	}

	// The test agent connects from 127.0.0.1, so it is the hub's own node.
	if status, body := call(t, srv, "POST", "/api/v1/sessions", "secret", `{"prompt":"hello","scratch":true}`); status != 200 {
		t.Fatalf("scratch session: %d %s", status, body)
	}
	if start := next().GetStart(); !start.Scratch || start.Cwd != "" {
		t.Fatalf("a hub session runs in a scratch folder: %v", start)
	}

	now := time.Now()
	h.mu.Lock()
	h.putSession(&v1.SessionInfo{Id: "old", Node: "laptop", Scratch: true, UpdatedMs: now.Add(-20 * 24 * time.Hour).UnixMilli()})
	h.putSession(&v1.SessionInfo{Id: "ancient", Node: "laptop", Scratch: true, UpdatedMs: now.Add(-90 * 24 * time.Hour).UnixMilli()})
	h.applyRetention(now)
	archived := h.sessions["old"].Archived
	h.mu.Unlock()
	if !archived {
		t.Error("a scratch session idle for 20 days should be archived")
	}
	if f := next().GetForget(); f.GetSession() != "ancient" {
		t.Errorf("a scratch session idle for 90 days should be forgotten, got %v", f)
	}

	if status, body := call(t, srv, "POST", "/api/v1/sessions/s1/global", "secret", `{"global":true}`); status != 200 {
		t.Fatalf("global: %d %s", status, body)
	}
	if up := next().GetUploadTranscript(); up.GetSession() != "s1" {
		t.Fatalf("going global should ask for a transcript copy, got %v", up)
	}
	if status, _ := call(t, srv, "POST", "/api/v1/sessions/s1/continue", "secret", `{"text":"carry on"}`); status != 404 {
		t.Fatalf("without a copy there is nothing to continue from, got %d", status)
	}
	copyOf := upload(t, srv.URL, "s1.jsonl", "{}\n", map[string]string{"X-Session": "s1", "X-Origin": "transcript"})
	status, body := call(t, srv, "POST", "/api/v1/sessions/s1/continue", "secret", `{"text":"carry on"}`)
	if status != 200 {
		t.Fatalf("continue: %d %s", status, body)
	}
	start := next().GetStart()
	if start.RestoreTranscript != copyOf.Id || start.Resume != "s1" || !start.Fork || !start.Scratch {
		t.Fatalf("continuing should resume a fork of the copy in a scratch folder: %v", start)
	}
}
