package hub

import (
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/Mahaveer86619/tether/server/internal/store"
)

// The audit log: every MCP tool call and every change to a skill, with who
// and when. It records what was asked, never the content (a skill's text, a
// saved file), so it holds nothing secret. See docs/agent-tools.md.

// auditedArgs are the arguments of a tool call worth keeping: where and
// what, not the content.
var auditedArgs = []string{"node", "cwd", "session", "chat", "name", "id", "model", "mutating"}

func (h *Hub) audit(actor, kind, subject, detail string, ok bool) {
	_ = h.store.AddAudit(store.AuditEntry{AtMs: time.Now().UnixMilli(), Actor: actor, Kind: kind, Subject: subject, Detail: detail, OK: ok})
}

func actorOf(id identity) string {
	if id.device != nil && id.device.Name != "" {
		return id.kind + ":" + id.device.Name
	}
	return id.kind
}

// auditDetail summarises a tool call's arguments.
func auditDetail(args map[string]any) string {
	var parts []string
	for _, k := range auditedArgs {
		if v, ok := args[k]; ok {
			s := strings.TrimSpace(strings.ReplaceAll(toString(v), "\n", " "))
			if len(s) > 80 {
				s = s[:80] + "…"
			}
			parts = append(parts, k+"="+s)
		}
	}
	sort.Strings(parts)
	return strings.Join(parts, " ")
}

func toString(v any) string {
	switch x := v.(type) {
	case string:
		return x
	case bool:
		return strconv.FormatBool(x)
	case float64:
		return strconv.FormatFloat(x, 'f', -1, 64)
	}
	return ""
}

func (h *Hub) auditRoutes(mux *http.ServeMux) {
	// GET /api/v1/audit?kind=&before=&limit= : newest first.
	mux.HandleFunc("GET /api/v1/audit", h.authed(func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		limit := 100
		if n, err := strconv.Atoi(q.Get("limit")); err == nil && n > 0 {
			limit = min(n, 500)
		}
		before, _ := strconv.ParseInt(q.Get("before"), 10, 64)
		h.mu.Lock()
		list, err := h.store.Audit(q.Get("kind"), before, limit)
		h.mu.Unlock()
		if err != nil {
			writeError(w, internalError(err))
			return
		}
		writePlainJSON(w, list)
	}))
}
