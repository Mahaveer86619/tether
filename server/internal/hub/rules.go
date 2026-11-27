package hub

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"sort"
	"strings"
	"time"
)

// Standing rules: instructions the user wants followed in every session they
// cover ("no comments in code", "keep docs/ current"). They are kept on the
// hub and added to the system prompt of the sessions of a chat. See
// docs/plans/prompt-desk.md#rules.

const rulesKey = "rules"

const (
	scopeAll     = "all"
	scopeDevice  = "device"
	scopeProject = "project"
)

const maxRuleText = 2000

type rule struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Text      string `json:"text"`
	Scope     string `json:"scope"`
	Node      string `json:"node,omitempty"`
	Cwd       string `json:"cwd,omitempty"`
	On        bool   `json:"on"`
	UpdatedMs int64  `json:"updatedMs"`
}

// rulesList returns every rule, oldest first. Caller holds h.mu.
func (h *Hub) rulesList() []rule {
	var out []rule
	if b, err := h.store.Get(rulesKey); err == nil && b != nil {
		_ = json.Unmarshal(b, &out)
	}
	return out
}

func (h *Hub) saveRules(list []rule) *opError {
	b, err := json.Marshal(list)
	if err == nil {
		err = h.store.Put(rulesKey, b)
	}
	if err != nil {
		return internalError(err)
	}
	return nil
}

// precision orders scopes so a more specific rule comes after (and so
// overrides) a general one.
func precision(scope string) int {
	switch scope {
	case scopeProject:
		return 2
	case scopeDevice:
		return 1
	}
	return 0
}

// rulesFor are the rules that are on and cover a session on node in cwd, the
// general ones first.
func rulesFor(list []rule, node, cwd string) []rule {
	var out []rule
	for _, r := range list {
		if !r.On {
			continue
		}
		switch r.Scope {
		case scopeAll:
		case scopeDevice:
			if r.Node != node {
				continue
			}
		case scopeProject:
			if r.Node != node || normPath(r.Cwd) != normPath(cwd) {
				continue
			}
		default:
			continue
		}
		out = append(out, r)
	}
	sort.SliceStable(out, func(i, j int) bool { return precision(out[i].Scope) < precision(out[j].Scope) })
	return out
}

// rulesPrompt is the standing rules for a session, or "". Caller holds h.mu.
func (h *Hub) rulesPrompt(node, cwd string) string {
	rs := rulesFor(h.rulesList(), node, cwd)
	if len(rs) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("\n\nStanding rules from the user, which apply to everything you do here (a later rule is more specific and wins over an earlier one):")
	for _, r := range rs {
		b.WriteString("\n- " + strings.Join(strings.Fields(r.Text), " "))
	}
	return b.String()
}

func checkRule(in *rule) *opError {
	in.Name = strings.TrimSpace(in.Name)
	in.Text = strings.TrimSpace(in.Text)
	if in.Text == "" {
		return invalid("a rule needs its text")
	}
	if len(in.Text) > maxRuleText {
		return invalid("a rule is at most 2000 characters; split it in two")
	}
	if in.Name == "" {
		in.Name = in.Text
		if len(in.Name) > 40 {
			in.Name = strings.TrimSpace(in.Name[:40]) + "…"
		}
	}
	switch in.Scope {
	case "":
		in.Scope = scopeAll
	case scopeAll:
	case scopeDevice:
		if in.Node == "" {
			return invalid("a rule for a device needs the device")
		}
	case scopeProject:
		if in.Node == "" || strings.TrimSpace(in.Cwd) == "" {
			return invalid("a rule for a project needs its device and folder")
		}
	default:
		return invalid("scope is all, device or project")
	}
	if in.Scope != scopeProject {
		in.Cwd = ""
	}
	if in.Scope == scopeAll {
		in.Node = ""
	}
	return nil
}

func newRuleID() string {
	b := make([]byte, 6)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func (h *Hub) rulesRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/rules", h.authed(func(w http.ResponseWriter, r *http.Request) {
		h.mu.Lock()
		list := h.rulesList()
		h.mu.Unlock()
		if list == nil {
			list = []rule{}
		}
		writePlainJSON(w, map[string]any{"rules": list})
	}))
	// POST creates a rule, PUT /{id} replaces one: both take the rule's fields.
	write := func(w http.ResponseWriter, r *http.Request, id string) {
		var in rule
		if json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBody)).Decode(&in) != nil {
			writeError(w, invalid("malformed JSON"))
			return
		}
		if err := checkRule(&in); err != nil {
			writeError(w, err)
			return
		}
		in.UpdatedMs = time.Now().UnixMilli()
		h.mu.Lock()
		defer h.mu.Unlock()
		list := h.rulesList()
		if id == "" {
			in.ID = newRuleID()
			list = append(list, in)
		} else {
			found := false
			for i := range list {
				if list[i].ID == id {
					in.ID = id
					list[i] = in
					found = true
				}
			}
			if !found {
				writeError(w, &opError{"not_found", "no such rule", http.StatusNotFound})
				return
			}
		}
		if err := h.saveRules(list); err != nil {
			writeError(w, err)
			return
		}
		writePlainJSON(w, in)
	}
	mux.HandleFunc("POST /api/v1/rules", h.authed(func(w http.ResponseWriter, r *http.Request) { write(w, r, "") }))
	mux.HandleFunc("PUT /api/v1/rules/{id}", h.authed(func(w http.ResponseWriter, r *http.Request) { write(w, r, r.PathValue("id")) }))
	mux.HandleFunc("DELETE /api/v1/rules/{id}", h.authed(func(w http.ResponseWriter, r *http.Request) {
		h.mu.Lock()
		defer h.mu.Unlock()
		list := h.rulesList()
		kept := list[:0]
		for _, x := range list {
			if x.ID != r.PathValue("id") {
				kept = append(kept, x)
			}
		}
		if len(kept) == len(list) {
			writeError(w, &opError{"not_found", "no such rule", http.StatusNotFound})
			return
		}
		if err := h.saveRules(kept); err != nil {
			writeError(w, err)
			return
		}
		writePlainJSON(w, map[string]bool{"ok": true})
	}))
}

func (h *Hub) mcpListRules(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	rs := rulesFor(h.rulesList(), str(args, "node"), str(args, "cwd"))
	out := []map[string]any{}
	for _, r := range rs {
		out = append(out, map[string]any{"name": r.Name, "rule": r.Text, "scope": r.Scope})
	}
	return jsonText(out)
}
