package hub

import (
	"encoding/json"
	"net/http"
)

// hello answers GET /api/v1/hello for anyone, with no token: what this is, its
// version, and whether the caller would be let in without one (the hub trusts
// its owner's tailnet). It lets an app that has found a machine on the tailnet
// tell a Tether hub from anything else, and say how to connect, before it has
// any credentials. It tells nothing else and counts as no failed attempt.
func (h *Hub) hello(w http.ResponseWriter, r *http.Request) {
	_, trusted := h.identifyFrom("", remoteIP(r))
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"app":     "tether-hub",
		"version": h.cfg.Version,
		"trusted": trusted,
	})
}
