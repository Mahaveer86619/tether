package hub

import v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"

// Lineage: which session split off from which, and how. Sessions carry
// parent, fork_point and lineage; every fork, branch, merge and abandon is
// also kept as an event for the second brain. See docs/plan.md.

// recordLineage keeps an event. Caller holds h.mu.
func (h *Hub) recordLineage(e *v1.LineageEvent) {
	if err := h.store.AddLineageEvent(e); err != nil {
		h.log.Error("record lineage", "session", e.Session, "err", err)
	}
}
