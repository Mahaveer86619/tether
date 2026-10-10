// Package hub is the central router: agents push raw Claude Code output in,
// the hub renders and stores it, and clients subscribe to the result.
package hub

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/render"
	"github.com/Mahaveer86619/tether/server/internal/store"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

const (
	helloTimeout  = 10 * time.Second
	flushInterval = 100 * time.Millisecond
	replayChunk   = 200
)

type Config struct {
	Token   string
	Version string
	Log     *slog.Logger
}

type client struct {
	conn *wire.Conn
	name string
}

// pendingItems holds coalesced partial-text updates in arrival order.
type pendingItems struct {
	order []string
	items map[string]*v1.TimelineItem
}

type Hub struct {
	cfg   Config
	store *store.Store
	log   *slog.Logger

	mu        sync.Mutex
	agents    map[string]*wire.Conn
	clients   map[*client]struct{}
	nodes     map[string]*v1.NodeStatus
	sessions  map[string]*v1.SessionInfo
	subs      map[string]map[*client]struct{}
	builders  map[string]*render.Builder
	pending   map[string]*pendingItems
	approvals map[string]*v1.ApprovalRequest
	mirroring map[string]bool
}

func New(cfg Config, st *store.Store) (*Hub, error) {
	h := &Hub{
		cfg:       cfg,
		store:     st,
		log:       cfg.Log,
		agents:    map[string]*wire.Conn{},
		clients:   map[*client]struct{}{},
		nodes:     map[string]*v1.NodeStatus{},
		sessions:  map[string]*v1.SessionInfo{},
		subs:      map[string]map[*client]struct{}{},
		builders:  map[string]*render.Builder{},
		pending:   map[string]*pendingItems{},
		approvals: map[string]*v1.ApprovalRequest{},
		mirroring: map[string]bool{},
	}
	nodes, err := st.Nodes()
	if err != nil {
		return nil, err
	}
	for _, n := range nodes {
		n.Online, n.RunningSessions = false, 0
		h.nodes[n.Node] = n
	}
	sessions, err := st.Sessions()
	if err != nil {
		return nil, err
	}
	for _, s := range sessions {
		// Live states belong to processes that may be gone; agents re-report them.
		if live(s.State) {
			s.State = v1.SessionState_SESSION_STATE_IDLE
		}
		h.sessions[s.Id] = s
	}
	return h, nil
}

func live(s v1.SessionState) bool {
	switch s {
	case v1.SessionState_SESSION_STATE_RUNNING, v1.SessionState_SESSION_STATE_AWAITING_APPROVAL, v1.SessionState_SESSION_STATE_READY:
		return true
	}
	return false
}

func (h *Hub) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", h.serveWS)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok\n")) })
	return mux
}

// Run flushes coalesced streaming updates until ctx ends.
func (h *Hub) Run(ctx context.Context) {
	t := time.NewTicker(flushInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			h.mu.Lock()
			for s := range h.pending {
				h.commit(s, h.takePending(s))
			}
			h.mu.Unlock()
		}
	}
}

func (h *Hub) serveWS(w http.ResponseWriter, r *http.Request) {
	conn, err := wire.Accept(w, r)
	if err != nil {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), helloTimeout)
	f, err := conn.Read(ctx)
	cancel()
	if err != nil {
		conn.Close(err)
		return
	}
	switch b := f.Body.(type) {
	case *v1.Frame_ClientHello:
		if !h.authorized(b.ClientHello.Token) {
			h.reject(conn, r)
			return
		}
		h.serveClient(conn, b.ClientHello)
	case *v1.Frame_AgentHello:
		if !h.authorized(b.AgentHello.Token) || b.AgentHello.Status.GetNode() == "" {
			h.reject(conn, r)
			return
		}
		h.serveAgent(conn, b.AgentHello.Status)
	default:
		conn.Close(errors.New("expected hello"))
	}
}

func (h *Hub) authorized(token string) bool {
	return h.cfg.Token != "" && subtle.ConstantTimeCompare([]byte(token), []byte(h.cfg.Token)) == 1
}

func (h *Hub) reject(conn *wire.Conn, r *http.Request) {
	h.log.Warn("rejected connection", "remote", r.RemoteAddr)
	conn.Send(errFrame("", "unauthorized", "bad token"))
	time.Sleep(200 * time.Millisecond)
	conn.Close(errors.New("unauthorized"))
}

// ---- clients ----

func (h *Hub) serveClient(conn *wire.Conn, hello *v1.ClientHello) {
	c := &client{conn: conn, name: hello.ClientName}
	h.mu.Lock()
	h.clients[c] = struct{}{}
	conn.Send(&v1.Frame{Body: &v1.Frame_Welcome{Welcome: h.welcome()}})
	h.mu.Unlock()
	h.log.Info("client connected", "name", c.name, "platform", hello.Platform)

	err := conn.Run(func(f *v1.Frame) { h.onClient(c, f) })

	h.mu.Lock()
	delete(h.clients, c)
	for s, set := range h.subs {
		if _, ok := set[c]; ok {
			delete(set, c)
			h.maybeStopMirror(s)
		}
	}
	h.mu.Unlock()
	h.log.Info("client disconnected", "name", c.name, "err", err)
}

func (h *Hub) welcome() *v1.Welcome {
	w := &v1.Welcome{HubVersion: h.cfg.Version}
	for _, n := range h.nodes {
		w.Nodes = append(w.Nodes, proto.Clone(n).(*v1.NodeStatus))
	}
	sort.Slice(w.Nodes, func(i, j int) bool { return w.Nodes[i].Node < w.Nodes[j].Node })
	for _, s := range h.sessions {
		w.Sessions = append(w.Sessions, proto.Clone(s).(*v1.SessionInfo))
	}
	sort.Slice(w.Sessions, func(i, j int) bool { return w.Sessions[i].UpdatedMs > w.Sessions[j].UpdatedMs })
	for _, a := range h.approvals {
		w.PendingApprovals = append(w.PendingApprovals, proto.Clone(a).(*v1.ApprovalRequest))
	}
	return w
}

func (h *Hub) onClient(c *client, f *v1.Frame) {
	h.mu.Lock()
	defer h.mu.Unlock()
	switch b := f.Body.(type) {
	case *v1.Frame_Subscribe:
		h.subscribe(c, f.Id, b.Subscribe)
	case *v1.Frame_Unsubscribe:
		if set := h.subs[b.Unsubscribe.Session]; set != nil {
			delete(set, c)
			h.maybeStopMirror(b.Unsubscribe.Session)
		}
		ack(c, f.Id, "")
	case *v1.Frame_CreateSession:
		h.createSession(c, f.Id, b.CreateSession)
	case *v1.Frame_SendMessage:
		h.sendMessage(c, f.Id, b.SendMessage)
	case *v1.Frame_InterruptSession:
		info, agent := h.target(c, f.Id, b.InterruptSession.Session)
		if agent == nil {
			return
		}
		agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Interrupt_{Interrupt: &v1.AgentCommand_Interrupt{Session: info.Id}}}))
		ack(c, f.Id, info.Id)
	case *v1.Frame_ApprovalDecision:
		h.decide(c, f.Id, b.ApprovalDecision)
	default:
		c.conn.Send(errFrame(f.Id, "unsupported", "unsupported frame"))
	}
}

func (h *Hub) subscribe(c *client, id string, s *v1.Subscribe) {
	if h.sessions[s.Session] == nil {
		c.conn.Send(errFrame(id, "not_found", "unknown session"))
		return
	}
	if h.subs[s.Session] == nil {
		h.subs[s.Session] = map[*client]struct{}{}
	}
	h.subs[s.Session][c] = struct{}{}

	items, maxSeq, err := h.store.ItemsAfter(s.Session, s.AfterSeq)
	if err != nil {
		c.conn.Send(errFrame(id, "internal", err.Error()))
		return
	}
	for len(items) > replayChunk {
		c.conn.Send(&v1.Frame{Body: timeline(s.Session, items[:replayChunk])})
		items = items[replayChunk:]
	}
	if len(items) > 0 {
		c.conn.Send(&v1.Frame{Seq: maxSeq, Body: timeline(s.Session, items)})
	}
	// An empty update marks the end of the replay.
	c.conn.Send(&v1.Frame{ReplyTo: id, Seq: max(maxSeq, s.AfterSeq), Body: timeline(s.Session, nil)})
	h.ensureMirror(s.Session)
}

func (h *Hub) createSession(c *client, id string, cs *v1.CreateSession) {
	agent := h.agents[cs.Node]
	if agent == nil {
		c.conn.Send(errFrame(id, "node_offline", "node is not connected"))
		return
	}
	if strings.TrimSpace(cs.Prompt) == "" {
		c.conn.Send(errFrame(id, "invalid", "prompt is empty"))
		return
	}
	now := time.Now().UnixMilli()
	info := &v1.SessionInfo{
		Id: uuid.NewString(), Node: cs.Node, Cwd: cs.Cwd, Title: firstNonEmpty(cs.Name, clip(cs.Prompt, 80)),
		State: v1.SessionState_SESSION_STATE_RUNNING, CreatedMs: now, UpdatedMs: now, LastPrompt: cs.Prompt, Model: cs.Model,
	}
	h.putSession(info)
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Start{Start: &v1.AgentCommand_StartRun{
		Session: info.Id, Cwd: cs.Cwd, Prompt: cs.Prompt, Model: cs.Model, PermissionMode: cs.PermissionMode, Name: cs.Name,
	}}}))
	ack(c, id, info.Id)
}

func (h *Hub) sendMessage(c *client, id string, m *v1.SendMessage) {
	info, agent := h.target(c, id, m.Session)
	if agent == nil {
		return
	}
	if strings.TrimSpace(m.Text) == "" {
		c.conn.Send(errFrame(id, "invalid", "message is empty"))
		return
	}
	if m.Fork {
		now := time.Now().UnixMilli()
		fork := &v1.SessionInfo{
			Id: uuid.NewString(), Node: info.Node, Cwd: info.Cwd, Title: "Fork: " + info.Title, GitBranch: info.GitBranch,
			State: v1.SessionState_SESSION_STATE_RUNNING, CreatedMs: now, UpdatedMs: now, LastPrompt: m.Text, Model: info.Model,
		}
		h.putSession(fork)
		agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Start{Start: &v1.AgentCommand_StartRun{
			Session: fork.Id, Cwd: info.Cwd, Prompt: m.Text, Resume: info.Id, Fork: true,
		}}}))
		ack(c, id, fork.Id)
		return
	}
	if info.State == v1.SessionState_SESSION_STATE_TERMINAL_ACTIVE ||
		info.Host == v1.SessionHost_SESSION_HOST_TERMINAL && info.State != v1.SessionState_SESSION_STATE_IDLE {
		c.conn.Send(errFrame(id, "terminal_active", "session is open in a terminal; fork it instead"))
		return
	}
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Send{Send: &v1.AgentCommand_SendInput{Session: info.Id, Text: m.Text}}}))
	ack(c, id, info.Id)
}

func (h *Hub) target(c *client, id, session string) (*v1.SessionInfo, *wire.Conn) {
	info := h.sessions[session]
	if info == nil {
		c.conn.Send(errFrame(id, "not_found", "unknown session"))
		return nil, nil
	}
	agent := h.agents[info.Node]
	if agent == nil {
		c.conn.Send(errFrame(id, "node_offline", "node is not connected"))
		return nil, nil
	}
	return info, agent
}

func (h *Hub) decide(c *client, id string, d *v1.ApprovalDecision) {
	a := h.approvals[d.ApprovalId]
	if a == nil {
		c.conn.Send(errFrame(id, "not_found", "approval already resolved"))
		return
	}
	agent := h.agents[a.Node]
	if agent == nil {
		c.conn.Send(errFrame(id, "node_offline", "node is not connected"))
		return
	}
	agent.Send(&v1.Frame{Body: &v1.Frame_ApprovalDecision{ApprovalDecision: d}})
	delete(h.approvals, d.ApprovalId)
	h.broadcast(&v1.Frame{Body: &v1.Frame_ApprovalResolved{ApprovalResolved: &v1.ApprovalResolved{
		ApprovalId: a.ApprovalId, Session: a.Session, Decision: d.Decision, By: c.name,
	}}})
	ack(c, id, a.Session)
}

// ---- agents ----

func (h *Hub) serveAgent(conn *wire.Conn, st *v1.NodeStatus) {
	node := st.Node
	h.mu.Lock()
	if old := h.agents[node]; old != nil {
		old.Close(errors.New("replaced by a new connection"))
	}
	h.agents[node] = conn
	st.Online, st.LastSeenMs = true, time.Now().UnixMilli()
	h.putNode(st)
	for s, set := range h.subs {
		if info := h.sessions[s]; info != nil && info.Node == node && len(set) > 0 {
			delete(h.mirroring, s)
			h.ensureMirror(s)
		}
	}
	h.mu.Unlock()
	h.log.Info("agent connected", "node", node, "os", st.Os, "claude", st.ClaudeVersion)

	err := conn.Run(func(f *v1.Frame) { h.onAgent(node, f) })

	h.mu.Lock()
	if h.agents[node] == conn {
		delete(h.agents, node)
		if n := h.nodes[node]; n != nil {
			n = proto.Clone(n).(*v1.NodeStatus)
			n.Online, n.RunningSessions, n.LastSeenMs = false, 0, time.Now().UnixMilli()
			h.putNode(n)
		}
		h.dropNode(node)
	}
	h.mu.Unlock()
	h.log.Info("agent disconnected", "node", node, "err", err)
}

func (h *Hub) dropNode(node string) {
	for s := range h.mirroring {
		if info := h.sessions[s]; info != nil && info.Node == node {
			delete(h.mirroring, s)
		}
	}
	for id, a := range h.approvals {
		if a.Node == node {
			delete(h.approvals, id)
			h.broadcast(&v1.Frame{Body: &v1.Frame_ApprovalResolved{ApprovalResolved: &v1.ApprovalResolved{
				ApprovalId: id, Session: a.Session, By: "agent disconnected",
			}}})
		}
	}
	for _, s := range h.sessions {
		if s.Node == node && live(s.State) {
			n := proto.Clone(s).(*v1.SessionInfo)
			n.State = v1.SessionState_SESSION_STATE_IDLE
			h.putSession(n)
		}
	}
}

func (h *Hub) onAgent(node string, f *v1.Frame) {
	h.mu.Lock()
	defer h.mu.Unlock()
	switch b := f.Body.(type) {
	case *v1.Frame_SessionIndex:
		for _, s := range b.SessionIndex.Sessions {
			s.Node = node
			h.mergeSession(s)
		}
	case *v1.Frame_RawEvents:
		h.ingest(node, b.RawEvents)
	case *v1.Frame_ApprovalRequested:
		a := b.ApprovalRequested
		a.Node, a.CreatedMs = node, time.Now().UnixMilli()
		if a.Kind != v1.ApprovalRequest_KIND_FOLDER_TRUST {
			a.Preview = render.ToolCard(a.ApprovalId, a.ToolName, json.RawMessage(a.InputJson))
		}
		h.approvals[a.ApprovalId] = a
		h.broadcast(&v1.Frame{Body: &v1.Frame_ApprovalRequested{ApprovalRequested: proto.Clone(a).(*v1.ApprovalRequest)}})
	case *v1.Frame_ApprovalResolved:
		// Answered on the node itself, usually in the terminal.
		r := b.ApprovalResolved
		if a := h.approvals[r.ApprovalId]; a != nil && a.Node == node {
			delete(h.approvals, r.ApprovalId)
			h.broadcast(&v1.Frame{Body: &v1.Frame_ApprovalResolved{ApprovalResolved: r}})
		}
	case *v1.Frame_NodeStatus:
		st := b.NodeStatus
		st.Node, st.Online, st.LastSeenMs = node, true, time.Now().UnixMilli()
		h.putNode(st)
	}
}

// mergeSession folds an agent's view of a session into the hub's, keeping
// what only the hub knows (to-dos, cost) and anything the agent left blank.
func (h *Hub) mergeSession(in *v1.SessionInfo) {
	cur := h.sessions[in.Id]
	if cur != nil {
		in.Todos, in.LastCostUsd = cur.Todos, cur.LastCostUsd
		in.Title = firstNonEmpty(in.Title, cur.Title)
		in.Cwd = firstNonEmpty(in.Cwd, cur.Cwd)
		in.GitBranch = firstNonEmpty(in.GitBranch, cur.GitBranch)
		in.Model = firstNonEmpty(in.Model, cur.Model)
		in.LastPrompt = firstNonEmpty(in.LastPrompt, cur.LastPrompt)
		in.ClaudeVersion = firstNonEmpty(in.ClaudeVersion, cur.ClaudeVersion)
		if in.CreatedMs == 0 {
			in.CreatedMs = cur.CreatedMs
		}
		if in.UpdatedMs < cur.UpdatedMs {
			in.UpdatedMs = cur.UpdatedMs
		}
		if in.MessageCount < cur.MessageCount {
			in.MessageCount = cur.MessageCount
		}
		if proto.Equal(in, cur) {
			return
		}
	}
	h.putSession(in)
}

func (h *Hub) ingest(node string, ev *v1.RawEvents) {
	s := ev.Session
	info := h.sessions[s]
	if info == nil {
		info = &v1.SessionInfo{Id: s, Node: node, State: v1.SessionState_SESSION_STATE_IDLE}
		h.putSession(info)
	}
	b := h.builder(s)
	var items []*v1.TimelineItem
	var patch render.Patch
	for _, line := range ev.Lines {
		out := b.Feed([]byte(line))
		if out.Delta {
			h.addPending(s, out.Items)
		} else if len(out.Items) > 0 {
			items = append(items, h.takePending(s)...)
			items = append(items, out.Items...)
		}
		mergePatch(&patch, out.Patch)
	}
	h.commit(s, items)
	if ev.Source == v1.RawEvents_SOURCE_TRANSCRIPT && ev.EndOffset > 0 {
		if err := h.store.SetTranscriptOffset(s, ev.EndOffset); err != nil {
			h.log.Error("save offset", "session", s, "err", err)
		}
	}
	if !patch.Empty() {
		h.applyPatch(s, patch)
	}
}

func (h *Hub) applyPatch(s string, p render.Patch) {
	n := proto.Clone(h.sessions[s]).(*v1.SessionInfo)
	if p.Title != "" {
		n.Title = p.Title
	}
	if p.Model != "" {
		n.Model = p.Model
	}
	if n.Cwd == "" {
		n.Cwd = p.Cwd
	}
	if n.ClaudeVersion == "" {
		n.ClaudeVersion = p.Version
	}
	if p.TodosSet {
		n.Todos = p.Todos
	}
	if p.Cost != nil {
		n.LastCostUsd = *p.Cost
	}
	if !proto.Equal(n, h.sessions[s]) {
		h.putSession(n)
	}
}

func mergePatch(dst *render.Patch, p render.Patch) {
	if p.Title != "" {
		dst.Title = p.Title
	}
	if p.Model != "" {
		dst.Model = p.Model
	}
	if p.Cwd != "" {
		dst.Cwd = p.Cwd
	}
	if p.Version != "" {
		dst.Version = p.Version
	}
	if p.TodosSet {
		dst.Todos, dst.TodosSet = p.Todos, true
	}
	if p.Cost != nil {
		dst.Cost = p.Cost
	}
}

func (h *Hub) builder(s string) *render.Builder {
	b := h.builders[s]
	if b == nil {
		b = render.NewBuilder()
		b.Lookup = func(id string) *v1.TimelineItem {
			it, err := h.store.Item(s, id)
			if err != nil {
				h.log.Error("lookup item", "session", s, "err", err)
			}
			return it
		}
		h.builders[s] = b
	}
	return b
}

func (h *Hub) addPending(s string, items []*v1.TimelineItem) {
	p := h.pending[s]
	if p == nil {
		p = &pendingItems{items: map[string]*v1.TimelineItem{}}
		h.pending[s] = p
	}
	for _, it := range items {
		if _, ok := p.items[it.ItemId]; !ok {
			p.order = append(p.order, it.ItemId)
		}
		p.items[it.ItemId] = it
	}
}

func (h *Hub) takePending(s string) []*v1.TimelineItem {
	p := h.pending[s]
	if p == nil {
		return nil
	}
	delete(h.pending, s)
	out := make([]*v1.TimelineItem, 0, len(p.order))
	for _, id := range p.order {
		out = append(out, p.items[id])
	}
	return out
}

// commit stores items and fans the changed ones out to subscribers.
func (h *Hub) commit(s string, items []*v1.TimelineItem) {
	items = collapse(items)
	if len(items) == 0 {
		return
	}
	stored, seq, err := h.store.PutItems(s, items)
	if err != nil {
		h.log.Error("store items", "session", s, "err", err)
		return
	}
	if len(stored) == 0 {
		return
	}
	f := &v1.Frame{Seq: seq, Body: timeline(s, stored)}
	for c := range h.subs[s] {
		c.conn.Send(f)
	}
}

// collapse keeps the last version of each item at its first position.
func collapse(items []*v1.TimelineItem) []*v1.TimelineItem {
	idx := map[string]int{}
	var out []*v1.TimelineItem
	for _, it := range items {
		if i, ok := idx[it.ItemId]; ok {
			out[i] = it
			continue
		}
		idx[it.ItemId] = len(out)
		out = append(out, it)
	}
	return out
}

func (h *Hub) ensureMirror(s string) {
	info := h.sessions[s]
	if info == nil || h.mirroring[s] {
		return
	}
	agent := h.agents[info.Node]
	if agent == nil {
		return
	}
	off, err := h.store.TranscriptOffset(s)
	if err != nil {
		h.log.Error("read offset", "session", s, "err", err)
	}
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Mirror_{Mirror: &v1.AgentCommand_Mirror{Session: s, FromOffset: off}}}))
	h.mirroring[s] = true
}

func (h *Hub) maybeStopMirror(s string) {
	if len(h.subs[s]) > 0 {
		return
	}
	delete(h.subs, s)
	info := h.sessions[s]
	if h.mirroring[s] && info != nil {
		if agent := h.agents[info.Node]; agent != nil {
			agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_StopMirror_{StopMirror: &v1.AgentCommand_StopMirror{Session: s}}}))
		}
		delete(h.mirroring, s)
	}
	// Keep the builder while a run streams; it tracks partial blocks.
	if info == nil || !live(info.State) {
		delete(h.builders, s)
	}
}

// ---- shared state ----

func (h *Hub) putSession(info *v1.SessionInfo) {
	h.sessions[info.Id] = info
	if err := h.store.PutSession(info); err != nil {
		h.log.Error("store session", "session", info.Id, "err", err)
	}
	h.broadcast(&v1.Frame{Body: &v1.Frame_SessionInfo{SessionInfo: proto.Clone(info).(*v1.SessionInfo)}})
}

func (h *Hub) putNode(st *v1.NodeStatus) {
	h.nodes[st.Node] = st
	if err := h.store.PutNode(st); err != nil {
		h.log.Error("store node", "node", st.Node, "err", err)
	}
	h.broadcast(&v1.Frame{Body: &v1.Frame_NodeStatus{NodeStatus: proto.Clone(st).(*v1.NodeStatus)}})
}

func (h *Hub) broadcast(f *v1.Frame) {
	for c := range h.clients {
		c.conn.Send(f)
	}
}

func timeline(s string, items []*v1.TimelineItem) *v1.Frame_Timeline {
	return &v1.Frame_Timeline{Timeline: &v1.TimelineUpdate{Session: s, Items: items}}
}

func command(c *v1.AgentCommand) *v1.Frame {
	return &v1.Frame{Body: &v1.Frame_AgentCommand{AgentCommand: c}}
}

func ack(c *client, replyTo, session string) {
	c.conn.Send(&v1.Frame{ReplyTo: replyTo, Body: &v1.Frame_Ack{Ack: &v1.Ack{Session: session}}})
}

func errFrame(replyTo, code, msg string) *v1.Frame {
	return &v1.Frame{ReplyTo: replyTo, Body: &v1.Frame_Error{Error: &v1.Error{Code: code, Message: msg}}}
}

func clip(s string, n int) string {
	s = strings.Join(strings.Fields(s), " ")
	if r := []rune(s); len(r) > n {
		return string(r[:n-1]) + "…"
	}
	return s
}

func firstNonEmpty(ss ...string) string {
	for _, s := range ss {
		if s != "" {
			return s
		}
	}
	return ""
}
