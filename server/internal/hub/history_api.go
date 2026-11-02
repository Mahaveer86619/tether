package hub

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

// The history's REST API; see docs/history.md for the schema.

func (h *Hub) historyRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/history/status", h.api(func(r *http.Request) (proto.Message, *opError) {
		st, err := h.store.HistoryStatus()
		if err != nil {
			return nil, internalError(err)
		}
		for _, n := range st.Nodes {
			if node := h.nodes[n.Node]; node != nil && node.HistorySyncedMs > 0 {
				n.SyncedMs = node.HistorySyncedMs
			}
		}
		return st, nil
	}))
	mux.HandleFunc("GET /api/v1/history/sessions/{id}", h.api(func(r *http.Request) (proto.Message, *opError) {
		return h.historyPage(r, []string{r.PathValue("id")})
	}))
	mux.HandleFunc("GET /api/v1/chats/{id}/history", h.api(func(r *http.Request) (proto.Message, *opError) {
		c := h.chats[r.PathValue("id")]
		if c == nil {
			return nil, errChatNotFound
		}
		return h.historyPage(r, chatSessions(c))
	}))
	mux.HandleFunc("GET /api/v1/history/search", h.api(func(r *http.Request) (proto.Message, *opError) {
		q := r.URL.Query()
		text := strings.TrimSpace(q.Get("q"))
		if text == "" {
			return nil, invalid("q is required")
		}
		var sessions []string
		if id := q.Get("session"); id != "" {
			sessions = []string{id}
		}
		if id := q.Get("chat"); id != "" {
			c := h.chats[id]
			if c == nil {
				return nil, errChatNotFound
			}
			sessions = chatSessions(c)
		}
		limit, _ := strconv.Atoi(q.Get("limit"))
		events, snippets, err := h.store.SearchHistory(text, sessions, limit)
		if err != nil {
			return nil, internalError(err)
		}
		out := &v1.HistorySearch{}
		for i, e := range events {
			out.Hits = append(out.Hits, &v1.HistoryHit{Event: e, Snippet: snippets[i], Chat: h.chatOf[e.Session]})
		}
		return out, nil
	}))
	mux.HandleFunc("GET /api/v1/history/changes", h.api(func(r *http.Request) (proto.Message, *opError) {
		since, _ := strconv.ParseUint(r.URL.Query().Get("since"), 10, 64)
		limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
		out, err := h.store.HistoryChanges(since, limit)
		if err != nil {
			return nil, internalError(err)
		}
		return out, nil
	}))
	// Asks every online agent to send what the history lacks now.
	mux.HandleFunc("POST /api/v1/history/sync", h.api(func(r *http.Request) (proto.Message, *opError) {
		for node := range h.agents {
			h.requestHistory(node)
		}
		return &v1.Ack{}, nil
	}))
	// Exports stream page by page, taking the lock only for each page.
	mux.HandleFunc("GET /api/v1/history/export", h.authed(h.exportHistory))
}

func chatSessions(c *v1.Chat) []string {
	ids := make([]string, 0, len(c.Sessions))
	for _, l := range c.Sessions {
		ids = append(ids, l.Session)
	}
	return ids
}

// historyPage reads ?before=, ?after=, ?limit= and ?subagents=1. Caller
// holds h.mu.
func (h *Hub) historyPage(r *http.Request, sessions []string) (*v1.HistoryPage, *opError) {
	q := r.URL.Query()
	limit, _ := strconv.Atoi(q.Get("limit"))
	page, err := h.store.HistoryPage(store.HistoryQuery{Sessions: sessions, Subagents: q.Get("subagents") == "1", Before: q.Get("before"), After: q.Get("after"), Limit: limit})
	if err != nil {
		return nil, invalid(err.Error())
	}
	return page, nil
}

// exportHistory streams a session's, a chat's or all history as JSON lines
// (format=jsonl, the default: one HistoryEvent per line), Markdown
// (format=md), or a session's transcript lines as stored (format=raw).
func (h *Hub) exportHistory(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	format := q.Get("format")
	if format == "" {
		format = "jsonl"
	}
	h.mu.Lock()
	var sessions []string
	name := "tether-history"
	title := "All history"
	switch {
	case q.Get("session") != "":
		id := q.Get("session")
		sessions = []string{id}
		name, title = "session-"+id, "Session "+id
		if s := h.sessions[id]; s != nil {
			title = s.Title
		}
	case q.Get("chat") != "":
		c := h.chats[q.Get("chat")]
		if c == nil {
			h.mu.Unlock()
			writeError(w, errChatNotFound)
			return
		}
		sessions, name, title = chatSessions(c), "chat-"+c.Id, c.Title
	}
	h.mu.Unlock()

	switch format {
	case "raw":
		if len(sessions) != 1 {
			writeError(w, invalid("format=raw needs a session"))
			return
		}
		f, err := os.Open(h.rawPath(sessions[0], ""))
		if err != nil {
			writeError(w, errNotFound)
			return
		}
		defer f.Close()
		w.Header().Set("Content-Type", "application/x-ndjson")
		w.Header().Set("Content-Disposition", `attachment; filename="`+name+`.jsonl"`)
		_, _ = io.Copy(w, f)
		return
	case "jsonl":
		w.Header().Set("Content-Type", "application/x-ndjson")
		w.Header().Set("Content-Disposition", `attachment; filename="`+name+`.jsonl"`)
	case "md":
		w.Header().Set("Content-Type", "text/markdown; charset=utf-8")
		w.Header().Set("Content-Disposition", `attachment; filename="`+name+`.md"`)
		fmt.Fprintf(w, "# %s\n", title)
	default:
		writeError(w, invalid("format is jsonl, md or raw"))
		return
	}
	line := protojson.MarshalOptions{UseProtoNames: true}
	// Oldest first: "after the very start".
	after, lastSession := "0_0", ""
	for {
		h.mu.Lock()
		page, err := h.store.HistoryPage(store.HistoryQuery{Sessions: sessions, All: len(sessions) == 0, Subagents: q.Get("subagents") == "1", After: after, Limit: 500})
		var info map[string]*v1.SessionInfo
		if err == nil && format == "md" {
			info = map[string]*v1.SessionInfo{}
			for _, e := range page.Events {
				info[e.Session] = h.sessions[e.Session]
			}
		}
		h.mu.Unlock()
		if err != nil {
			return
		}
		for _, e := range page.Events {
			if format == "jsonl" {
				b, _ := line.Marshal(e)
				_, _ = w.Write(append(b, '\n'))
				continue
			}
			if e.Session != lastSession {
				lastSession = e.Session
				where := e.Node
				if s := info[e.Session]; s != nil {
					where = s.Node + " · " + s.Cwd
				}
				fmt.Fprintf(w, "\n---\n\n*Session %s on %s*\n", e.Session, where)
			}
			fmt.Fprintf(w, "\n%s\n", markdownEvent(e))
		}
		if !page.MoreAfter || len(page.Events) == 0 {
			return
		}
		after = page.After
		if f, ok := w.(http.Flusher); ok {
			f.Flush()
		}
	}
}

func markdownEvent(e *v1.HistoryEvent) string {
	at := time.UnixMilli(e.TsMs).UTC().Format("2006-01-02 15:04")
	switch e.Kind {
	case "user":
		return "**You** (" + at + "):\n\n" + e.Text
	case "assistant":
		return "**Claude** (" + at + "):\n\n" + e.Text
	case "tool_use":
		return "> " + strings.ReplaceAll(e.Text, "\n", "\n> ")
	case "tool_result":
		return "```\n" + clip(e.Text, 600) + "\n```"
	case "state":
		return "*(" + e.Text + ", " + at + ")*"
	}
	return "*" + e.Kind + ":* " + e.Text
}
