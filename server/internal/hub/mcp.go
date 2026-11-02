package hub

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// The hub's MCP server (streamable HTTP, JSON responses) at /mcp. It lets a
// Claude session on any node see the other nodes and sessions, start work
// elsewhere and wait for it, and use the artifact store. Agents register it
// in Claude Code on their machine. See docs/plan.md.

const (
	mcpProtocol   = "2025-06-18"
	mcpSource     = "Claude (Tether MCP)"
	mcpReadLimit  = 256 << 10
	mcpWaitMax    = 900
	mcpWaitPoll   = time.Second
	mcpItemsShown = 20
)

type rpcRequest struct {
	ID     json.RawMessage `json:"id"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type mcpTool struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	InputSchema map[string]any `json:"inputSchema"`
	call        func(h *Hub, args map[string]any) (string, error)
}

func schema(required []string, props map[string]string) map[string]any {
	p := map[string]any{}
	for name, desc := range props {
		typ, d, _ := strings.Cut(desc, ":")
		p[name] = map[string]any{"type": typ, "description": strings.TrimSpace(d)}
	}
	if required == nil {
		required = []string{}
	}
	return map[string]any{"type": "object", "properties": p, "required": required}
}

var mcpTools = []mcpTool{
	{
		Name:        "list_nodes",
		Description: "The machines connected to Tether: name, OS, whether online, and which one is the hub's own machine (where hub sessions run).",
		InputSchema: schema(nil, nil),
		call:        (*Hub).mcpListNodes,
	},
	{
		Name:        "list_sessions",
		Description: "Claude Code sessions across machines, newest first: id, title, machine, state, folder.",
		InputSchema: schema(nil, map[string]string{
			"node":      "string: only this machine",
			"live_only": "boolean: only sessions with a running Claude Code process",
			"limit":     "integer: at most this many (default 20)",
		}),
		call: (*Hub).mcpListSessions,
	},
	{
		Name:        "start_session",
		Description: "Start a Claude Code session with a first prompt. Without node it runs on the hub's machine in a scratch folder. Returns the session id; use wait_for_session to get the result.",
		InputSchema: schema([]string{"prompt"}, map[string]string{
			"prompt": "string: what the new session should do",
			"node":   "string: the machine to run on; omit for a hub session",
			"cwd":    "string: folder on that machine (default: its home folder)",
			"model":  "string: e.g. sonnet, opus, haiku",
			"chat":   "string: the Tether chat you are working in, if your instructions name one; the session then shows in that chat",
		}),
		call: (*Hub).mcpStartSession,
	},
	{
		Name: "set_chat_target",
		Description: "Record where a Tether chat should work: a machine and folder, or scratch for no project. " +
			"By default Tether then carries the conversation over to a new session there, which takes over the chat.",
		InputSchema: schema([]string{"chat"}, map[string]string{
			"chat":    "string: the chat id from your instructions",
			"node":    "string: the machine, as list_nodes names it",
			"cwd":     "string: the folder on that machine",
			"scratch": "boolean: no project; a fresh scratch folder on the hub's machine",
			"reason":  "string: one line on why this folder, shown to the user",
			"move":    "boolean: carry the conversation over now (default true)",
		}),
		call: (*Hub).mcpSetChatTarget,
	},
	{
		Name:        "send_message",
		Description: "Send a message to an existing session, as the user would.",
		InputSchema: schema([]string{"session", "text"}, map[string]string{
			"session": "string: session id",
			"text":    "string: the message",
		}),
		call: (*Hub).mcpSendMessage,
	},
	{
		Name:        "read_session",
		Description: "A session's state and its latest conversation as text: messages, and tool calls as one line each.",
		InputSchema: schema([]string{"session"}, map[string]string{
			"session": "string: session id",
			"last":    "integer: how many recent items (default 20)",
		}),
		call: (*Hub).mcpReadSession,
	},
	{
		Name:        "wait_for_session",
		Description: "Wait until a session finishes its current turn (or needs approval), then return its state and latest reply.",
		InputSchema: schema([]string{"session"}, map[string]string{
			"session":         "string: session id",
			"timeout_seconds": "integer: give up after this long (default 300, at most 900)",
		}),
		call: (*Hub).mcpWait,
	},
	{
		Name:        "list_artifacts",
		Description: "Files in Tether's central artifact store: screenshots, documents and attachments sessions read, wrote or were given.",
		InputSchema: schema(nil, map[string]string{
			"session": "string: only this session's files",
			"limit":   "integer: at most this many (default 50)",
		}),
		call: (*Hub).mcpListArtifacts,
	},
	{
		Name:        "read_artifact",
		Description: "Read a text artifact, 256 KB at a time from offset. For other files, returns its details, where an attached file sits in its session's folder, and a link that works for an hour.",
		InputSchema: schema([]string{"id"}, map[string]string{"id": "string: artifact id", "offset": "integer: byte to start reading from (default 0)"}),
		call:        (*Hub).mcpReadArtifact,
	},
	{
		Name:        "save_artifact",
		Description: "Save text to the central artifact store, e.g. a report or notes to keep or hand to another session.",
		InputSchema: schema([]string{"name", "content"}, map[string]string{
			"name":    "string: file name, e.g. report.md",
			"content": "string: the text",
			"session": "string: the session it belongs to",
		}),
		call: (*Hub).mcpSaveArtifact,
	},
}

func (h *Hub) serveMCP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", "POST")
		http.Error(w, "this MCP server answers POST requests only", http.StatusMethodNotAllowed)
		return
	}
	if _, err := h.auth(r, true); err != nil {
		writeError(w, err)
		return
	}
	var req rpcRequest
	if err := json.NewDecoder(io.LimitReader(r.Body, maxBody)).Decode(&req); err != nil {
		writeRPC(w, nil, nil, &rpcError{-32700, "could not parse the request"})
		return
	}
	if len(req.ID) == 0 { // a notification
		w.WriteHeader(http.StatusAccepted)
		return
	}
	switch req.Method {
	case "initialize":
		var p struct {
			ProtocolVersion string `json:"protocolVersion"`
		}
		_ = json.Unmarshal(req.Params, &p)
		writeRPC(w, req.ID, map[string]any{
			"protocolVersion": firstNonEmpty(p.ProtocolVersion, mcpProtocol),
			"capabilities":    map[string]any{"tools": map[string]any{}},
			"serverInfo":      map[string]any{"name": "tether", "version": h.cfg.Version},
			"instructions": "Tether connects the user's machines and their Claude Code sessions. Use it to see and start sessions on other machines, and to read and save files in the shared artifact store. " +
				"To show the user something as a web page (a demo, a visual explanation, a report), write it under .tether/pages/<name>/ in the session's folder, with index.html as the entry and relative links to its other files; Tether hosts it and the user opens it from the app.",
		}, nil)
	case "ping":
		writeRPC(w, req.ID, map[string]any{}, nil)
	case "tools/list":
		writeRPC(w, req.ID, map[string]any{"tools": mcpTools}, nil)
	case "tools/call":
		var p struct {
			Name      string         `json:"name"`
			Arguments map[string]any `json:"arguments"`
		}
		_ = json.Unmarshal(req.Params, &p)
		for _, t := range mcpTools {
			if t.Name == p.Name {
				text, err := t.call(h, p.Arguments)
				isErr := err != nil
				if isErr {
					text = err.Error()
				}
				writeRPC(w, req.ID, map[string]any{"content": []map[string]any{{"type": "text", "text": text}}, "isError": isErr}, nil)
				return
			}
		}
		writeRPC(w, req.ID, nil, &rpcError{-32602, "unknown tool " + p.Name})
	default:
		writeRPC(w, req.ID, nil, &rpcError{-32601, "unknown method " + req.Method})
	}
}

func writeRPC(w http.ResponseWriter, id json.RawMessage, result any, e *rpcError) {
	out := map[string]any{"jsonrpc": "2.0", "id": id}
	if e != nil {
		out["error"] = e
	} else {
		out["result"] = result
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(out)
}

func str(args map[string]any, k string) string {
	s, _ := args[k].(string)
	return strings.TrimSpace(s)
}

func num(args map[string]any, k string, def int) int {
	if f, ok := args[k].(float64); ok && f > 0 {
		return int(f)
	}
	return def
}

func jsonText(v any) (string, error) {
	b, err := json.MarshalIndent(v, "", "  ")
	return string(b), err
}

func opErr(e *opError) error {
	if e == nil {
		return nil
	}
	return fmt.Errorf("%s", e.Message)
}

func stateName(s v1.SessionState) string {
	return strings.ToLower(strings.TrimPrefix(s.String(), "SESSION_STATE_"))
}

func (h *Hub) mcpListNodes(map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	hub := h.hubNode()
	var out []map[string]any
	for _, n := range h.nodes {
		out = append(out, map[string]any{"name": n.Node, "os": n.Os, "online": n.Online, "hub": n.Node == hub, "running_sessions": n.RunningSessions})
	}
	sort.Slice(out, func(i, j int) bool { return out[i]["name"].(string) < out[j]["name"].(string) })
	return jsonText(out)
}

func (h *Hub) mcpListSessions(args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	node, liveOnly, limit := str(args, "node"), args["live_only"] == true, num(args, "limit", 20)
	var list []*v1.SessionInfo
	for _, s := range h.sessions {
		if (node == "" || s.Node == node) && (!liveOnly || live(s.State)) {
			list = append(list, s)
		}
	}
	sort.Slice(list, func(i, j int) bool { return list[i].UpdatedMs > list[j].UpdatedMs })
	var out []map[string]any
	for _, s := range list[:min(limit, len(list))] {
		out = append(out, map[string]any{
			"id": s.Id, "title": s.Title, "node": s.Node, "state": stateName(s.State), "cwd": s.Cwd,
			"updated": time.UnixMilli(s.UpdatedMs).Format(time.RFC3339),
		})
	}
	return jsonText(out)
}

func (h *Hub) mcpStartSession(args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	cs := &v1.CreateSession{Prompt: str(args, "prompt"), Node: str(args, "node"), Cwd: str(args, "cwd"), Model: str(args, "model")}
	cs.Scratch = cs.Node == ""
	chat := h.chats[str(args, "chat")]
	if str(args, "chat") != "" && chat == nil {
		return "", fmt.Errorf("unknown chat %s", str(args, "chat"))
	}
	extra := startExtra{}
	if chat != nil {
		extra.systemPrompt = h.chatPromptFor(chat, cs.Node, true)
		if cs.Scratch {
			extra.systemPrompt = h.chatPromptFor(chat, h.hubNode(), true)
		}
	}
	id, err := h.startSession(cs, mcpSource, extra)
	if err != nil {
		return "", opErr(err)
	}
	if chat != nil {
		h.link(chat, id, linkStarted)
		h.putChat(chat)
	}
	return "Started session " + id + " on " + h.sessions[id].Node + ".", nil
}

func (h *Hub) mcpSetChatTarget(args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	move, ok := args["move"].(bool)
	if !ok {
		move = true
	}
	scratch, _ := args["scratch"].(bool)
	t := &v1.ChatTarget{Mode: targetClaude, Node: str(args, "node"), Cwd: str(args, "cwd"), Scratch: scratch,
		Reason: firstNonEmpty(str(args, "reason"), "picked by Claude")}
	if scratch {
		t.Node, t.Cwd = h.hubNode(), ""
	}
	if !scratch && h.agents[t.Node] == nil {
		return "", fmt.Errorf("%s is not online; list_nodes shows the machines that are", t.Node)
	}
	c, err := h.setChatTarget(str(args, "chat"), &v1.SetChatTarget{Target: t, Move: move && !scratch}, mcpSource)
	if err != nil {
		return "", opErr(err)
	}
	if move && !scratch {
		return "Done: the chat continues in session " + c.ActiveSession + " on " + t.Node + " in " + t.Cwd + ". Stop here; that session takes over.", nil
	}
	return "Recorded. Carry on here.", nil
}

func (h *Hub) mcpSendMessage(args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, err := h.sendMessage(&v1.SendMessage{Session: str(args, "session"), Text: str(args, "text")}, mcpSource); err != nil {
		return "", opErr(err)
	}
	return "Sent.", nil
}

func (h *Hub) mcpReadSession(args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.sessionText(str(args, "session"), num(args, "last", mcpItemsShown))
}

// sessionText is a session's state and last items as plain text. Caller
// holds h.mu.
func (h *Hub) sessionText(id string, last int) (string, error) {
	s := h.sessions[id]
	if s == nil {
		return "", fmt.Errorf("unknown session %s", id)
	}
	items, _, err := h.store.ItemsAfter(id, 0)
	if err != nil {
		return "", err
	}
	sort.Slice(items, func(i, j int) bool { return items[i].Ord < items[j].Ord })
	var b strings.Builder
	fmt.Fprintf(&b, "Session %s on %s, %s. Title: %s\n\n", s.Id, s.Node, stateName(s.State), s.Title)
	for _, it := range items[max(0, len(items)-last):] {
		if t := itemText(it); t != "" {
			b.WriteString(t + "\n\n")
		}
	}
	return b.String(), nil
}

func itemText(it *v1.TimelineItem) string {
	switch k := it.Kind.(type) {
	case *v1.TimelineItem_User:
		return "User: " + k.User.Text
	case *v1.TimelineItem_Markdown:
		return "Claude: " + blocksText(k.Markdown.Blocks)
	case *v1.TimelineItem_Tool:
		return fmt.Sprintf("[%s] %s (%s)", k.Tool.Name, k.Tool.Title, strings.ToLower(strings.TrimPrefix(k.Tool.Status.String(), "STATUS_")))
	case *v1.TimelineItem_Notice:
		return "Note: " + k.Notice.Text
	}
	return ""
}

func blocksText(blocks []*v1.Block) string {
	var parts []string
	for _, bl := range blocks {
		switch k := bl.Kind.(type) {
		case *v1.Block_Heading:
			parts = append(parts, spansText(k.Heading.Spans))
		case *v1.Block_Paragraph:
			parts = append(parts, spansText(k.Paragraph.Spans))
		case *v1.Block_Code:
			parts = append(parts, "```"+k.Code.Lang+"\n"+k.Code.Text+"\n```")
		case *v1.Block_List:
			for _, li := range k.List.Items {
				parts = append(parts, "- "+blocksText(li.Blocks))
			}
		case *v1.Block_Quote:
			parts = append(parts, "> "+blocksText(k.Quote.Blocks))
		case *v1.Block_Table:
			var row []string
			for _, c := range k.Table.Header {
				row = append(row, spansText(c.Spans))
			}
			parts = append(parts, strings.Join(row, " | "))
			for _, r := range k.Table.Rows {
				row = row[:0]
				for _, c := range r.Cells {
					row = append(row, spansText(c.Spans))
				}
				parts = append(parts, strings.Join(row, " | "))
			}
		}
	}
	return strings.Join(parts, "\n")
}

func spansText(spans []*v1.Span) string {
	var b strings.Builder
	for _, s := range spans {
		b.WriteString(s.Text)
	}
	return b.String()
}

func (h *Hub) mcpWait(args map[string]any) (string, error) {
	id := str(args, "session")
	deadline := time.Now().Add(time.Duration(min(num(args, "timeout_seconds", 300), mcpWaitMax)) * time.Second)
	// Give a just-started session a moment to report that it is working.
	time.Sleep(2 * mcpWaitPoll)
	for {
		h.mu.Lock()
		s := h.sessions[id]
		if s == nil {
			h.mu.Unlock()
			return "", fmt.Errorf("unknown session %s", id)
		}
		if s.State != v1.SessionState_SESSION_STATE_RUNNING || time.Now().After(deadline) {
			text, err := h.sessionText(id, 6)
			h.mu.Unlock()
			if s.State == v1.SessionState_SESSION_STATE_RUNNING {
				text = "Still working when the wait ran out.\n\n" + text
			}
			return text, err
		}
		h.mu.Unlock()
		time.Sleep(mcpWaitPoll)
	}
}

func (h *Hub) mcpListArtifacts(args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	list, err := h.store.Artifacts(str(args, "session"), num(args, "limit", 50))
	if err != nil {
		return "", err
	}
	var out []map[string]any
	for _, a := range list {
		out = append(out, map[string]any{
			"id": a.Id, "name": a.Name, "mime": a.Mime, "size": a.Size, "session": a.Session, "node": a.Node, "origin": a.Origin,
			"sha256": a.Sha256, "note": a.Note, "created": time.UnixMilli(a.CreatedMs).Format(time.RFC3339),
		})
	}
	return jsonText(out)
}

func (h *Hub) mcpReadArtifact(args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	a, err := h.store.Artifact(str(args, "id"))
	if err != nil || a == nil {
		return "", fmt.Errorf("unknown artifact %s", str(args, "id"))
	}
	text := strings.HasPrefix(a.Mime, "text/") || strings.Contains(a.Mime, "json") || strings.HasSuffix(a.Name, ".md")
	offset := int64(num(args, "offset", 0))
	if !text || offset < 0 || offset >= max(a.Size, 1) {
		link, lerr := h.artifactLink(a.Id, time.Hour)
		if lerr != nil {
			return "", opErr(lerr)
		}
		where := ""
		if a.Origin == "attachment" && a.Session != "" {
			where = fmt.Sprintf(" It was attached to session %s, whose folder has it as .tether/attachments/%s.", a.Session, a.Name)
		}
		return fmt.Sprintf("%s (%s, %d bytes, sha256 %s) isn't text Tether can show here.%s It also downloads from the hub at %s for an hour.",
			a.Name, a.Mime, a.Size, a.Sha256, where, link.Url), nil
	}
	f, err := os.Open(h.blobPath(a.Sha256))
	if err != nil {
		return "", err
	}
	defer f.Close()
	b := make([]byte, min(mcpReadLimit, a.Size-offset))
	n, err := f.ReadAt(b, offset)
	if err != nil && n < len(b) {
		return "", err
	}
	if end := offset + int64(n); offset > 0 || end < a.Size {
		return fmt.Sprintf("[bytes %d-%d of %d; pass offset %d for more]\n%s", offset, end, a.Size, end, b[:n]), nil
	}
	return string(b[:n]), nil
}

func (h *Hub) mcpSaveArtifact(args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	name, content := str(args, "name"), str(args, "content")
	if name == "" {
		return "", fmt.Errorf("name is required")
	}
	sha, n, err := h.putBlob(strings.NewReader(content), "")
	if err != nil {
		return "", opErr(err)
	}
	a := &v1.Artifact{Sha256: sha, Name: name, Mime: mimeOf("", name), Size: n, Session: str(args, "session"), Origin: "upload"}
	if err := h.addArtifact(a); err != nil {
		return "", opErr(err)
	}
	return "Saved as artifact " + a.Id + ".", nil
}
