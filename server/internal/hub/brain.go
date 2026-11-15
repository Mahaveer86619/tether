package hub

import (
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// The second brain's MCP server (tether-brain, see docs/plans/second-brain-rust.md)
// listens on the loopback of the hub's machine. The hub puts it behind its own
// token at /brain/mcp, so every device's Claude Code reaches it the way it
// reaches the hub's own MCP server.

var brainClient = &http.Client{Timeout: 60 * time.Second}

func (h *Hub) brainRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /brain/mcp", h.authed(h.brainForward))
	mux.HandleFunc("GET /brain/healthz", h.authed(func(w http.ResponseWriter, r *http.Request) {
		if h.cfg.BrainURL == "" {
			http.Error(w, "the second brain is not set up on this hub", http.StatusNotFound)
			return
		}
		res, err := brainClient.Get(strings.TrimRight(h.cfg.BrainURL, "/") + "/healthz")
		if err != nil {
			http.Error(w, "the second brain is not answering", http.StatusBadGateway)
			return
		}
		res.Body.Close()
		w.WriteHeader(res.StatusCode)
	}))
}

// brainForward hands one MCP message to the brain and returns its answer.
func (h *Hub) brainForward(w http.ResponseWriter, r *http.Request) {
	if h.cfg.BrainURL == "" {
		http.Error(w, "the second brain is not set up on this hub", http.StatusNotFound)
		return
	}
	target, err := url.Parse(h.cfg.BrainURL)
	if err != nil {
		http.Error(w, "bad brain address", http.StatusInternalServerError)
		return
	}
	body := http.MaxBytesReader(w, r.Body, 4<<20)
	req, err := http.NewRequestWithContext(r.Context(), http.MethodPost, target.String(), body)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := brainClient.Do(req)
	if err != nil {
		h.log.Warn("brain", "err", err)
		http.Error(w, "the second brain is not answering", http.StatusBadGateway)
		return
	}
	defer res.Body.Close()
	if ct := res.Header.Get("Content-Type"); ct != "" {
		w.Header().Set("Content-Type", ct)
	}
	w.WriteHeader(res.StatusCode)
	_, _ = io.Copy(w, res.Body)
}
