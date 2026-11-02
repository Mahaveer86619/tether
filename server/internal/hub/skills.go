package hub

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
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

// ---- the library: proposals, approved skills, corrections ----

func (h *Hub) lib() *skills.Library {
	h.libOnce.Do(func() { h.library = skills.NewLibrary(h.store) })
	return h.library
}

// skillSummary is a skill without its texts, for lists.
type skillSummary struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Status      string `json:"status"`
	Mutating    bool   `json:"mutating"`
	Source      string `json:"source"`
	Version     int    `json:"version"`
	UpdatedMs   int64  `json:"updatedMs"`
}

func summarize(s skills.Skill) skillSummary {
	return skillSummary{Name: s.Name, Description: s.Description, Status: s.Status, Mutating: s.Mutating, Source: s.Source, Version: s.Latest().N, UpdatedMs: s.UpdatedM}
}

func skillError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, skills.ErrNotFound):
		writeError(w, &opError{"not_found", "no such skill", http.StatusNotFound})
	case errors.Is(err, skills.ErrExists):
		writeError(w, &opError{"exists", err.Error(), http.StatusConflict})
	default:
		writeError(w, invalid(err.Error()))
	}
}

func writePlainJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}

func (h *Hub) skillLibraryRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/skills", h.authed(func(w http.ResponseWriter, r *http.Request) {
		all, err := h.lib().List()
		if err != nil {
			writeError(w, internalError(err))
			return
		}
		out := []skillSummary{}
		for _, s := range all {
			out = append(out, summarize(s))
		}
		writePlainJSON(w, map[string]any{"skills": out})
	}))
	mux.HandleFunc("GET /api/v1/skills/{name}", h.authed(func(w http.ResponseWriter, r *http.Request) {
		s, err := h.lib().Get(r.PathValue("name"))
		if err != nil || s.Status == "dismissed" {
			skillError(w, skills.ErrNotFound)
			return
		}
		writePlainJSON(w, s)
	}))
	act := func(do func(name string, r *http.Request, now int64) (skills.Skill, error)) http.HandlerFunc {
		return h.authed(func(w http.ResponseWriter, r *http.Request) {
			s, err := do(r.PathValue("name"), r, time.Now().UnixMilli())
			if err != nil {
				skillError(w, err)
				return
			}
			writePlainJSON(w, summarize(s))
		})
	}
	mux.HandleFunc("POST /api/v1/skills/{name}/approve", act(func(n string, _ *http.Request, now int64) (skills.Skill, error) { return h.lib().Approve(n, now) }))
	mux.HandleFunc("POST /api/v1/skills/{name}/dismiss", act(func(n string, _ *http.Request, now int64) (skills.Skill, error) { return h.lib().Dismiss(n, now) }))
	mux.HandleFunc("POST /api/v1/skills/{name}/rollback", act(func(n string, r *http.Request, now int64) (skills.Skill, error) {
		var body struct{ Version int }
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			return skills.Skill{}, errors.New("send {\"version\": n}")
		}
		return h.lib().Rollback(n, body.Version, "the owner", now)
	}))
	// POST /api/v1/skills/draft {"example": "..."} starts a session that writes
	// a skill for the routine with that example request, from what the hub kept.
	mux.HandleFunc("POST /api/v1/skills/draft", h.authed(func(w http.ResponseWriter, r *http.Request) {
		var body struct{ Example string }
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil || strings.TrimSpace(body.Example) == "" {
			writeError(w, invalid("send {\"example\": the routine's example request}"))
			return
		}
		id, err := h.draftSkill(body.Example)
		if err != nil {
			writeError(w, err)
			return
		}
		writePlainJSON(w, map[string]string{"session": id})
	}))
}

// draftSkill starts a hub session with the brief for the routine whose example
// request is example.
func (h *Hub) draftSkill(example string) (string, *opError) {
	tasks, _, err := skills.Collect(h.store)
	if err != nil {
		return "", internalError(err)
	}
	o := skills.DefaultOptions(time.Now().UnixMilli())
	o.WindowMs, o.MinRuns = 0, 2
	for _, c := range skills.Cluster(tasks, o) {
		if c.Example != example {
			continue
		}
		h.mu.Lock()
		defer h.mu.Unlock()
		cs := &v1.CreateSession{Prompt: skills.DraftBrief(c), Scratch: true, Name: "Skill: " + clip(example, 50)}
		return h.startSession(cs, "Routines", startExtra{})
	}
	return "", &opError{"not_found", "that routine is no longer in the history", http.StatusNotFound}
}

// activeSkillsPrompt tells a lead session which skills it can use, or "".
func (h *Hub) activeSkillsPrompt() string {
	active, err := h.lib().Active()
	if err != nil || len(active) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("\n\nSkills Tether has learned from this user's repeated requests (tether tool read_skill gives the steps; follow one when it fits, and fix it with update_skill if a step is wrong):")
	for _, s := range active {
		b.WriteString("\n- " + s.Name + ": " + s.Description)
	}
	return b.String()
}

// ---- hub MCP tools ----

func (h *Hub) mcpListSkills(map[string]any) (string, error) {
	active, err := h.lib().Active()
	if err != nil {
		return "", err
	}
	out := []map[string]any{}
	for _, s := range active {
		out = append(out, map[string]any{"name": s.Name, "description": s.Description, "changes_things": s.Mutating, "version": s.Latest().N})
	}
	return jsonText(out)
}

func (h *Hub) mcpReadSkill(args map[string]any) (string, error) {
	s, err := h.lib().Get(str(args, "name"))
	if err != nil || s.Status != "active" {
		return "", fmt.Errorf("no approved skill called %q; list_skills shows them", str(args, "name"))
	}
	return s.Latest().MD, nil
}

func (h *Hub) mcpProposeSkill(args map[string]any) (string, error) {
	mutating, _ := args["mutating"].(bool)
	s, err := h.lib().Propose(str(args, "skill_md"), mutating, str(args, "source"), mcpSource, time.Now().UnixMilli())
	if err != nil {
		return "", err
	}
	return "Saved " + s.Name + " for the user to approve in the Tether app. It can't be used until they do.", nil
}

func (h *Hub) mcpUpdateSkill(args map[string]any) (string, error) {
	s, err := h.lib().Get(str(args, "name"))
	if err != nil || s.Status != "active" {
		return "", fmt.Errorf("no approved skill called %q", str(args, "name"))
	}
	s, err = h.lib().Update(s.Name, str(args, "skill_md"), str(args, "note"), mcpSource, time.Now().UnixMilli())
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s is now version %d. The previous text is kept.", s.Name, s.Latest().N), nil
}
