package hub

import (
	"context"
	"strings"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"google.golang.org/protobuf/encoding/protojson"

	"github.com/Mahaveer86619/tether/server/internal/render"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func dialAgent(t *testing.T, h *Hub, url string) (*wire.Conn, context.Context) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	t.Cleanup(cancel)
	agent, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(url, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { agent.Close(nil) })
	_ = agent.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_AgentHello{AgentHello: &v1.AgentHello{Token: "secret", Status: &v1.NodeStatus{Node: "laptop"}}}})
	for i := 0; i < 50 && !h.agentOnline("laptop"); i++ {
		time.Sleep(10 * time.Millisecond)
	}
	return agent, ctx
}

func nextSetMode(t *testing.T, agent *wire.Conn, ctx context.Context) *v1.AgentCommand_SetMode {
	t.Helper()
	for {
		f, err := agent.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		if m := f.GetAgentCommand().GetSetMode(); m != nil {
			return m
		}
	}
}

func TestSettingAModeForAWhileAndRevertingIt(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)

	if status, body := call(t, srv, "POST", "/api/v1/sessions/s1/mode", "secret", `{"mode":"acceptEdits","revertAfterMs":"900000"}`); status != 200 {
		t.Fatalf("set mode: %d %s", status, body)
	}
	if m := nextSetMode(t, agent, ctx); m.Session != "s1" || m.Mode != "acceptEdits" {
		t.Fatalf("the node got %v", m)
	}
	h.mu.Lock()
	s := h.sessions["s1"]
	if s.PermissionMode != "acceptEdits" || s.ModeRevertTo != "default" || s.ModeRevertMs < time.Now().Add(14*time.Minute).UnixMilli() {
		t.Fatalf("session after set: %q revert to %q at %d", s.PermissionMode, s.ModeRevertTo, s.ModeRevertMs)
	}
	// Not due yet.
	h.revertModes(time.Now())
	h.revertModes(time.Now().Add(16 * time.Minute))
	s = h.sessions["s1"]
	h.mu.Unlock()
	if m := nextSetMode(t, agent, ctx); m.Mode != "default" {
		t.Fatalf("revert sent %q", m.Mode)
	}
	if s.PermissionMode != "default" || s.ModeRevertMs != 0 {
		t.Fatalf("after revert: %q %d", s.PermissionMode, s.ModeRevertMs)
	}

	if status, _ := call(t, srv, "POST", "/api/v1/sessions/s1/mode", "secret", `{"mode":"bypassPermissions"}`); status != 400 {
		t.Fatalf("an unknown mode should be refused, got %d", status)
	}
}

func TestAModeTheNodeCouldNotSwitchToIsUndone(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	call(t, srv, "POST", "/api/v1/sessions/s1/mode", "secret", `{"mode":"plan"}`)
	nextSetMode(t, agent, ctx)
	h.onAgent("laptop", &v1.Frame{Body: &v1.Frame_ModeResult{ModeResult: &v1.ModeResult{Session: "s1", Mode: "plan", Error: "a dialog is open"}}})
	h.mu.Lock()
	defer h.mu.Unlock()
	if s := h.sessions["s1"]; s.PermissionMode != "default" || !strings.Contains(s.Error, "a dialog is open") {
		t.Fatalf("a failed switch should put the mode back and say why: %q %q", s.PermissionMode, s.Error)
	}
}

func TestTheTranscriptSetsTheModeUnlessASwitchIsPending(t *testing.T) {
	h, srv := newTestHubWith(t)
	h.mu.Lock()
	h.applyPatch("s1", render.Patch{Mode: "plan"})
	got := h.sessions["s1"].PermissionMode
	h.mu.Unlock()
	if got != "plan" {
		t.Fatalf("mode from the transcript: %q", got)
	}

	agent, ctx := dialAgent(t, h, srv.URL)
	call(t, srv, "POST", "/api/v1/sessions/s1/mode", "secret", `{"mode":"acceptEdits"}`)
	nextSetMode(t, agent, ctx)
	h.mu.Lock()
	defer h.mu.Unlock()
	h.applyPatch("s1", render.Patch{Mode: "plan"})
	if m := h.sessions["s1"].PermissionMode; m != "acceptEdits" {
		t.Fatalf("an older line put the mode back during the switch: %q", m)
	}
	// An agent from before modes never answers; the transcript wins again.
	sw := h.modeBefore["s1"]
	sw.at = time.Now().Add(-time.Minute)
	h.modeBefore["s1"] = sw
	h.applyPatch("s1", render.Patch{Mode: "plan"})
	if m := h.sessions["s1"].PermissionMode; m != "plan" {
		t.Fatalf("after waiting, the transcript should set the mode: %q", m)
	}

	// The agent's own reports don't know modes and mustn't clear them.
	h.mergeSession(&v1.SessionInfo{Id: "s1", Node: "laptop", State: v1.SessionState_SESSION_STATE_READY})
	if m := h.sessions["s1"].PermissionMode; m != "plan" {
		t.Fatalf("an agent report cleared the mode: %q", m)
	}
}

func TestForksAndResumesKeepTheMode(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	h.mu.Lock()
	h.sessions["s1"].PermissionMode = "plan"
	h.mu.Unlock()
	call(t, srv, "POST", "/api/v1/sessions/s1/messages", "secret", `{"text":"go on"}`)
	call(t, srv, "POST", "/api/v1/sessions/s1/messages", "secret", `{"text":"try it another way","fork":true}`)
	var send *v1.AgentCommand_SendInput
	var start *v1.AgentCommand_StartRun
	for send == nil || start == nil {
		f, err := agent.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		if s := f.GetAgentCommand().GetSend(); s != nil {
			send = s
		}
		if s := f.GetAgentCommand().GetStart(); s != nil {
			start = s
		}
	}
	if send.PermissionMode != "plan" || start.PermissionMode != "plan" {
		t.Fatalf("resume %q, fork %q", send.PermissionMode, start.PermissionMode)
	}
}

func TestACommandTheNodeCouldNotCarryOutShowsOnTheSession(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.onAgent("minipc", &v1.Frame{Body: &v1.Frame_CommandResult{CommandResult: &v1.CommandResult{Session: "s1", Command: "interrupt", Error: "forged"}}})
	h.onAgent("laptop", &v1.Frame{Body: &v1.Frame_CommandResult{CommandResult: &v1.CommandResult{Session: "s1", Command: "interrupt", Error: "Claude Code is still working"}}})
	h.mu.Lock()
	defer h.mu.Unlock()
	if e := h.sessions["s1"].Error; e != "Claude Code is still working" {
		t.Fatalf("session error: %q", e)
	}
}

func TestConnectedAppsAreListedWithTheirVersions(t *testing.T) {
	h, srv := newTestHubWith(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	app, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	defer app.Close(nil)
	_ = app.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_ClientHello{ClientHello: &v1.ClientHello{Token: "secret", ClientName: "Pixel (android)", Platform: "android", AppVersion: "0.15.0"}}})
	if _, err := app.Read(ctx); err != nil { // the welcome
		t.Fatal(err)
	}
	_, body := call(t, srv, "GET", "/api/v1/clients", "secret", "")
	list := &v1.ClientList{}
	if err := protojson.Unmarshal([]byte(body), list); err != nil || len(list.Clients) != 1 {
		t.Fatalf("clients: %s", body)
	}
	if c := list.Clients[0]; c.Name != "Pixel (android)" || c.Platform != "android" || c.AppVersion != "0.15.0" || c.ConnectedMs == 0 {
		t.Fatalf("client: %v", c)
	}
	if status, _ := call(t, srv, "GET", "/api/v1/clients", "", ""); status != 401 {
		t.Fatalf("listing apps needs a token, got %d", status)
	}
	_ = h
}
