package hub

import (
	"encoding/json"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/Mahaveer86619/tether/server/internal/skills"
)

// The routines that keep coming back across the user's sessions, read-only.
// See docs/skills.md. Reading every timeline takes a moment, so an answer is
// kept for a few minutes.

const skillCacheTTL = 5 * time.Minute

type skillCache struct {
	mu   sync.Mutex
	key  string
	at   time.Time
	body []byte
}

type skillStep struct {
	Key      string  `json:"key"`
	Detail   string  `json:"detail"`
	Mutating bool    `json:"mutating"`
	Share    float64 `json:"share"`
}

type skillCandidate struct {
	Example  string      `json:"example"`
	Requests []string    `json:"requests"`
	Runs     int         `json:"runs"`
	Sessions int         `json:"sessions"`
	Nodes    []string    `json:"nodes"`
	Cwds     []string    `json:"cwds"`
	Mutating bool        `json:"mutating"`
	Clean    float64     `json:"clean"`
	FirstMs  int64       `json:"firstMs"`
	LastMs   int64       `json:"lastMs"`
	Steps    []skillStep `json:"steps"`
}

type skillReport struct {
	GeneratedMs int64            `json:"generatedMs"`
	Sessions    int              `json:"sessions"`
	Tasks       int              `json:"tasks"`
	Candidates  []skillCandidate `json:"candidates"`
}

func (h *Hub) skillRoutes(mux *http.ServeMux) {
	// GET /api/v1/skills/candidates?days=30&runs=3 (days=0 for all of history).
	mux.HandleFunc("GET /api/v1/skills/candidates", h.authed(func(w http.ResponseWriter, r *http.Request) {
		days, runs := atoiOr(r.URL.Query().Get("days"), 30), atoiOr(r.URL.Query().Get("runs"), 3)
		body, err := h.skillReport(days, max(runs, 2))
		if err != nil {
			writeError(w, internalError(err))
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(body)
	}))
}

func atoiOr(s string, def int) int {
	if n, err := strconv.Atoi(s); err == nil && n >= 0 {
		return n
	}
	return def
}

func (h *Hub) skillReport(days, runs int) ([]byte, error) {
	key := strconv.Itoa(days) + "/" + strconv.Itoa(runs)
	c := &h.skills
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.key == key && time.Since(c.at) < skillCacheTTL {
		return c.body, nil
	}
	tasks, sessions, err := skills.Collect(h.store)
	if err != nil {
		return nil, err
	}
	now := time.Now()
	o := skills.DefaultOptions(now.UnixMilli())
	o.MinRuns = runs
	o.WindowMs = int64(days) * 24 * 3600 * 1000
	rep := skillReport{GeneratedMs: now.UnixMilli(), Sessions: sessions, Tasks: len(tasks), Candidates: []skillCandidate{}}
	for _, c := range skills.Cluster(tasks, o) {
		sc := skillCandidate{
			Example: c.Example, Runs: len(c.Runs), Sessions: c.Sessions, Nodes: c.Nodes, Cwds: c.Cwds,
			Mutating: c.Mutating, Clean: c.Clean, FirstMs: c.FirstMs, LastMs: c.LastMs,
		}
		for _, t := range c.Runs[max(0, len(c.Runs)-5):] {
			sc.Requests = append(sc.Requests, t.Request)
		}
		for _, s := range c.Steps {
			sc.Steps = append(sc.Steps, skillStep{Key: s.Key, Detail: s.Detail, Mutating: s.Mutating, Share: s.Share})
		}
		rep.Candidates = append(rep.Candidates, sc)
	}
	body, err := json.Marshal(rep)
	if err != nil {
		return nil, err
	}
	c.key, c.at, c.body = key, now, body
	return body, nil
}
