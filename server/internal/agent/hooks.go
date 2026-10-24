package agent

import (
	"encoding/json"
	"io"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/hooks"
)

const (
	hookPath            = hooks.Path
	hookStale           = hooks.StaleTimeout
	approvalHookTimeout = hooks.ApprovalTimeout
)

var hookEvents = hooks.Events

type hookInput struct {
	SessionID        string          `json:"session_id"`
	Cwd              string          `json:"cwd"`
	Event            string          `json:"hook_event_name"`
	ToolName         string          `json:"tool_name"`
	ToolInput        json.RawMessage `json:"tool_input"`
	ToolUseID        string          `json:"tool_use_id"`
	NotificationType string          `json:"notification_type"`
	Message          string          `json:"message"`
	Error            string          `json:"error"`
}

// hookSession is what hooks have told us about one live Claude Code process.
type hookSession struct {
	state   v1.SessionState
	closed  bool
	last    time.Time
	errText string
	// The Claude Code process, when known; lets Windows type into its console.
	pid uint32
}

type hookApproval struct {
	session  string
	decision chan *v1.ApprovalDecision
}

func (a *Agent) serveHooks(addr string) error {
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	mux := http.NewServeMux()
	mux.HandleFunc(hookPath, a.handleHook)
	go func() { _ = http.Serve(ln, mux) }()
	return nil
}

func (a *Agent) handleHook(w http.ResponseWriter, r *http.Request) {
	var in hookInput
	if err := json.NewDecoder(io.LimitReader(r.Body, 16<<20)).Decode(&in); err != nil || in.SessionID == "" {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	var pid uint32
	if terminalInputSupported {
		if _, port, err := net.SplitHostPort(a.cfg.HookAddr); err == nil {
			p, _ := strconv.Atoi(port)
			pid, _ = pidOfLocalPeer(r.RemoteAddr, p)
		}
	}
	a.noteHook(in, pid)
	a.noteToolFile(in)
	if in.Event != "PermissionRequest" {
		w.WriteHeader(http.StatusOK)
		return
	}
	// Headless runs get their prompts through the stdio control protocol.
	if a.run(in.SessionID) != nil {
		w.WriteHeader(http.StatusOK)
		return
	}
	a.mu.Lock()
	connected := a.conn != nil
	a.mu.Unlock()
	if !connected {
		w.WriteHeader(http.StatusOK)
		return
	}

	id := uuid.NewString()
	ha := &hookApproval{session: in.SessionID, decision: make(chan *v1.ApprovalDecision, 1)}
	a.mu.Lock()
	a.hookApprovals[id] = ha
	a.mu.Unlock()
	input := in.ToolInput
	if len(input) == 0 {
		input = json.RawMessage("{}")
	}
	var desc struct {
		Description string `json:"description"`
	}
	_ = json.Unmarshal(input, &desc)
	a.send(&v1.Frame{Body: &v1.Frame_ApprovalRequested{ApprovalRequested: &v1.ApprovalRequest{
		ApprovalId: id, Session: in.SessionID, ToolName: in.ToolName, InputJson: string(input),
		Description: desc.Description, Kind: approvalKind(in.ToolName),
	}}})

	select {
	case d := <-ha.decision:
		behavior := map[string]any{"behavior": "allow"}
		if len(d.Answers) > 0 {
			behavior["updatedInput"] = withAnswers(input, d.Answers)
		}
		if d.Decision != v1.Decision_DECISION_ALLOW {
			behavior = map[string]any{"behavior": "deny", "message": firstNonEmpty(d.Message, "Denied from Tether")}
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{"hookSpecificOutput": map[string]any{
			"hookEventName": "PermissionRequest", "decision": behavior,
		}})
		a.setHookState(in.SessionID, v1.SessionState_SESSION_STATE_RUNNING)
	case <-r.Context().Done():
		a.withdrawApproval(id, "terminal")
	}
}

// noteHook updates a session's state from a hook event. Any event after a
// permission request means it was answered elsewhere, usually the terminal.
func (a *Agent) noteHook(in hookInput, pid uint32) {
	var next v1.SessionState
	closed := false
	switch in.Event {
	case "SessionStart", "Stop":
		next = v1.SessionState_SESSION_STATE_READY
	case "UserPromptSubmit", "PostToolUse":
		next = v1.SessionState_SESSION_STATE_RUNNING
	case "PermissionRequest":
		next = v1.SessionState_SESSION_STATE_AWAITING_APPROVAL
	case "Notification":
		switch in.NotificationType {
		case "idle_prompt", "agent_completed":
			next = v1.SessionState_SESSION_STATE_READY
		case "permission_prompt", "agent_needs_input", "elicitation_dialog":
			next = v1.SessionState_SESSION_STATE_AWAITING_APPROVAL
		}
	case "StopFailure":
		next = v1.SessionState_SESSION_STATE_READY
	case "SessionEnd":
		closed = true
	}
	if in.Event != "PermissionRequest" && in.Event != "Notification" {
		a.withdrawSessionApprovals(in.SessionID)
	}

	a.mu.Lock()
	hs := a.hooks[in.SessionID]
	if hs == nil {
		hs = &hookSession{}
		a.hooks[in.SessionID] = hs
	}
	hs.last = time.Now()
	hs.closed = closed
	if pid != 0 {
		hs.pid = pid
	}
	if next != v1.SessionState_SESSION_STATE_UNSPECIFIED {
		hs.state = next
	}
	if in.Event == "StopFailure" {
		hs.errText = firstNonEmpty(in.Error, in.Message, "turn failed")
	} else if next == v1.SessionState_SESSION_STATE_RUNNING {
		hs.errText = ""
	}
	a.mu.Unlock()
	a.report(in.SessionID)
}

func (a *Agent) setHookState(session string, s v1.SessionState) {
	a.mu.Lock()
	if hs := a.hooks[session]; hs != nil {
		hs.state, hs.last = s, time.Now()
	}
	a.mu.Unlock()
	a.report(session)
}

// hookState returns live hook-tracked state, if any.
func (a *Agent) hookState(session string) (*hookSession, bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	hs := a.hooks[session]
	if hs == nil || hs.closed || time.Since(hs.last) > hookStale {
		return hs, false
	}
	c := *hs
	return &c, true
}

func (a *Agent) answerHook(d *v1.ApprovalDecision) bool {
	a.mu.Lock()
	ha := a.hookApprovals[d.ApprovalId]
	delete(a.hookApprovals, d.ApprovalId)
	a.mu.Unlock()
	if ha == nil {
		return false
	}
	ha.decision <- d
	return true
}

func (a *Agent) withdrawApproval(id, by string) {
	a.mu.Lock()
	ha := a.hookApprovals[id]
	delete(a.hookApprovals, id)
	a.mu.Unlock()
	if ha != nil {
		a.send(&v1.Frame{Body: &v1.Frame_ApprovalResolved{ApprovalResolved: &v1.ApprovalResolved{ApprovalId: id, Session: ha.session, By: by}}})
	}
}

func (a *Agent) withdrawSessionApprovals(session string) {
	a.mu.Lock()
	var ids []string
	for id, ha := range a.hookApprovals {
		if ha.session == session {
			ids = append(ids, id)
		}
	}
	a.mu.Unlock()
	for _, id := range ids {
		a.withdrawApproval(id, "terminal")
	}
}

// ---- settings.json ----

// InstallHooks adds Tether's HTTP hooks to a Claude Code settings file,
// replacing any earlier Tether entries and leaving everything else as is.
func InstallHooks(settingsPath, url string) error {
	return hooks.Install(settingsPath, url)
}

// UninstallHooks removes Tether's hooks from a Claude Code settings file.
func UninstallHooks(settingsPath string) error {
	return hooks.Uninstall(settingsPath)
}
