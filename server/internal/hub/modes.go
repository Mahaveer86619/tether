package hub

import (
	"context"
	"net/http"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Permission modes: shown on every session, switched from an app, and put
// back by the hub when one was set for a while. See docs/hosting.md#permission-modes.

const (
	modeCheckEvery = 15 * time.Second
	// An agent from before modes answers nothing; stop waiting for it.
	modeSwitchWait = 30 * time.Second
)

type modeSwitch struct {
	before string
	at     time.Time
}

var permissionModes = map[string]bool{"default": true, "acceptEdits": true, "plan": true, "auto": true}

func (h *Hub) modeRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v1/sessions/{id}/mode", h.api(func(r *http.Request) (proto.Message, *opError) {
		m := &v1.SetPermissionMode{}
		if err := decode(r, m); err != nil {
			return nil, err
		}
		return ackOf(h.setMode(r.PathValue("id"), m.Mode, time.Duration(m.RevertAfterMs)*time.Millisecond))
	}))
}

// setMode switches a session's mode, for revertAfter if that's set. Caller
// holds h.mu.
func (h *Hub) setMode(session, mode string, revertAfter time.Duration) (string, *opError) {
	if !permissionModes[mode] {
		return "", invalid("unknown permission mode " + mode)
	}
	info, agent, err := h.target(session)
	if err != nil {
		return "", err
	}
	next := proto.Clone(info).(*v1.SessionInfo)
	was := firstNonEmpty(info.PermissionMode, "default")
	if info.ModeRevertMs != 0 {
		// Setting a mode again keeps what the first timed change put aside.
		was = info.ModeRevertTo
	}
	next.PermissionMode, next.ModeRevertMs, next.ModeRevertTo = mode, 0, ""
	if revertAfter > 0 && was != mode {
		next.ModeRevertMs, next.ModeRevertTo = time.Now().Add(revertAfter).UnixMilli(), was
	}
	h.modeBefore[info.Id] = modeSwitch{before: firstNonEmpty(info.PermissionMode, "default"), at: time.Now()}
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_SetMode_{SetMode: &v1.AgentCommand_SetMode{Session: info.Id, Mode: mode}}}))
	h.putSession(next)
	return info.Id, nil
}

// noteModeResult undoes a mode the node couldn't switch to. Caller holds h.mu.
func (h *Hub) noteModeResult(node string, r *v1.ModeResult) {
	info := h.sessions[r.Session]
	if info == nil || info.Node != node {
		return
	}
	sw, ok := h.modeBefore[r.Session]
	delete(h.modeBefore, r.Session)
	if r.Error == "" || !ok || info.PermissionMode != r.Mode {
		return
	}
	h.log.Warn("permission mode not switched", "session", r.Session, "mode", r.Mode, "err", r.Error)
	next := proto.Clone(info).(*v1.SessionInfo)
	next.PermissionMode, next.ModeRevertMs, next.ModeRevertTo = sw.before, 0, ""
	next.Error = "Couldn't switch to " + r.Mode + ": " + r.Error
	h.putSession(next)
}

// switchingMode reports a switch the node hasn't answered yet, during
// which older transcript lines mustn't put the old mode back. Caller holds h.mu.
func (h *Hub) switchingMode(session string) bool {
	sw, ok := h.modeBefore[session]
	if ok && time.Since(sw.at) > modeSwitchWait {
		delete(h.modeBefore, session)
		return false
	}
	return ok
}

// noteCommandResult shows a command the node couldn't carry out on the
// session. Caller holds h.mu.
func (h *Hub) noteCommandResult(node string, r *v1.CommandResult) {
	info := h.sessions[r.Session]
	if info == nil || info.Node != node || r.Error == "" {
		return
	}
	next := proto.Clone(info).(*v1.SessionInfo)
	next.Error = r.Error
	h.putSession(next)
}

// modeArg is the mode to start or resume a session in; Claude Code's own
// default needs no flag.
func modeArg(mode string) string {
	if mode == "default" {
		return ""
	}
	return mode
}

// modeLoop puts back modes that were set for a while.
func (h *Hub) modeLoop(ctx context.Context) {
	t := time.NewTicker(modeCheckEvery)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			h.mu.Lock()
			h.revertModes(time.Now())
			h.mu.Unlock()
		}
	}
}

// revertModes: caller holds h.mu.
func (h *Hub) revertModes(now time.Time) {
	for id, s := range h.sessions {
		if s.ModeRevertMs == 0 || now.UnixMilli() < s.ModeRevertMs {
			continue
		}
		// An offline node is tried again on a later tick; its next resume
		// starts in the mode the session shows.
		if _, err := h.setMode(id, firstNonEmpty(s.ModeRevertTo, "default"), 0); err != nil && err != errNodeOffline {
			next := proto.Clone(s).(*v1.SessionInfo)
			next.PermissionMode, next.ModeRevertMs, next.ModeRevertTo = firstNonEmpty(s.ModeRevertTo, "default"), 0, ""
			h.putSession(next)
		}
	}
}
