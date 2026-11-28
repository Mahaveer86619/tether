package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"testing"
)

type recordingRunner struct {
	mu       sync.Mutex
	commands [][]string
}

func (r *recordingRunner) Run(_ context.Context, args ...string) (string, error) {
	r.mu.Lock()
	r.commands = append(r.commands, append([]string(nil), args...))
	r.mu.Unlock()
	return "", nil
}

func (r *recordingRunner) joined() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]string, 0, len(r.commands))
	for _, args := range r.commands {
		out = append(out, strings.Join(args, " "))
	}
	return out
}

type fakeHub struct {
	t     *testing.T
	token string
	state welcomeState
}

func (f *fakeHub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if got := r.Header.Get("Authorization"); got != "Bearer "+f.token {
		f.t.Errorf("authorization = %q", got)
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	switch r.URL.Path {
	case "/api/v1/state":
		_ = json.NewEncoder(w).Encode(f.state)
	case "/mcp":
		var req rpcRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			f.t.Fatalf("decode MCP request: %v", err)
		}
		var result any
		switch req.Method {
		case "initialize":
			result = map[string]any{"protocolVersion": "2025-06-18"}
		case "tools/list":
			result = map[string]any{"tools": []map[string]any{{"name": "create_chat"}}}
		case "tools/call":
			var p struct {
				Name string `json:"name"`
			}
			_ = json.Unmarshal(req.Params, &p)
			result = map[string]any{"content": []map[string]any{{"type": "text", "text": toolText(p.Name)}}}
		default:
			http.Error(w, "unexpected method "+req.Method, http.StatusBadRequest)
			return
		}
		_ = json.NewEncoder(w).Encode(rpcResponse{JSONRPC: "2.0", ID: req.ID, Result: mustJSON(result)})
	default:
		http.NotFound(w, r)
	}
}

func toolText(name string) string {
	switch name {
	case "create_chat":
		return "Created chat chat-1 with lead session sess-1 on box."
	case "delegate_task":
		return `{"task":"task-2","session":"sess-2","profile":"opencode-worker","model":"opencode/big-pickle","node":"box"}`
	case "pick_model":
		return `{"profile":"opencode-worker","model":"big-pickle","decision":"route","reason":"free tier"}`
	case "token_status":
		return `{"status":{"lastDecision":"big-pickle","providers":[{"provider":"opencode","model":"big-pickle","enabled":true,"quotaState":"ok","remainingTokens":1200000}]},"events":[]}`
	case "wait_for_subagents":
		return "Task task-2, session sess-2, ready on box"
	default:
		return "ok"
	}
}

func newTestBridge(t *testing.T, o options) (*bridge, *recordingRunner) {
	t.Helper()
	fake := &fakeHub{t: t, token: "tok", state: welcomeState{
		Sessions: []sessionState{{ID: "sess-1", State: "SESSION_STATE_RUNNING", Title: "Test chat", Node: "box", Profile: "claude-main"}},
		Chats:    []chatState{{ID: "chat-1", ActiveSession: "sess-1", Sessions: []chatLink{{Session: "sess-1"}}}},
	}}
	srv := httptest.NewServer(fake)
	t.Cleanup(srv.Close)
	o.hub = srv.URL
	o.token = "tok"
	o.herdrBin = "herdr"
	runner := &recordingRunner{}
	herdr := &herdrAdapter{runner: runner, pane: "w1:p1", source: "tether", agent: "tether"}
	b := newBridge(newHubClient(o.hub, o.token, ""), herdr, o)
	b.watchRunner = runner
	return b, runner
}

func hasCommand(commands []string, parts ...string) bool {
	want := strings.Join(parts, " ")
	for _, cmd := range commands {
		if strings.HasPrefix(cmd, want) {
			return true
		}
	}
	return false
}

func TestServeForwardsMCPAndReportsChat(t *testing.T) {
	b, runner := newTestBridge(t, options{})

	in := strings.NewReader(strings.Join([]string{
		`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}`,
		`{"jsonrpc":"2.0","id":2,"method":"tools/list"}`,
		`{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"create_chat","arguments":{"prompt":"hi"}}}`,
	}, "\n") + "\n")
	var out bytes.Buffer
	if err := b.serve(in, &out); err != nil {
		t.Fatalf("serve: %v", err)
	}

	lines := strings.Split(strings.TrimSpace(out.String()), "\n")
	if len(lines) != 3 {
		t.Fatalf("got %d replies: %s", len(lines), out.String())
	}
	for i, line := range lines {
		var resp rpcResponse
		if err := json.Unmarshal([]byte(line), &resp); err != nil {
			t.Fatalf("reply %d: %v", i, err)
		}
		if resp.Error != nil {
			t.Fatalf("reply %d error: %v", i, resp.Error)
		}
		if string(resp.ID) != strconv.Itoa(i+1) {
			t.Fatalf("reply %d id = %s", i, resp.ID)
		}
	}

	cmds := runner.joined()
	if !hasCommand(cmds, "pane report-agent w1:p1 --source tether --agent tether --state working --seq 1 --message Tether chat chat-1 --agent-session-id sess-1") {
		t.Fatalf("missing agent report: %v", cmds)
	}
	if !hasCommand(cmds, "pane report-metadata w1:p1 --source tether --seq 2") {
		t.Fatalf("missing metadata report: %v", cmds)
	}
	if !strings.Contains(strings.Join(cmds, " "), "--token tether_chat=chat-1") {
		t.Fatalf("missing chat token: %v", cmds)
	}
}

func TestDelegateTaskOpensWatchTerminal(t *testing.T) {
	b, runner := newTestBridge(t, options{watch: true, hcBin: "hc", watchBin: "tetherctl"})

	b.observe(context.Background(), "delegate_task", map[string]any{"chat": "chat-1"}, json.RawMessage(mustJSON(map[string]any{
		"content": []map[string]any{{"type": "text", "text": toolText("delegate_task")}},
	})))

	cmds := runner.joined()
	if !hasCommand(cmds, "run --bg --name tether-task-2 tetherctl watch sess-2") {
		t.Fatalf("missing watch terminal: %v", cmds)
	}
	if !hasCommand(cmds, "pane report-agent w1:p1 --source tether --agent tether --state working") {
		t.Fatalf("missing agent report: %v", cmds)
	}
}

func TestSyncMapsSessionStateAfterReconnect(t *testing.T) {
	b, runner := newTestBridge(t, options{chat: "chat-1"})

	if err := b.sync(context.Background()); err != nil {
		t.Fatalf("first sync: %v", err)
	}
	if !hasCommand(runner.joined(), "pane report-agent w1:p1 --source tether --agent tether --state working --seq 1 --message Tether Test chat --agent-session-id sess-1") {
		t.Fatalf("first sync did not report working: %v", runner.joined())
	}
	if err := b.sync(context.Background()); err != nil {
		t.Fatalf("second sync: %v", err)
	}
	if !hasCommand(runner.joined(), "pane report-metadata w1:p1 --source tether --seq 3") {
		t.Fatalf("second sync should only refresh metadata: %v", runner.joined())
	}
}

func TestObserveReportsModelChoiceAndTokens(t *testing.T) {
	b, runner := newTestBridge(t, options{})

	for _, tool := range []string{"pick_model", "token_status"} {
		b.observe(context.Background(), tool, nil, json.RawMessage(mustJSON(map[string]any{
			"content": []map[string]any{{"type": "text", "text": toolText(tool)}},
		})))
	}

	cmds := strings.Join(runner.joined(), " ")
	for _, want := range []string{"--token tether_profile=opencode-worker", "--token tether_model=big-pickle", "--token tether_tokens=remaining 1M", "--token tether_decision=big-pickle"} {
		if !strings.Contains(cmds, want) {
			t.Fatalf("missing %q in %q", want, cmds)
		}
	}
}

func TestSessionIDsForChat(t *testing.T) {
	w := welcomeState{Chats: []chatState{{
		ID: "chat-1", ActiveSession: "s1", Sessions: []chatLink{{Session: "s1"}, {Session: "s2"}, {Session: ""}},
	}}}
	got := w.sessionIDsFor("chat-1")
	if len(got) != 2 || got[0] != "s1" || got[1] != "s2" {
		t.Fatalf("sessionIDsFor = %v", got)
	}
}
