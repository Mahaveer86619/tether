package hub

import (
	"encoding/json"
	"net/http"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// The prompt desk: rewind, the recap, the context meter and the handoff.
// See docs/plans/prompt-desk.md and docs/architecture/chats.md.

const (
	linkRewound = "rewound"
	linkHandoff = "handoff"

	modeText = "text"
	modeFork = "fork"

	// Chat notes: the recap job's output, a rewind's cut (one per new
	// session) and the per-chat Remind switch.
	noteRecap       = "recap"
	noteRewindStart = "rewind:"
	noteRemind      = "remind"

	deskKey = "desk"

	// Tokens of context past which the app offers a handoff. Claude Code
	// compacts a little under 200k, so this leaves room to hand off first.
	defaultHandoffTokens = 150_000

	// The opening lines of a session that carries a chat on: the
	// conversation they quote is already in chat_messages.
	carryMoved   = "This continues an earlier conversation from another Claude Code session"
	carryRewound = "This picks up an earlier conversation at a point the user went back to"
	carryHandoff = "Handoff summary, made by Tether from the saved chat"
)

type deskSettings struct {
	HandoffTokens int64 `json:"handoffTokens"`
}

func (h *Hub) deskSettings() deskSettings {
	d := deskSettings{}
	if b, err := h.store.Get(deskKey); err == nil && b != nil {
		_ = json.Unmarshal(b, &d)
	}
	if d.HandoffTokens <= 0 {
		d.HandoffTokens = defaultHandoffTokens
	}
	return d
}

func isCarry(text string) bool {
	for _, p := range []string{carryMoved, carryRewound, carryHandoff} {
		if strings.HasPrefix(text, p) {
			return true
		}
	}
	return false
}

type rewindCut struct {
	Old     string `json:"old"`
	New     string `json:"new"`
	Session string `json:"session"`
	Item    string `json:"item"`
	Prompt  int    `json:"prompt"`
	AtMs    int64  `json:"atMs"`
}

func (h *Hub) rewindCuts(chat string) []rewindCut {
	notes, err := h.store.ChatNotes(chat)
	if err != nil {
		h.log.Error("chat notes", "chat", chat, "err", err)
		return nil
	}
	var out []rewindCut
	for _, n := range notes {
		if !strings.HasPrefix(n.Kind, noteRewindStart) {
			continue
		}
		var r rewindCut
		if json.Unmarshal([]byte(n.Value), &r) == nil {
			out = append(out, r)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].AtMs < out[j].AtMs })
	return out
}

// conversation is what was said in the chat along the line it now follows:
// without what a rewind went back over, and without the messages that only
// carried the conversation into a new session (they quote what is already
// here).
func (h *Hub) conversation(c *v1.Chat) []*v1.ChatMessage {
	msgs, err := h.store.ChatMessages(c.Id)
	if err != nil {
		h.log.Error("chat messages", "chat", c.Id, "err", err)
		return nil
	}
	return dropRewound(msgs, h.rewindCuts(c.Id))
}

func dropRewound(msgs []*v1.ChatMessage, cuts []rewindCut) []*v1.ChatMessage {
	drop := make([]bool, len(msgs))
	for _, r := range cuts {
		from, until := -1, len(msgs)
		for i, m := range msgs {
			if from < 0 && m.Session == r.Session && m.ItemId == r.Item {
				from = i
			}
			if m.Session == r.New {
				until = i
				break
			}
		}
		if from < 0 {
			continue
		}
		for i := from; i < len(msgs); i++ {
			// The old session may still say something after the new one starts.
			if i < until || msgs[i].Session == r.Old {
				drop[i] = true
			}
		}
	}
	var out []*v1.ChatMessage
	for i, m := range msgs {
		if drop[i] || m.Role == "user" && isCarry(m.Text) {
			continue
		}
		out = append(out, m)
	}
	return out
}

// carryText is msgs as a first message: oldest first, trimmed like a move.
func carryText(msgs []*v1.ChatMessage) string {
	var parts []string
	used := 0
	for i := len(msgs) - 1; i >= 0 && used < handoffBudget; i-- {
		p := speaker(msgs[i]) + ": " + clip(msgs[i].Text, handoffEach)
		parts = append(parts, p)
		used += len(p)
	}
	for i, j := 0, len(parts)-1; i < j; i, j = i+1, j-1 {
		parts[i], parts[j] = parts[j], parts[i]
	}
	return strings.Join(parts, "\n\n")
}

func speaker(m *v1.ChatMessage) string {
	if m.Role == "assistant" {
		return "Claude"
	}
	return "User"
}

// carryOn starts a session at the chat's target with prompt and makes it
// the active one, linked by role. Caller holds h.mu and saves c.
func (h *Hub) carryOn(c *v1.Chat, prompt, request, role, kind, from string) (string, *opError) {
	t := c.Target
	if t == nil || t.Node == "" && !t.Scratch {
		return "", invalid("the chat has no target")
	}
	cs := &v1.CreateSession{Node: t.Node, Cwd: t.Cwd, Scratch: t.Scratch, Prompt: prompt}
	prev := h.sessions[c.ActiveSession]
	if prev != nil {
		cs.Model = prev.Model
	}
	id, err := h.startSession(cs, from, startExtra{systemPrompt: h.chatPromptWith(c, cs.Node, false, request)})
	if err != nil {
		return "", err
	}
	if s := h.sessions[id]; s != nil {
		next := proto.Clone(s).(*v1.SessionInfo)
		next.Title, next.LastPrompt = c.Title, firstNonEmpty(request, c.Title)
		if prev != nil {
			next.Parent, next.Lineage = prev.Id, kind
		}
		h.putSession(next)
		h.recordLineage(&v1.LineageEvent{Session: id, Parent: c.ActiveSession, Kind: kind, By: from, AtMs: next.CreatedMs, Detail: "chat " + c.Id})
	}
	h.link(c, id, role)
	c.ActiveSession = id
	return id, nil
}

// setRole changes the role of a session already in c. Caller holds h.mu.
func (h *Hub) setRole(c *v1.Chat, session, role string) {
	for _, l := range c.Sessions {
		if l.Session == session {
			l.Role = role
		}
	}
	if err := h.store.SetLinkRole(c.Id, session, role); err != nil {
		h.log.Error("link role", "chat", c.Id, "session", session, "err", err)
	}
}

// ---- rewind ----

type rewindRequest struct {
	ItemID  string `json:"itemId"`
	Session string `json:"session"`
	Mode    string `json:"mode"`
}

type rewindResult struct {
	Chat    json.RawMessage `json:"chat"`
	Session string          `json:"session"`
	Text    string          `json:"text"`
	Prompt  int             `json:"prompt"`
	Back    int             `json:"back"`
	Mode    string          `json:"mode"`
	Note    string          `json:"note,omitempty"`
}

// rewindChat goes back to before a user message: a new session gets the
// conversation up to it and becomes the active one; the old one stays,
// linked as rewound. Returns the message, for the user to edit and send.
// Caller holds h.mu.
func (h *Hub) rewindChat(id string, in rewindRequest, from string) (*rewindResult, *opError) {
	c := h.chats[id]
	if c == nil {
		return nil, errChatNotFound
	}
	if in.ItemID == "" {
		return nil, invalid("itemId is required")
	}
	mode := firstNonEmpty(in.Mode, modeText)
	if mode != modeText && mode != modeFork {
		return nil, invalid("mode is text or fork")
	}
	msgs := h.conversation(c)
	at, prompts, n := -1, 0, 0
	for i, m := range msgs {
		if m.Role == "user" {
			prompts++
		}
		if at < 0 && m.ItemId == in.ItemID && (in.Session == "" || m.Session == in.Session) {
			if m.Role != "user" {
				return nil, invalid("only your own messages can be rewound to")
			}
			at, n = i, prompts
		}
	}
	if at < 0 {
		return nil, &opError{"not_found", "that message isn't in this chat's conversation", http.StatusNotFound}
	}
	res := &rewindResult{Text: msgs[at].Text, Prompt: n, Back: prompts - n + 1, Mode: modeText}
	if mode == modeFork {
		// Cutting a transcript at a turn needs the agent; until it can, the
		// text carry gives the same conversation.
		res.Note = "Fork at a point isn't available yet, so the conversation was carried as text."
	}
	old := c.ActiveSession
	if s := h.sessions[old]; s != nil && s.State == v1.SessionState_SESSION_STATE_RUNNING {
		_, _ = h.interrupt(old)
	}
	ready := "The user will send their next message in a moment. Reply only with: Ready."
	prompt := carryRewound + " (prompt " + strconv.Itoa(n) + "). There was nothing before it, so this is a fresh start. " + ready
	if history := carryText(msgs[:at]); history != "" {
		prompt = carryRewound + " (prompt " + strconv.Itoa(n) + "). Here is the conversation up to that point, oldest first:\n\n" +
			history + "\n\n---\n\n" + ready
	}
	session, err := h.carryOn(c, prompt, "", linkMoved, "rewind", from)
	if err != nil {
		return nil, err
	}
	if old != "" && h.chatOf[old] == c.Id {
		h.setRole(c, old, linkRewound)
	}
	cut := rewindCut{Old: old, New: session, Session: msgs[at].Session, Item: msgs[at].ItemId, Prompt: n, AtMs: time.Now().UnixMilli()}
	b, _ := json.Marshal(cut)
	if err := h.store.PutChatNote(c.Id, &v1.ChatNote{Kind: noteRewindStart + session, Value: string(b), UpdatedMs: cut.AtMs}); err != nil {
		h.log.Error("store rewind", "chat", c.Id, "err", err)
	}
	c.UpdatedMs, c.Archived = time.Now().UnixMilli(), false
	h.putChat(c)
	res.Session = session
	res.Chat, _ = jsonOut.Marshal(c)
	return res, nil
}

// ---- the recap ----

type recap struct {
	Asked  string   `json:"asked"`
	Done   string   `json:"done"`
	Open   []string `json:"open"`
	Prompt int      `json:"prompt"`
	AtMs   int64    `json:"atMs"`
}

// recapJob notes where a chat stands: the last thing asked, the first lines
// of the last reply, and the to-dos not done. No model is asked.
func recapJob(h *Hub, c *v1.Chat, _ []*v1.ChatMessage) *v1.ChatNote {
	r := h.recapOf(c)
	if r == nil {
		return nil
	}
	b, _ := json.Marshal(r)
	return &v1.ChatNote{Value: string(b)}
}

func (h *Hub) recapOf(c *v1.Chat) *recap {
	msgs := h.conversation(c)
	r := &recap{}
	for _, m := range msgs {
		if m.Role == "user" {
			r.Prompt++
			r.Asked, r.Done, r.AtMs = m.Text, "", m.TsMs
		} else if strings.TrimSpace(m.Text) != "" {
			r.Done, r.AtMs = m.Text, m.TsMs
		}
	}
	if r.Asked == "" && r.Done == "" {
		return nil
	}
	r.Asked = clip(r.Asked, 300)
	r.Done = firstLines(r.Done, 3, 400)
	if s := h.sessions[c.ActiveSession]; s != nil {
		for _, t := range s.Todos {
			if t.Status != v1.Todo_STATUS_COMPLETED {
				r.Open = append(r.Open, clip(t.Content, 160))
			}
		}
	}
	return r
}

// firstLines is the first n non-empty lines of s, without markdown marks.
func firstLines(s string, n, limit int) string {
	var out []string
	inCode := false
	for _, l := range strings.Split(s, "\n") {
		t := strings.TrimSpace(l)
		if strings.HasPrefix(t, "```") {
			inCode = !inCode
			continue
		}
		t = strings.TrimSpace(strings.TrimLeft(t, "#>*-|` "))
		if inCode || t == "" {
			continue
		}
		out = append(out, t)
		if len(out) == n {
			break
		}
	}
	return clip(strings.Join(out, " "), limit)
}

// ---- the context meter and the handoff ----

type contextEstimate struct {
	// What a resume of the active session would carry, as best known: its
	// last turn's context when usage was reported, else the saved text / 4.
	Tokens    int64 `json:"tokens"`
	FromUsage bool  `json:"fromUsage"`
	Chars     int64 `json:"chars"`
	Messages  int   `json:"messages"`
	Prompts   int   `json:"prompts"`
	HandoffAt int64 `json:"handoffAt"`
}

func (h *Hub) estimate(c *v1.Chat, msgs []*v1.ChatMessage) contextEstimate {
	e := contextEstimate{Messages: len(msgs), HandoffAt: h.deskSettings().HandoffTokens}
	for _, m := range msgs {
		e.Chars += int64(len(m.Text))
		if m.Role == "user" {
			e.Prompts++
		}
	}
	e.Tokens = e.Chars / 4
	if u, err := h.store.LastUsage(c.ActiveSession); err == nil && u != nil {
		if t := u.Input + u.CacheRead + u.CacheWrite + u.Output; t > 0 {
			e.Tokens, e.FromUsage = t, true
		}
	}
	return e
}

var (
	decisionLine = regexp.MustCompile(`(?i)\b(decided|decision|we'll use|going with|settled on|chose|instead of)\b`)
	ruleLine     = regexp.MustCompile(`(?i)^(always|never|don't|do not|use|keep|make sure|only|no )`)
	openLine     = regexp.MustCompile(`(?i)\b(todo|next step|still to|not yet|left to|remaining|follow-up|open question|blocked)\b`)
)

// handoffSummary is a structured summary of the chat for a fresh session:
// goal, decisions, open items, files touched and the last three turns as
// they were. It is made from the saved text by rules, not by a model, and
// says so. Caller holds h.mu.
func (h *Hub) handoffSummary(c *v1.Chat) string {
	msgs := h.conversation(c)
	var goal string
	var decisions, open []string
	seen := map[string]bool{}
	add := func(list *[]string, s string, max int) {
		s = clip(s, 240)
		if len(*list) < max && s != "" && !seen[s] {
			seen[s] = true
			*list = append(*list, s)
		}
	}
	for _, m := range msgs {
		if m.Role == "user" && goal == "" {
			goal = clip(m.Text, 800)
		}
		for _, l := range strings.Split(m.Text, "\n") {
			l = strings.TrimSpace(strings.TrimLeft(strings.TrimSpace(l), "#>*-` "))
			switch {
			case l == "":
			case m.Role == "user" && ruleLine.MatchString(l):
				add(&decisions, l, 12)
			case m.Role == "assistant" && decisionLine.MatchString(l):
				add(&decisions, l, 12)
			}
		}
	}
	if s := h.sessions[c.ActiveSession]; s != nil {
		for _, t := range s.Todos {
			if t.Status != v1.Todo_STATUS_COMPLETED {
				add(&open, t.Content, 12)
			}
		}
	}
	for i := len(msgs) - 1; i >= 0; i-- {
		if msgs[i].Role == "assistant" {
			for _, l := range strings.Split(msgs[i].Text, "\n") {
				l = strings.TrimSpace(strings.TrimLeft(strings.TrimSpace(l), "#>*-` "))
				if openLine.MatchString(l) {
					add(&open, l, 12)
				}
			}
			break
		}
	}

	var b strings.Builder
	b.WriteString(carryHandoff + " by rules, not by a model, so it may miss things; ask the user when something is unclear.\n\n")
	b.WriteString("## Goal\n\n" + firstNonEmpty(goal, c.Title) + "\n\n")
	section := func(title string, items []string, none string) {
		b.WriteString("## " + title + "\n\n")
		if len(items) == 0 {
			b.WriteString(none + "\n\n")
			return
		}
		for _, it := range items {
			b.WriteString("- " + it + "\n")
		}
		b.WriteString("\n")
	}
	section("Decisions and instructions", decisions, "None found in the text.")
	section("Open items", open, "None found in the text.")
	section("Files touched", h.filesTouched(c), "None recorded.")
	b.WriteString("## The last turns, as they were\n\n")
	b.WriteString(lastTurns(msgs, 3))
	return b.String()
}

// lastTurns is the last n prompts with the replies after each, verbatim
// up to handoffEach characters a message.
func lastTurns(msgs []*v1.ChatMessage, n int) string {
	start, seen := 0, 0
	for i := len(msgs) - 1; i >= 0; i-- {
		if msgs[i].Role == "user" {
			seen++
			start = i
			if seen == n {
				break
			}
		}
	}
	var parts []string
	for _, m := range msgs[start:] {
		t := strings.TrimSpace(m.Text)
		if r := []rune(t); len(r) > handoffEach {
			t = string(r[:handoffEach]) + "…"
		}
		parts = append(parts, "**"+speaker(m)+":** "+t)
	}
	return strings.Join(parts, "\n\n")
}

// filesTouched are the files edited or written in the chat's sessions,
// newest first. Caller holds h.mu.
func (h *Hub) filesTouched(c *v1.Chat) []string {
	var out []string
	seen := map[string]bool{}
	for i := len(c.Sessions) - 1; i >= 0 && len(out) < 30; i-- {
		l := c.Sessions[i]
		if l.Role == linkRewound {
			continue
		}
		items, err := h.store.RecentItems(l.Session, 3000)
		if err != nil {
			continue
		}
		for _, it := range items {
			tool := it.GetTool()
			if tool == nil {
				continue
			}
			p := firstNonEmpty(tool.GetEdit().GetPath(), tool.GetWrite().GetPath())
			if p == "" || seen[p] || len(out) >= 30 {
				continue
			}
			seen[p] = true
			out = append(out, p)
		}
	}
	return out
}

type handoffRequest struct {
	Text string `json:"text"`
}

// handoffChat continues the chat in a fresh session at its target, with a
// summary in place of the whole conversation. Caller holds h.mu.
func (h *Hub) handoffChat(id string, in handoffRequest, from string) (*rewindResult, *opError) {
	c := h.chats[id]
	if c == nil {
		return nil, errChatNotFound
	}
	text := strings.TrimSpace(in.Text)
	if text == "" {
		text = "Read the summary, say in two or three lines where things stand, and wait for the user."
	}
	summary := h.handoffSummary(c)
	session, err := h.carryOn(c, summary+"\n\n---\n\n"+text, in.Text, linkHandoff, "handoff", from)
	if err != nil {
		return nil, err
	}
	c.UpdatedMs, c.Archived = time.Now().UnixMilli(), false
	h.putChat(c)
	res := &rewindResult{Session: session, Text: summary, Mode: linkHandoff}
	res.Chat, _ = jsonOut.Marshal(c)
	return res, nil
}

// ---- what the app shows around the composer ----

type deskPrompt struct {
	ItemID  string `json:"itemId"`
	Session string `json:"session"`
	N       int    `json:"n"`
	Text    string `json:"text"`
	AtMs    int64  `json:"atMs"`
}

type deskRule struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Text  string `json:"text"`
	Scope string `json:"scope"`
}

type deskView struct {
	Recap   *recap          `json:"recap"`
	Context contextEstimate `json:"context"`
	Remind  bool            `json:"remind"`
	Rules   []deskRule      `json:"rules"`
	Rewinds []rewindCut     `json:"rewinds"`
	Prompts []deskPrompt    `json:"prompts"`
}

// deskOf is everything the chat page shows around its composer: the recap,
// the context meter, the rules that apply, rewinds and the prompts a rewind
// can go back to (newest last, at most 30). Caller holds h.mu.
func (h *Hub) deskOf(c *v1.Chat) deskView {
	msgs := h.conversation(c)
	d := deskView{Context: h.estimate(c, msgs), Remind: h.chatNote(c.Id, noteRemind) == "on", Rules: []deskRule{}, Rewinds: h.rewindCuts(c.Id), Prompts: []deskPrompt{}}
	if d.Rewinds == nil {
		d.Rewinds = []rewindCut{}
	}
	if v := h.chatNote(c.Id, noteRecap); v != "" {
		r := &recap{}
		if json.Unmarshal([]byte(v), r) == nil {
			d.Recap = r
		}
	}
	for _, r := range rulesFor(h.rulesList(), c.Target.GetNode(), c.Target.GetCwd()) {
		d.Rules = append(d.Rules, deskRule{ID: r.ID, Name: r.Name, Text: r.Text, Scope: r.Scope})
	}
	n := 0
	for _, m := range msgs {
		if m.Role != "user" {
			continue
		}
		n++
		d.Prompts = append(d.Prompts, deskPrompt{ItemID: m.ItemId, Session: m.Session, N: n, Text: clip(m.Text, 300), AtMs: m.TsMs})
	}
	if len(d.Prompts) > 30 {
		d.Prompts = d.Prompts[len(d.Prompts)-30:]
	}
	return d
}

func (h *Hub) deskRoutes(mux *http.ServeMux) {
	withChat := func(fn func(w http.ResponseWriter, r *http.Request, c *v1.Chat)) http.HandlerFunc {
		return h.authed(func(w http.ResponseWriter, r *http.Request) {
			h.mu.Lock()
			defer h.mu.Unlock()
			c := h.chats[r.PathValue("id")]
			if c == nil {
				writeError(w, errChatNotFound)
				return
			}
			fn(w, r, c)
		})
	}
	readJSON := func(w http.ResponseWriter, r *http.Request, v any) bool {
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBody)).Decode(v); err != nil && err.Error() != "EOF" {
			writeError(w, invalid("malformed JSON"))
			return false
		}
		return true
	}
	mux.HandleFunc("GET /api/v1/chats/{id}/desk", withChat(func(w http.ResponseWriter, r *http.Request, c *v1.Chat) {
		writePlainJSON(w, h.deskOf(c))
	}))
	mux.HandleFunc("PUT /api/v1/chats/{id}/desk", withChat(func(w http.ResponseWriter, r *http.Request, c *v1.Chat) {
		var in struct {
			Remind *bool `json:"remind"`
		}
		if !readJSON(w, r, &in) {
			return
		}
		if in.Remind != nil {
			v := ""
			if *in.Remind {
				v = "on"
			}
			if err := h.store.PutChatNote(c.Id, &v1.ChatNote{Kind: noteRemind, Value: v, UpdatedMs: time.Now().UnixMilli()}); err != nil {
				writeError(w, internalError(err))
				return
			}
		}
		writePlainJSON(w, h.deskOf(c))
	}))
	mux.HandleFunc("POST /api/v1/chats/{id}/rewind", withChat(func(w http.ResponseWriter, r *http.Request, c *v1.Chat) {
		var in rewindRequest
		if !readJSON(w, r, &in) {
			return
		}
		res, err := h.rewindChat(c.Id, in, clientName(r))
		if err != nil {
			writeError(w, err)
			return
		}
		writePlainJSON(w, res)
	}))
	mux.HandleFunc("POST /api/v1/chats/{id}/handoff", withChat(func(w http.ResponseWriter, r *http.Request, c *v1.Chat) {
		var in handoffRequest
		if !readJSON(w, r, &in) {
			return
		}
		res, err := h.handoffChat(c.Id, in, clientName(r))
		if err != nil {
			writeError(w, err)
			return
		}
		writePlainJSON(w, res)
	}))
	mux.HandleFunc("GET /api/v1/desk", h.authed(func(w http.ResponseWriter, r *http.Request) {
		h.mu.Lock()
		defer h.mu.Unlock()
		writePlainJSON(w, h.deskSettings())
	}))
	mux.HandleFunc("PUT /api/v1/desk", h.authed(func(w http.ResponseWriter, r *http.Request) {
		var in deskSettings
		if !readJSON(w, r, &in) {
			return
		}
		if in.HandoffTokens < 0 {
			writeError(w, invalid("handoffTokens can't be negative"))
			return
		}
		h.mu.Lock()
		defer h.mu.Unlock()
		b, _ := json.Marshal(in)
		if err := h.store.Put(deskKey, b); err != nil {
			writeError(w, internalError(err))
			return
		}
		writePlainJSON(w, h.deskSettings())
	}))
}
