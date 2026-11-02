package hub

import (
	"context"
	"net"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Hub sessions run on the hub's own machine in a scratch folder each, so a
// conversation can start without picking a device. Old ones are archived,
// then deleted (their artifacts stay). See docs/plan.md.

const (
	scratchArchiveAfter = 14 * 24 * time.Hour
	scratchDeleteAfter  = 60 * 24 * time.Hour
	retentionEvery      = time.Hour
)

// localIP reports whether ip belongs to this machine.
func localIP(ip string) bool {
	parsed := net.ParseIP(ip)
	if parsed == nil {
		return false
	}
	if parsed.IsLoopback() {
		return true
	}
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return false
	}
	for _, a := range addrs {
		if n, ok := a.(*net.IPNet); ok && n.IP.Equal(parsed) {
			return true
		}
	}
	return false
}

// hubNode is the node running on the hub's machine, or "". Caller holds h.mu.
func (h *Hub) hubNode() string {
	for node, ip := range h.agentIPs {
		if h.agents[node] != nil && localIP(ip) {
			return node
		}
	}
	return ""
}

// retentionLoop archives and then deletes old hub sessions, and drops
// abandoned uploads.
func (h *Hub) retentionLoop(ctx context.Context) {
	t := time.NewTicker(retentionEvery)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			h.mu.Lock()
			h.applyRetention(time.Now())
			h.mu.Unlock()
			h.dropStaleUploads(time.Now())
		}
	}
}

// applyRetention handles idle scratch sessions by age. Caller holds h.mu.
func (h *Hub) applyRetention(now time.Time) {
	for id, s := range h.sessions {
		if !s.Scratch || live(s.State) {
			continue
		}
		age := now.Sub(time.UnixMilli(s.UpdatedMs))
		switch {
		case age > scratchDeleteAfter:
			if agent := h.agents[s.Node]; agent != nil {
				// The agent deletes the folder and transcript; the index then
				// reports the session gone and the hub forgets it.
				agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Forget_{Forget: &v1.AgentCommand_Forget{Session: id}}}))
				h.recordLineage(&v1.LineageEvent{Session: id, Kind: "delete", By: "retention", AtMs: now.UnixMilli()})
			}
		case age > scratchArchiveAfter && !s.Archived:
			next := proto.Clone(s).(*v1.SessionInfo)
			next.Archived = true
			h.putSession(next)
		}
	}
}
