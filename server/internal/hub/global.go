package hub

import (
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Global sessions: the hub keeps a copy of the transcript (an artifact
// uploaded by the session's agent whenever a turn ends), so the
// conversation can be continued on the hub's machine after its own machine
// closes it or goes offline. Continuing starts a new session there from
// the copy, like a fork, and leaves the original alone.

// setGlobal turns a session's global flag on or off. Caller holds h.mu.
func (h *Hub) setGlobal(session string, global bool, by string) (string, *opError) {
	info := h.sessions[session]
	if info == nil {
		return "", errNotFound
	}
	if info.Global != global {
		next := proto.Clone(info).(*v1.SessionInfo)
		next.Global = global
		h.putSession(next)
		kind := "global"
		if !global {
			kind = "local"
		}
		h.recordLineage(&v1.LineageEvent{Session: session, Kind: kind, By: by, AtMs: time.Now().UnixMilli()})
	}
	if global {
		h.uploadTranscript(info)
		h.snapshotSession(h.sessions[session])
	}
	return session, nil
}

// uploadTranscript asks the session's agent for a fresh copy, if it's
// online. Caller holds h.mu.
func (h *Hub) uploadTranscript(info *v1.SessionInfo) {
	if agent := h.agents[info.Node]; agent != nil {
		agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_UploadTranscript_{UploadTranscript: &v1.AgentCommand_UploadTranscript{Session: info.Id}}}))
	}
}

// continueOnHub starts a new session on the hub's machine from a global
// session's latest transcript copy, with text as its first message. Caller
// holds h.mu.
func (h *Hub) continueOnHub(session, text, from string) (string, *opError) {
	info := h.sessions[session]
	if info == nil {
		return "", errNotFound
	}
	if !info.Global {
		return "", invalid("only global sessions can be continued on the hub")
	}
	if strings.TrimSpace(text) == "" {
		return "", invalid("message is empty")
	}
	copy := h.latestCopy(session)
	if copy == nil {
		return "", &opError{"not_found", "the hub has no copy of this session yet; its machine uploads one when a turn ends", http.StatusNotFound}
	}
	node := h.hubNode()
	agent := h.agents[node]
	if agent == nil {
		return "", &opError{"node_offline", "no agent is running on the hub's machine", http.StatusServiceUnavailable}
	}
	now := time.Now().UnixMilli()
	next := &v1.SessionInfo{
		Id: uuid.NewString(), Node: node, Title: info.Title, State: v1.SessionState_SESSION_STATE_RUNNING,
		CreatedMs: now, UpdatedMs: now, LastPrompt: text, Model: info.Model,
		Parent: session, Lineage: "continue", Scratch: true, Global: true,
	}
	start := &v1.AgentCommand_StartRun{
		Session: next.Id, Prompt: text, Model: info.Model, Resume: session, Fork: true, Scratch: true, RestoreTranscript: copy.Id,
	}
	detail := "from transcript copy " + copy.Id
	// With a snapshot of its codebase, it carries on in a copy of that
	// codebase rather than in an empty scratch folder.
	if c := h.codebaseFor(info.Node, info.Cwd); c != nil && c.Snapshot != "" {
		rel, _ := relPath(c.Path, info.Cwd)
		next.Scratch, next.Codebase, next.Snapshot = false, c.Id, c.Snapshot
		start.Scratch, start.Cwd, start.RestoreCodebase, start.RestoreSnapshot = false, rel, c.Id, c.Snapshot
		detail += ", codebase snapshot " + c.Snapshot
	}
	h.putSession(next)
	h.noteSent(next.Id, text, from)
	h.recordLineage(&v1.LineageEvent{Session: next.Id, Parent: session, Kind: "continue", By: from, AtMs: now, Detail: detail})
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Start{Start: start}}))
	return next.Id, nil
}
