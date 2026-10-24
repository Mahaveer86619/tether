package hub

import (
	"net/http"
	"sort"
	"strings"
	"time"
	"unicode"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/updates"
)

// Chats are the conversations the app shows; sessions do the work behind
// them. See docs/chats.md.

const (
	linkMain    = "main"
	linkMoved   = "moved"
	linkFork    = "fork"
	linkStarted = "started"
	linkLinked  = "linked"

	targetAuto   = "auto"
	targetManual = "manual"
	targetClaude = "claude"

	targetResolved  = "resolved"
	targetDetecting = "detecting"

	// The first agent that passes StartRun.system_prompt to Claude Code.
	systemPromptVersion = "0.16.0"

	// How much of the conversation a moved session gets, newest kept.
	handoffBudget = 40_000
	handoffEach   = 4_000
)

// loadChats reads the chats into memory. Caller holds h.mu or is New.
func (h *Hub) loadChats() error {
	chats, err := h.store.Chats()
	if err != nil {
		return err
	}
	for _, c := range chats {
		h.chats[c.Id] = c
		for _, l := range c.Sessions {
			h.chatOf[l.Session] = c.Id
		}
	}
	return nil
}

func (h *Hub) chatList() []*v1.Chat {
	out := make([]*v1.Chat, 0, len(h.chats))
	for _, c := range h.chats {
		out = append(out, proto.Clone(c).(*v1.Chat))
	}
	sort.Slice(out, func(i, j int) bool { return out[i].UpdatedMs > out[j].UpdatedMs })
	return out
}

// putChat stores a chat and tells every client. Caller holds h.mu.
func (h *Hub) putChat(c *v1.Chat) {
	h.chats[c.Id] = c
	if err := h.store.PutChat(c); err != nil {
		h.log.Error("store chat", "chat", c.Id, "err", err)
	}
	h.broadcast(&v1.Frame{Body: &v1.Frame_Chat{Chat: proto.Clone(c).(*v1.Chat)}})
}

// link adds a session to a chat without storing the chat itself; callers
// follow with putChat. Caller holds h.mu.
func (h *Hub) link(c *v1.Chat, session, role string) {
	if h.chatOf[session] == c.Id {
		return
	}
	if other := h.chats[h.chatOf[session]]; other != nil {
		h.unlink(other, session)
		h.putChat(other)
	}
	l := &v1.ChatLink{Session: session, Role: role, LinkedMs: time.Now().UnixMilli()}
	if err := h.store.LinkSession(c.Id, l); err != nil {
		h.log.Error("link session", "chat", c.Id, "session", session, "err", err)
	}
	c.Sessions = append(c.Sessions, l)
	h.chatOf[session] = c.Id
	h.captureMessages(c.Id, session)
}

func (h *Hub) unlink(c *v1.Chat, session string) {
	if err := h.store.UnlinkSession(c.Id, session); err != nil {
		h.log.Error("unlink session", "chat", c.Id, "session", session, "err", err)
	}
	kept := c.Sessions[:0]
	for _, l := range c.Sessions {
		if l.Session != session {
			kept = append(kept, l)
		}
	}
	c.Sessions = kept
	delete(h.chatOf, session)
	if c.ActiveSession == session {
		c.ActiveSession = ""
		if n := len(c.Sessions); n > 0 {
			c.ActiveSession = c.Sessions[n-1].Session
		}
	}
}

// createChat starts a chat with its first session, or makes a chat of an
// existing session. Caller holds h.mu.
func (h *Hub) createChat(cc *v1.CreateChat, from string) (*v1.Chat, *opError) {
	now := time.Now().UnixMilli()
	c := &v1.Chat{Id: uuid.NewString(), CreatedMs: now, UpdatedMs: now}
	if cc.Session != "" {
		s := h.sessions[cc.Session]
		if s == nil {
			return nil, errNotFound
		}
		if existing := h.chats[h.chatOf[cc.Session]]; existing != nil {
			return proto.Clone(existing).(*v1.Chat), nil
		}
		c.Title, c.TitleByUser = firstNonEmpty(strings.TrimSpace(cc.Title), s.Title), cc.Title != ""
		c.Target = &v1.ChatTarget{Mode: targetManual, Node: s.Node, Cwd: s.Cwd, Scratch: s.Scratch, State: targetResolved, Reason: "where the session ran"}
		c.ActiveSession = s.Id
		h.link(c, s.Id, linkMain)
		h.putChat(c)
		h.runChatJobs(c)
		return proto.Clone(c).(*v1.Chat), nil
	}
	if strings.TrimSpace(cc.Prompt) == "" {
		return nil, invalid("prompt is empty")
	}
	target, err := h.resolveTarget(cc.Prompt, cc.Target)
	if err != nil {
		return nil, err
	}
	c.Target = target
	c.Title, c.TitleByUser = strings.TrimSpace(cc.Title), strings.TrimSpace(cc.Title) != ""
	if c.Title == "" {
		c.Title = autoTitle(cc.Prompt)
	}
	cs := &v1.CreateSession{Node: target.Node, Cwd: target.Cwd, Scratch: target.Scratch, Prompt: cc.Prompt,
		Model: cc.Model, PermissionMode: cc.PermissionMode, Attachments: cc.Attachments}
	// The chat must exist before the session so the system prompt can name it.
	h.chats[c.Id] = c
	system := h.chatPromptFor(c, cs.Node)
	if system == "" && target.State == targetDetecting {
		// An agent too old for a system prompt gets the instructions inline.
		cs.Prompt = detectPrompt(c.Id) + "\n\n---\n\n" + cs.Prompt
	}
	id, err := h.startSession(cs, from, startExtra{systemPrompt: system, clientID: cc.ClientId})
	if err != nil {
		delete(h.chats, c.Id)
		return nil, err
	}
	if s := h.sessions[id]; s != nil && s.Title != c.Title {
		next := proto.Clone(s).(*v1.SessionInfo)
		next.Title = c.Title
		h.putSession(next)
	}
	if !c.TitleByUser {
		h.noteTitle(c.Id, c.Title)
	}
	c.ActiveSession = id
	h.link(c, id, linkMain)
	h.putChat(c)
	h.runChatJobs(c)
	return proto.Clone(c).(*v1.Chat), nil
}

// updateChat renames or archives a chat. An empty title hands naming back
// to the title job. Caller holds h.mu.
func (h *Hub) updateChat(id string, u *v1.UpdateChat) (*v1.Chat, *opError) {
	c := h.chats[id]
	if c == nil {
		return nil, errChatNotFound
	}
	if u.Title != nil {
		title := strings.TrimSpace(*u.Title)
		c.TitleByUser = title != ""
		c.Title = clip(title, 120)
	}
	if u.Archived != nil {
		c.Archived = *u.Archived
	}
	c.UpdatedMs = max(c.UpdatedMs, time.Now().UnixMilli())
	if u.Title != nil && !c.TitleByUser {
		h.runChatJobs(c)
	}
	h.putChat(c)
	return proto.Clone(c).(*v1.Chat), nil
}

var errChatNotFound = &opError{"not_found", "unknown chat", http.StatusNotFound}

// chatSend sends a message to the chat's active session. When that session
// is gone (its folder was cleaned up, say), the chat carries on in a new
// one at its target. Caller holds h.mu.
func (h *Hub) chatSend(id string, m *v1.SendMessage, from string) (string, *opError) {
	c := h.chats[id]
	if c == nil {
		return "", errChatNotFound
	}
	if strings.TrimSpace(m.Text) == "" {
		return "", invalid("message is empty")
	}
	var session string
	var err *opError
	if h.sessions[c.ActiveSession] == nil {
		session, err = h.moveChat(c, c.Target, m.Text, m.Attachments, from, m.ClientId)
	} else {
		m.Session = c.ActiveSession
		session, err = h.sendMessage(m, from)
	}
	if err != nil {
		return "", err
	}
	c.UpdatedMs, c.Archived = time.Now().UnixMilli(), false
	h.putChat(c)
	return session, nil
}

// setChatTarget records where a chat should work and, with move, carries
// the conversation over to a new session there. Caller holds h.mu.
func (h *Hub) setChatTarget(id string, st *v1.SetChatTarget, from string) (*v1.Chat, *opError) {
	c := h.chats[id]
	if c == nil {
		return nil, errChatNotFound
	}
	t := proto.Clone(st.GetTarget()).(*v1.ChatTarget)
	if t == nil || t.Node == "" && !t.Scratch {
		return nil, invalid("a node, or scratch, is required")
	}
	t.Mode = firstNonEmpty(t.Mode, targetManual)
	t.State = targetResolved
	if t.Reason == "" && t.Mode == targetManual {
		t.Reason = "picked by you"
	}
	prev := c.Target
	c.Target = t
	if st.Move {
		if _, err := h.moveChat(c, t, st.Text, nil, from, ""); err != nil {
			c.Target = prev
			return nil, err
		}
	}
	c.UpdatedMs = time.Now().UnixMilli()
	h.putChat(c)
	return proto.Clone(c).(*v1.Chat), nil
}

// moveChat starts a session at target that carries on the conversation,
// and makes it the active one. Caller holds h.mu and saves c.
func (h *Hub) moveChat(c *v1.Chat, t *v1.ChatTarget, text string, attachments []string, from, clientID string) (string, *opError) {
	if t == nil {
		return "", invalid("the chat has no target")
	}
	text = strings.TrimSpace(text)
	if text == "" {
		text = "Carry on with the task from where the conversation above left off."
	}
	prompt := text
	if history := h.handoff(c); history != "" {
		prompt = "This continues an earlier conversation from another Claude Code session, which ran somewhere else. " +
			"Here it is, oldest first:\n\n" + history + "\n\n---\n\n" + text
	}
	cs := &v1.CreateSession{Node: t.Node, Cwd: t.Cwd, Scratch: t.Scratch, Prompt: prompt, Attachments: attachments}
	if s := h.sessions[c.ActiveSession]; s != nil {
		cs.Model = s.Model
	}
	id, err := h.startSession(cs, from, startExtra{systemPrompt: h.chatPromptFor(c, cs.Node), clientID: clientID})
	if err != nil {
		return "", err
	}
	if s := h.sessions[id]; s != nil {
		next := proto.Clone(s).(*v1.SessionInfo)
		next.Title, next.LastPrompt = c.Title, text
		if prev := h.sessions[c.ActiveSession]; prev != nil {
			next.Parent, next.Lineage = prev.Id, "move"
		}
		h.putSession(next)
		h.recordLineage(&v1.LineageEvent{Session: id, Parent: c.ActiveSession, Kind: "move", By: from, AtMs: next.CreatedMs, Detail: "chat " + c.Id})
	}
	h.link(c, id, linkMoved)
	c.ActiveSession = id
	return id, nil
}

// handoff is the chat so far as text, trimmed to fit a first message.
func (h *Hub) handoff(c *v1.Chat) string {
	msgs, err := h.store.ChatMessages(c.Id)
	if err != nil {
		h.log.Error("chat messages", "chat", c.Id, "err", err)
		return ""
	}
	var parts []string
	used := 0
	for i := len(msgs) - 1; i >= 0 && used < handoffBudget; i-- {
		who := "User"
		if msgs[i].Role == "assistant" {
			who = "Claude"
		}
		p := who + ": " + clip(msgs[i].Text, handoffEach)
		parts = append(parts, p)
		used += len(p)
	}
	for i, j := 0, len(parts)-1; i < j; i, j = i+1, j-1 {
		parts[i], parts[j] = parts[j], parts[i]
	}
	return strings.Join(parts, "\n\n")
}

// linkToChat adds or removes a session by hand. Caller holds h.mu.
func (h *Hub) linkToChat(id string, ls *v1.LinkSession) (*v1.Chat, *opError) {
	c := h.chats[id]
	if c == nil {
		return nil, errChatNotFound
	}
	if ls.Unlink {
		if h.chatOf[ls.Session] != id {
			return nil, errNotFound
		}
		h.unlink(c, ls.Session)
	} else {
		if h.sessions[ls.Session] == nil {
			return nil, errNotFound
		}
		h.link(c, ls.Session, firstNonEmpty(ls.Role, linkLinked))
	}
	c.UpdatedMs = time.Now().UnixMilli()
	h.putChat(c)
	return proto.Clone(c).(*v1.Chat), nil
}

// chatContext is what was said in a chat plus what jobs made of it.
// Caller holds h.mu.
func (h *Hub) chatContext(id string) (*v1.ChatContext, *opError) {
	c := h.chats[id]
	if c == nil {
		return nil, errChatNotFound
	}
	msgs, err := h.store.ChatMessages(id)
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	notes, err := h.store.ChatNotes(id)
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	return &v1.ChatContext{Chat: proto.Clone(c).(*v1.Chat), Messages: msgs, Notes: notes}, nil
}

// ---- following sessions ----

// noteNewSession links a session that split off from one in a chat: a fork
// or a continue on the hub. Splitting off the active session moves the
// chat along with it. Caller holds h.mu.
func (h *Hub) noteNewSession(s *v1.SessionInfo) {
	if s.Parent == "" || h.chatOf[s.Id] != "" {
		return
	}
	c := h.chats[h.chatOf[s.Parent]]
	if c == nil {
		return
	}
	h.link(c, s.Id, linkFork)
	if c.ActiveSession == s.Parent {
		c.ActiveSession = s.Id
	}
	c.UpdatedMs = time.Now().UnixMilli()
	h.putChat(c)
}

// noteTurnEnded runs a chat's jobs when one of its sessions finishes a
// turn. Caller holds h.mu.
func (h *Hub) noteTurnEnded(session string) {
	c := h.chats[h.chatOf[session]]
	if c == nil {
		return
	}
	if s := h.sessions[session]; s != nil && s.UpdatedMs > c.UpdatedMs {
		c.UpdatedMs = s.UpdatedMs
	}
	h.runChatJobs(c)
	h.putChat(c)
}

// keepMessages stores the user and assistant messages among items, if
// their session is in a chat. Caller holds h.mu.
func (h *Hub) keepMessages(session string, items []*v1.TimelineItem) {
	chat := h.chatOf[session]
	if chat == "" {
		return
	}
	if err := h.store.PutChatMessages(chat, chatMessages(session, items)); err != nil {
		h.log.Error("store chat messages", "chat", chat, "err", err)
	}
}

// captureMessages stores what a session said before it joined a chat.
func (h *Hub) captureMessages(chat, session string) {
	items, _, err := h.store.ItemsAfter(session, 0)
	if err != nil {
		h.log.Error("items", "session", session, "err", err)
		return
	}
	sort.Slice(items, func(i, j int) bool { return items[i].Ord < items[j].Ord })
	if err := h.store.PutChatMessages(chat, chatMessages(session, items)); err != nil {
		h.log.Error("store chat messages", "chat", chat, "err", err)
	}
}

func chatMessages(session string, items []*v1.TimelineItem) []*v1.ChatMessage {
	var out []*v1.ChatMessage
	for _, it := range items {
		// Sub-agents' chatter isn't part of the conversation.
		if it.ParentToolUseId != "" {
			continue
		}
		m := &v1.ChatMessage{Session: session, ItemId: it.ItemId, TsMs: it.TsMs}
		switch k := it.Kind.(type) {
		case *v1.TimelineItem_User:
			if k.User.Queued {
				continue
			}
			m.Role, m.Text = "user", k.User.Text
		case *v1.TimelineItem_Markdown:
			m.Role, m.Text = "assistant", blocksText(k.Markdown.Blocks)
		default:
			continue
		}
		if strings.TrimSpace(m.Text) != "" {
			out = append(out, m)
		}
	}
	return out
}

// ---- system prompt ----

// chatPromptFor is the system prompt for a new session of chat c on node,
// or "" when the node's agent can't pass one on. Caller holds h.mu.
func (h *Hub) chatPromptFor(c *v1.Chat, node string) string {
	if !h.agentAtLeast(node, systemPromptVersion) {
		return ""
	}
	p := "You are working in a Tether chat (id " + c.Id + "): the user talks to you from the Tether app. " +
		"When you start a session on another machine with the tether MCP tool start_session, pass chat=\"" + c.Id + "\" so it shows in this chat."
	if c.Target.GetState() == targetDetecting {
		p += "\n\n" + detectPrompt(c.Id)
	}
	return p
}

// detectPrompt asks Claude to find out where a chat belongs and report it.
func detectPrompt(chat string) string {
	return "The user didn't say which project or folder this is about, so you were started in an empty scratch folder. " +
		"Before doing the task, work out where it belongs: the user's words, and the tether MCP tools list_nodes and list_sessions " +
		"(recent sessions show the folders the user works in, and on which machine). " +
		"If one place is clearly meant, say which in one line and why. If not, ask the user, listing the likely options, and wait for the answer. " +
		"Then call the tether tool set_chat_target with chat=\"" + chat + "\", node and cwd. Tether carries this conversation over to a new session in that folder, " +
		"so stop after calling it. If the task needs no project (a general question), just answer it here and call set_chat_target with scratch=true."
}

// chatSystemPrompt is the system prompt to resume session with, if it's in
// a chat. Caller holds h.mu.
func (h *Hub) chatSystemPrompt(session string) string {
	c := h.chats[h.chatOf[session]]
	s := h.sessions[session]
	if c == nil || s == nil {
		return ""
	}
	return h.chatPromptFor(c, s.Node)
}

// agentAtLeast reports whether node's agent is version v or newer. Builds
// without a version count as new. Caller holds h.mu.
func (h *Hub) agentAtLeast(node, v string) bool {
	n := h.nodes[node]
	if n == nil {
		return false
	}
	return versionAtLeast(n.AgentVersion, v)
}

// versionAtLeast is updates.AtLeast, except a build without a release
// version (dev, tests) counts as new.
func versionAtLeast(have, want string) bool {
	if _, ok := updates.Parse(have); !ok {
		return true
	}
	return updates.AtLeast(have, want)
}

func parseVersion(s string) ([3]int, bool) {
	return updates.Parse(s)
}

// ---- post-processing ----

// A chatJob derives something from a chat's stored context. Jobs run under
// h.mu after a chat is made and whenever one of its sessions ends a turn,
// so they must be quick; slow ones (a model call) should start a goroutine
// and come back through putChat. A job returns a note to store, or nil.
type chatJob struct {
	kind string
	run  func(h *Hub, c *v1.Chat, msgs []*v1.ChatMessage) *v1.ChatNote
}

var chatJobs = []chatJob{
	{kind: "title", run: titleJob},
}

func (h *Hub) runChatJobs(c *v1.Chat) {
	msgs, err := h.store.ChatMessages(c.Id)
	if err != nil {
		h.log.Error("chat messages", "chat", c.Id, "err", err)
		return
	}
	for _, j := range chatJobs {
		n := j.run(h, c, msgs)
		if n == nil {
			continue
		}
		n.Kind, n.UpdatedMs = j.kind, time.Now().UnixMilli()
		if err := h.store.PutChatNote(c.Id, n); err != nil {
			h.log.Error("store chat note", "chat", c.Id, "kind", j.kind, "err", err)
		}
	}
}

// titleJob names a chat after its first message, unless the user named it.
func titleJob(h *Hub, c *v1.Chat, msgs []*v1.ChatMessage) *v1.ChatNote {
	first := ""
	for _, m := range msgs {
		if m.Role == "user" {
			first = m.Text
			break
		}
	}
	if first == "" {
		if s := h.sessions[c.ActiveSession]; s != nil {
			first = s.LastPrompt
		}
	}
	title := autoTitle(first)
	if title == "" {
		return nil
	}
	// Only a title this job made is replaced: not the user's, and not the
	// one a session already had when it became a chat.
	if !c.TitleByUser && (c.Title == "" || c.Title == h.chatNote(c.Id, "title")) {
		c.Title = title
	}
	return &v1.ChatNote{Value: title}
}

func (h *Hub) chatNote(chat, kind string) string {
	notes, err := h.store.ChatNotes(chat)
	if err != nil {
		h.log.Error("chat notes", "chat", chat, "err", err)
	}
	for _, n := range notes {
		if n.Kind == kind {
			return n.Value
		}
	}
	return ""
}

func (h *Hub) noteTitle(chat, title string) {
	if err := h.store.PutChatNote(chat, &v1.ChatNote{Kind: "title", Value: title, UpdatedMs: time.Now().UnixMilli()}); err != nil {
		h.log.Error("store chat note", "chat", chat, "err", err)
	}
}

var titleFiller = []string{"please ", "can you ", "could you ", "would you ", "hey ", "hi ", "hello ", "so ", "ok ", "okay ", "i want you to ", "i need you to ", "help me "}

// autoTitle makes a short title from a first message: its first line or
// sentence, without markdown or politeness, cut at a word.
func autoTitle(text string) string {
	text = strings.TrimSpace(text)
	if strings.HasPrefix(text, "My message is long, so it is in the attached file") {
		return "Long message"
	}
	line := ""
	for _, l := range strings.Split(text, "\n") {
		l = strings.TrimSpace(strings.TrimLeft(strings.TrimSpace(l), "#>*-` "))
		if l != "" {
			line = l
			break
		}
	}
	if i := strings.IndexAny(line, ".?!"); i > 12 {
		line = line[:i]
	}
	line = strings.NewReplacer("**", "", "__", "", "`", "").Replace(line)
	for changed := true; changed; {
		changed = false
		for _, f := range titleFiller {
			if len(line) > len(f) && strings.EqualFold(line[:len(f)], f) {
				line, changed = strings.TrimSpace(line[len(f):]), true
			}
		}
	}
	line = strings.TrimRight(line, ",;: ")
	const limit = 60
	if len([]rune(line)) > limit {
		r := []rune(line)[:limit]
		cut := strings.LastIndexFunc(string(r), unicode.IsSpace)
		if cut > limit/2 {
			line = string(r)[:cut]
		} else {
			line = string(r)
		}
		line = strings.TrimRight(line, ",;: ") + "…"
	}
	if line == "" {
		return ""
	}
	r := []rune(line)
	r[0] = unicode.ToUpper(r[0])
	return string(r)
}

func (h *Hub) chatRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/chats", h.api(func(r *http.Request) (proto.Message, *opError) {
		return &v1.ChatList{Chats: h.chatList()}, nil
	}))
	mux.HandleFunc("POST /api/v1/chats", h.api(func(r *http.Request) (proto.Message, *opError) {
		cc := &v1.CreateChat{}
		if err := decode(r, cc); err != nil {
			return nil, err
		}
		return h.createChat(cc, clientName(r))
	}))
	mux.HandleFunc("PATCH /api/v1/chats/{id}", h.api(func(r *http.Request) (proto.Message, *opError) {
		u := &v1.UpdateChat{}
		if err := decode(r, u); err != nil {
			return nil, err
		}
		return h.updateChat(r.PathValue("id"), u)
	}))
	mux.HandleFunc("POST /api/v1/chats/{id}/messages", h.api(func(r *http.Request) (proto.Message, *opError) {
		m := &v1.SendMessage{}
		if err := decode(r, m); err != nil {
			return nil, err
		}
		return ackOf(h.chatSend(r.PathValue("id"), m, clientName(r)))
	}))
	mux.HandleFunc("POST /api/v1/chats/{id}/target", h.api(func(r *http.Request) (proto.Message, *opError) {
		st := &v1.SetChatTarget{}
		if err := decode(r, st); err != nil {
			return nil, err
		}
		return h.setChatTarget(r.PathValue("id"), st, clientName(r))
	}))
	mux.HandleFunc("POST /api/v1/chats/{id}/links", h.api(func(r *http.Request) (proto.Message, *opError) {
		ls := &v1.LinkSession{}
		if err := decode(r, ls); err != nil {
			return nil, err
		}
		return h.linkToChat(r.PathValue("id"), ls)
	}))
	mux.HandleFunc("GET /api/v1/chats/{id}/context", h.api(func(r *http.Request) (proto.Message, *opError) {
		return h.chatContext(r.PathValue("id"))
	}))
	mux.HandleFunc("GET /api/v1/targets", h.api(func(r *http.Request) (proto.Message, *opError) {
		return h.targetSuggestions(r.URL.Query().Get("prompt")), nil
	}))
}
