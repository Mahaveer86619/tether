package hub

import (
	"context"
	"net/http"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Background backups: while an app is in the foreground somewhere, the hub
// keeps a copy of every session's transcript (with its subagents' and its
// details), asking each node only for what changed. See
// docs/plan.md#session-backups.

const (
	backupEvery  = 10 * time.Minute
	originBackup = "backup"
	// The path of a backup's main transcript; subagents are "subagents/<file>".
	backupTranscript = "transcript"
)

// backupLoop asks for backups every backupEvery while an app is active.
func (h *Hub) backupLoop(ctx context.Context) {
	t := time.NewTicker(backupEvery)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			h.mu.Lock()
			if h.appActive() {
				h.requestBackups()
			}
			h.mu.Unlock()
		}
	}
}

// appActive: caller holds h.mu.
func (h *Hub) appActive() bool {
	for c := range h.clients {
		if c.active {
			return true
		}
	}
	return false
}

// notePresence: an app coming to the foreground after a while away starts a
// backup at once rather than at the next tick. Caller holds h.mu.
func (h *Hub) notePresence(c *client, active bool) {
	c.active = active
	if active && time.Since(h.lastBackup) > backupEvery {
		h.requestBackups()
	}
}

// requestBackups sends each online node what the hub has of its sessions.
// Caller holds h.mu.
func (h *Hub) requestBackups() {
	h.lastBackup = time.Now()
	for node, agent := range h.agents {
		stored := map[string]int64{}
		for id, s := range h.sessions {
			if s.Node == node {
				stored[id] = s.BackedUpBytes
			}
		}
		agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Backup{Backup: &v1.AgentCommand_BackupSessions{Stored: stored}}}))
	}
}

// keepBackup records one backed-up file: one row per session and path,
// replaced only when the content changed, and not announced to apps.
// Caller holds h.mu.
func (h *Hub) keepBackup(a *v1.Artifact) (*v1.Artifact, *opError) {
	old, err := h.store.BackupFile(a.Session, a.Path)
	if err != nil {
		return nil, internalError(err)
	}
	if old != nil && old.Sha256 == a.Sha256 {
		return old, nil
	}
	if old != nil {
		if oerr := h.deleteArtifact(old.Id); oerr != nil {
			return nil, oerr
		}
	}
	a.Id, a.CreatedMs = newID(), time.Now().UnixMilli()
	if err := h.store.PutArtifact(a); err != nil {
		return nil, internalError(err)
	}
	if info := h.sessions[a.Session]; info != nil && a.Path == backupTranscript {
		next := proto.Clone(info).(*v1.SessionInfo)
		next.BackedUpMs, next.BackedUpBytes = a.CreatedMs, a.Size
		h.putSession(next)
	}
	return a, nil
}

// latestCopy is the newest stored transcript of a session: a global
// session's copy or a backup. Caller holds h.mu.
func (h *Hub) latestCopy(session string) *v1.Artifact {
	list, err := h.store.Artifacts(session, 100)
	if err != nil {
		return nil
	}
	for _, a := range list {
		if a.Origin == "transcript" || a.Origin == originBackup && a.Path == backupTranscript {
			return a
		}
	}
	if b, err := h.store.BackupFile(session, backupTranscript); err == nil && b != nil {
		return b
	}
	return nil
}

// hideBackups keeps backups out of artifact lists unless asked for: they're
// for restoring, not browsing.
func hideBackups(r *http.Request, list []*v1.Artifact) []*v1.Artifact {
	if r.URL.Query().Get("origin") == originBackup {
		return list
	}
	out := list[:0]
	for _, a := range list {
		if a.Origin != originBackup {
			out = append(out, a)
		}
	}
	return out
}
