package agent

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/google/uuid"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

const (
	hookPath = "/tether/hook"
	// Hook-tracked sessions with no events for this long are assumed closed;
	// a terminal that crashed never sends SessionEnd.
	hookStale = 12 * time.Hour
	// How long a PermissionRequest hook may wait for an answer from the app.
	// The terminal shows its own prompt meanwhile; whichever answers first wins.
	approvalHookTimeout = 3600
)

// hookEvents are the Claude Code hook events the agent listens to.
var hookEvents = []string{"SessionStart", "UserPromptSubmit", "PermissionRequest", "PostToolUse", "Notification", "Stop", "StopFailure", "SessionEnd"}

type hookInput struct {
	SessionID        string          `json:"session_id"`
	Cwd              string          `json:"cwd"`
	Event            string          `json:"hook_event_name"`
	ToolName         string          `json:"tool_name"`
	ToolInput        json.RawMessage `json:"tool_input"`
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
	a.noteHook(in)
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
		Description: desc.Description, Kind: v1.ApprovalRequest_KIND_TOOL,
	}}})

	select {
	case d := <-ha.decision:
		behavior := map[string]any{"behavior": "allow"}
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
func (a *Agent) noteHook(in hookInput) {
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
	return editHooks(settingsPath, func(hooks map[string][]map[string]any) {
		for _, ev := range hookEvents {
			entry := map[string]any{"type": "http", "url": url, "timeout": 10}
			if ev == "PermissionRequest" {
				entry["timeout"] = approvalHookTimeout
			}
			hooks[ev] = append(hooks[ev], map[string]any{"hooks": []any{entry}})
		}
	})
}

// UninstallHooks removes Tether's hooks from a Claude Code settings file.
func UninstallHooks(settingsPath string) error {
	return editHooks(settingsPath, func(map[string][]map[string]any) {})
}

func editHooks(path string, add func(map[string][]map[string]any)) error {
	orig, err := os.ReadFile(path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	if len(bytes.TrimSpace(orig)) == 0 {
		orig = []byte("{}")
	}
	keys, values, err := orderedObject(orig)
	if err != nil {
		return fmt.Errorf("%s: %w", path, err)
	}

	hooks := map[string][]map[string]any{}
	if raw, ok := values["hooks"]; ok {
		if err := json.Unmarshal(raw, &hooks); err != nil {
			return fmt.Errorf("%s: hooks: %w", path, err)
		}
	}
	for ev, groups := range hooks {
		var kept []map[string]any
		for _, g := range groups {
			list, _ := g["hooks"].([]any)
			var rest []any
			for _, h := range list {
				if m, ok := h.(map[string]any); ok && isTetherHook(m) {
					continue
				}
				rest = append(rest, h)
			}
			if len(rest) == 0 && len(list) > 0 {
				continue
			}
			g["hooks"] = rest
			kept = append(kept, g)
		}
		if len(kept) == 0 {
			delete(hooks, ev)
		} else {
			hooks[ev] = kept
		}
	}
	add(hooks)

	if len(hooks) == 0 {
		if _, ok := values["hooks"]; ok {
			delete(values, "hooks")
			keys = without(keys, "hooks")
		}
	} else {
		raw, err := json.Marshal(hooks)
		if err != nil {
			return err
		}
		if _, ok := values["hooks"]; !ok {
			keys = append(keys, "hooks")
		}
		values["hooks"] = raw
	}

	out := writeObject(keys, values)
	if bytes.Equal(bytes.TrimSpace(out), bytes.TrimSpace(orig)) {
		return nil
	}
	if _, err := os.Stat(path + ".tether-backup"); errors.Is(err, os.ErrNotExist) && len(orig) > 2 {
		if err := os.WriteFile(path+".tether-backup", orig, 0o600); err != nil {
			return err
		}
	}
	tmp := path + ".tether-tmp"
	if err := os.WriteFile(tmp, out, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func isTetherHook(m map[string]any) bool {
	url, _ := m["url"].(string)
	return m["type"] == "http" && strings.HasSuffix(url, hookPath)
}

// orderedObject decodes a JSON object keeping its key order, so rewriting
// the settings file doesn't shuffle the user's keys.
func orderedObject(data []byte) ([]string, map[string]json.RawMessage, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	tok, err := dec.Token()
	if err != nil {
		return nil, nil, err
	}
	if d, ok := tok.(json.Delim); !ok || d != '{' {
		return nil, nil, errors.New("not a JSON object")
	}
	var keys []string
	values := map[string]json.RawMessage{}
	for dec.More() {
		tok, err := dec.Token()
		if err != nil {
			return nil, nil, err
		}
		k, _ := tok.(string)
		var raw json.RawMessage
		if err := dec.Decode(&raw); err != nil {
			return nil, nil, err
		}
		if _, dup := values[k]; !dup {
			keys = append(keys, k)
		}
		values[k] = raw
	}
	return keys, values, nil
}

func writeObject(keys []string, values map[string]json.RawMessage) []byte {
	var b bytes.Buffer
	b.WriteString("{")
	for i, k := range keys {
		if i > 0 {
			b.WriteString(",")
		}
		kb, _ := json.Marshal(k)
		var v bytes.Buffer
		if json.Indent(&v, values[k], "  ", "  ") != nil {
			v.Write(values[k])
		}
		fmt.Fprintf(&b, "\n  %s: %s", kb, v.Bytes())
	}
	b.WriteString("\n}\n")
	return b.Bytes()
}

func without(ss []string, s string) []string {
	var out []string
	for _, x := range ss {
		if x != s {
			out = append(out, x)
		}
	}
	return out
}
