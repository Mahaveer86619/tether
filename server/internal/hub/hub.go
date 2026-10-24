// Package hub is the central router: agents push raw Claude Code output in,
// the hub renders and stores it, and clients subscribe to the result.
package hub

import (
	"context"
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
	// The admin token; paired devices have their own.
	Token   string
	Version string
	Log     *slog.Logger
	// SHA-256 of the hub's self-signed certificate, handed out with pairing
	// codes so clients can pin it. Empty without TLS or with a CA-issued one.
	CertFingerprint string
	// Reads `tailscale status --json`; defaults to running the CLI.
	TailscaleStatus func(context.Context) ([]byte, error)
	// Accept apps and agents without a token when they connect from a
	// machine owned by the hub machine's own Tailscale user.
	TrustTailnet bool
	// Where the hub keeps files: the artifact store lives under it.
	DataDir string
	// Releases to serve; defaults to <DataDir>/updates.
	UpdatesDir string
	// A published latest.json to poll for new releases; empty turns it off.
	UpdateFeed string
	// Tell idle agents older than the newest release to update themselves.
	AutoUpdateAgents bool
	// Take secrets out of stored history (see docs/history.md).
	HistoryRedact bool
	// Drop a session's history after this many days untouched, and the
	// oldest sessions' when it outgrows this many MB; 0 keeps everything.
	HistoryKeepDays int
	HistoryMaxMB    int
}

type client struct {
	conn     *wire.Conn
	name     string
	device   string
	ip       string
	platform string
	version  string
	since    time.Time
	// In the foreground, as the app last said; apps from before presence
	// count as active while connected.
	active bool
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

	devices      map[string]*v1.Device // by token hash
	agentDevices map[string]string     // node -> device id of its connection
	agentIPs     map[string]string     // node -> address it connects from
	codes        map[string]time.Time  // pairing code -> expiry
	fails        map[string][]time.Time
	prefs        *v1.Preferences
	plans        map[string]*v1.PlanUsage // node -> its latest /usage report
	keyOnce      sync.Once
	linkKey      []byte

	tsMu     sync.Mutex
	tsStatus *tsStatus
	tsAt     time.Time

	sent        map[string][]sentMsg         // session -> messages sent through the hub
	keptSources map[string]map[string]string // session -> item -> source, across a rebuild

	uploadMu  sync.Mutex
	uploading map[string]bool // upload id -> a request is writing it

	queuedItems   map[string]map[string]string         // session -> its "queued" placeholders' text, by item
	modeBefore    map[string]modeSwitch                // session -> a switch the node hasn't confirmed
	screens       map[string]*v1.ScreenSnapshot        // session -> its last terminal screen
	screenWaiters map[string][]chan *v1.ScreenSnapshot // session -> requests waiting for a capture
	lastBackup    time.Time

	chats  map[string]*v1.Chat
	chatOf map[string]string // session -> the chat it's in

	update       *v1.UpdateManifest     // the newest release known
	agentUpdates map[string]agentUpdate // node -> the update last asked of it
}

func New(cfg Config, st *store.Store) (*Hub, error) {
	h := &Hub{
		cfg:           cfg,
		store:         st,
		log:           cfg.Log,
		agents:        map[string]*wire.Conn{},
		clients:       map[*client]struct{}{},
		nodes:         map[string]*v1.NodeStatus{},
		sessions:      map[string]*v1.SessionInfo{},
		subs:          map[string]map[*client]struct{}{},
		builders:      map[string]*render.Builder{},
		screens:       map[string]*v1.ScreenSnapshot{},
		queuedItems:   map[string]map[string]string{},
		modeBefore:    map[string]modeSwitch{},
		screenWaiters: map[string][]chan *v1.ScreenSnapshot{},
		pending:       map[string]*pendingItems{},
		approvals:     map[string]*v1.ApprovalRequest{},
		mirroring:     map[string]bool{},

		agentDevices: map[string]string{},
		agentIPs:     map[string]string{},
		sent:         map[string][]sentMsg{},
		plans:        map[string]*v1.PlanUsage{},
		keptSources:  map[string]map[string]string{},
		codes:        map[string]time.Time{},
		fails:        map[string][]time.Time{},
		chats:        map[string]*v1.Chat{},
		chatOf:       map[string]string{},
		agentUpdates: map[string]agentUpdate{},
	}
	devices, err := st.Devices()
	if err != nil {
		return nil, err
	}
	h.devices = devices
	if b, err := st.Get(prefsKey); err != nil {
		return nil, err
	} else if b != nil {
		h.prefs = &v1.Preferences{}
		if err := proto.Unmarshal(b, h.prefs); err != nil {
			return nil, err
		}
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
	if err := h.loadChats(); err != nil {
		return nil, err
	}
	h.loadLocalUpdate()
	return h, nil
}

func busy(s v1.SessionState) bool {
	return s == v1.SessionState_SESSION_STATE_RUNNING || s == v1.SessionState_SESSION_STATE_AWAITING_APPROVAL
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
	h.routes(mux)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok\n")) })
	return mux
}

// Run flushes coalesced streaming updates until ctx ends.
func (h *Hub) Run(ctx context.Context) {
	go h.retentionLoop(ctx)
	go h.modeLoop(ctx)
	go h.backupLoop(ctx)
	go h.updateLoop(ctx)
	go h.historyLoop(ctx)
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
	ip := remoteIP(r)
	if h.limited(ip) {
		_ = conn.WriteNow(r.Context(), errFrame("", errRateLimited.Code, errRateLimited.Message))
		conn.Close(errors.New("rate limited"))
		return
	}
	switch b := f.Body.(type) {
	case *v1.Frame_ClientHello:
		id, ok := h.identifyFrom(b.ClientHello.Token, ip)
		if !ok || id.kind == kindNode {
			h.reject(conn, r)
			return
		}
		h.serveClient(conn, b.ClientHello, id.deviceID(), ip)
	case *v1.Frame_AgentHello:
		node := b.AgentHello.Status.GetNode()
		id, ok := h.identifyFrom(b.AgentHello.Token, ip)
		// A node token only ever connects as the node it was paired for.
		if !ok || node == "" || id.kind == kindClient || id.kind == kindNode && id.device.Name != node {
			h.reject(conn, r)
			return
		}
		h.serveAgent(conn, b.AgentHello.Status, id.deviceID(), ip)
	default:
		conn.Close(errors.New("expected hello"))
	}
}

func (h *Hub) reject(conn *wire.Conn, r *http.Request) {
	h.log.Warn("rejected connection", "remote", r.RemoteAddr)
	h.fail(remoteIP(r))
	// The write queue only runs once a connection is accepted, so write directly.
	_ = conn.WriteNow(r.Context(), errFrame("", errUnauthorized.Code, errUnauthorized.Message))
	conn.Close(errors.New("unauthorized"))
}

// ---- clients ----

func (h *Hub) serveClient(conn *wire.Conn, hello *v1.ClientHello, device, ip string) {
	c := &client{conn: conn, name: hello.ClientName, device: device, ip: ip, platform: hello.Platform, version: hello.AppVersion, since: time.Now(), active: true}
	h.mu.Lock()
	h.clients[c] = struct{}{}
	conn.Send(&v1.Frame{Body: &v1.Frame_Welcome{Welcome: h.welcome(device, ip)}})
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

// welcome is the full state for a client connecting with a paired device id
// (or "") from ip.
func (h *Hub) welcome(device, ip string) *v1.Welcome {
	w := &v1.Welcome{HubVersion: h.cfg.Version, DeviceId: device, ClientIp: ip}
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
	if h.prefs != nil {
		w.Preferences = proto.Clone(h.prefs).(*v1.Preferences)
	}
	w.HubNode = h.hubNode()
	w.Chats = h.chatList()
	w.Update = h.servedManifest()
	return w
}

func (h *Hub) onClient(c *client, f *v1.Frame) {
	h.mu.Lock()
	defer h.mu.Unlock()
	var session string
	var err *opError
	switch b := f.Body.(type) {
	case *v1.Frame_Subscribe:
		h.subscribe(c, f.Id, b.Subscribe)
		return
	case *v1.Frame_ClientPresence:
		h.notePresence(c, b.ClientPresence.Active)
		return
	case *v1.Frame_Unsubscribe:
		if set := h.subs[b.Unsubscribe.Session]; set != nil {
			delete(set, c)
			h.maybeStopMirror(b.Unsubscribe.Session)
		}
	case *v1.Frame_CreateSession:
		session, err = h.createSession(b.CreateSession, c.name)
	case *v1.Frame_SendMessage:
		session, err = h.sendMessage(b.SendMessage, c.name)
	case *v1.Frame_InterruptSession:
		session, err = h.interrupt(b.InterruptSession.Session)
	case *v1.Frame_StopSession:
		session, err = h.stop(b.StopSession.Session)
	case *v1.Frame_ApprovalDecision:
		session, err = h.decide(c.name, b.ApprovalDecision)
	default:
		err = errUnsupported
	}
	if err != nil {
		c.conn.Send(errFrame(f.Id, err.Code, err.Message))
		return
	}
	ack(c, f.Id, session)
}

func (h *Hub) subscribe(c *client, id string, s *v1.Subscribe) {
	if h.sessions[s.Session] == nil {
		c.conn.Send(errFrame(id, errNotFound.Code, errNotFound.Message))
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

// The operations below are shared by the WebSocket and REST APIs. They
// expect h.mu to be held and return the affected session id.

func (h *Hub) createSession(cs *v1.CreateSession, from string) (string, *opError) {
	return h.startSession(cs, from, startExtra{})
}

// startExtra is what chats add to a new session.
type startExtra struct {
	systemPrompt, clientID string
}

func (h *Hub) startSession(cs *v1.CreateSession, from string, extra startExtra) (string, *opError) {
	if cs.Scratch {
		cs.Node, cs.Cwd = h.hubNode(), ""
		if cs.Node == "" {
			return "", &opError{"node_offline", "no agent is running on the hub's machine", http.StatusServiceUnavailable}
		}
	}
	agent := h.agents[cs.Node]
	if agent == nil {
		return "", errNodeOffline
	}
	if strings.TrimSpace(cs.Prompt) == "" {
		return "", invalid("prompt is empty")
	}
	now := time.Now().UnixMilli()
	info := &v1.SessionInfo{
		Id: uuid.NewString(), Node: cs.Node, Cwd: cs.Cwd, Title: firstNonEmpty(cs.Name, clip(cs.Prompt, 80)),
		State: v1.SessionState_SESSION_STATE_RUNNING, CreatedMs: now, UpdatedMs: now, LastPrompt: cs.Prompt, Model: cs.Model,
		Scratch: cs.Scratch,
	}
	attachments, aerr := h.attachments(cs.Attachments)
	if aerr != nil {
		return "", aerr
	}
	prompt, long, aerr := h.fileLongText(info.Id, cs.Prompt)
	if aerr != nil {
		return "", aerr
	}
	if long != nil {
		attachments = append(attachments, long)
	}
	h.putSession(info)
	h.noteSentAs(info.Id, prompt, from, extra.clientID)
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Start{Start: &v1.AgentCommand_StartRun{
		Session: info.Id, Cwd: cs.Cwd, Prompt: prompt, Model: cs.Model, PermissionMode: cs.PermissionMode, Name: cs.Name, CreateCwd: cs.CreateCwd,
		Attachments: attachments, Scratch: cs.Scratch, SystemPrompt: extra.systemPrompt,
	}}}))
	return info.Id, nil
}

func (h *Hub) sendMessage(m *v1.SendMessage, from string) (string, *opError) {
	info, agent, err := h.target(m.Session)
	if err != nil {
		return "", err
	}
	if strings.TrimSpace(m.Text) == "" {
		return "", invalid("message is empty")
	}
	if !m.Fork && h.alreadySent(info.Id, m.ClientId) {
		return info.Id, nil
	}
	if m.Fork {
		now := time.Now().UnixMilli()
		point, perr := h.store.LastItemID(info.Id)
		if perr != nil {
			h.log.Error("fork point", "session", info.Id, "err", perr)
		}
		fork := &v1.SessionInfo{
			Id: uuid.NewString(), Node: info.Node, Cwd: info.Cwd, Title: "Fork: " + info.Title, GitBranch: info.GitBranch,
			State: v1.SessionState_SESSION_STATE_RUNNING, CreatedMs: now, UpdatedMs: now, LastPrompt: m.Text, Model: info.Model,
			Parent: info.Id, ForkPoint: point, Lineage: "fork",
			// Every fork is kept on the hub: its transcript and its codebase.
			Global: true,
		}
		h.putSession(fork)
		h.snapshotSession(fork)
		h.recordLineage(&v1.LineageEvent{Session: fork.Id, Parent: info.Id, Kind: "fork", ForkPoint: point, By: from, AtMs: now})
		h.noteSent(fork.Id, m.Text, from)
		agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Start{Start: &v1.AgentCommand_StartRun{
			Session: fork.Id, Cwd: info.Cwd, Prompt: m.Text, Resume: info.Id, Fork: true, PermissionMode: modeArg(info.PermissionMode),
		}}}))
		return fork.Id, nil
	}
	if info.State == v1.SessionState_SESSION_STATE_TERMINAL_ACTIVE ||
		info.Host == v1.SessionHost_SESSION_HOST_TERMINAL && info.State != v1.SessionState_SESSION_STATE_IDLE && !info.TerminalInput {
		return "", errTerminalActive
	}
	attachments, aerr := h.attachments(m.Attachments)
	if aerr != nil {
		return "", aerr
	}
	text, long, aerr := h.fileLongText(info.Id, m.Text)
	if aerr != nil {
		return "", aerr
	}
	if long != nil {
		attachments = append(attachments, long)
	}
	h.noteSentAs(info.Id, text, from, m.ClientId)
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Send{Send: &v1.AgentCommand_SendInput{Session: info.Id, Text: text, Attachments: attachments, PermissionMode: modeArg(info.PermissionMode),
		SystemPrompt: h.chatSystemPrompt(info.Id)}}}))
	return info.Id, nil
}

func (h *Hub) interrupt(session string) (string, *opError) {
	info, agent, err := h.target(session)
	if err != nil {
		return "", err
	}
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Interrupt_{Interrupt: &v1.AgentCommand_Interrupt{Session: info.Id}}}))
	return info.Id, nil
}

func (h *Hub) stop(session string) (string, *opError) {
	info, agent, err := h.target(session)
	if err != nil {
		return "", err
	}
	if info.Host == v1.SessionHost_SESSION_HOST_TERMINAL {
		return "", errTerminalOwned
	}
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Stop_{Stop: &v1.AgentCommand_Stop{Session: info.Id}}}))
	return info.Id, nil
}

// archive marks a session as done, or not. It needs no agent: the flag is
// the hub's own.
func (h *Hub) archive(session string, archived bool) (string, *opError) {
	info := h.sessions[session]
	if info == nil {
		return "", errNotFound
	}
	if info.Archived != archived {
		next := proto.Clone(info).(*v1.SessionInfo)
		next.Archived = archived
		h.putSession(next)
	}
	return info.Id, nil
}

// rebuild re-renders a session's timeline from its transcript, e.g. after
// the renderer learned a new line type.
func (h *Hub) rebuild(session string) (string, *opError) {
	info := h.sessions[session]
	if info == nil {
		return "", errNotFound
	}
	// A headless run streams partial blocks into the builder; only
	// transcript-mirrored sessions can be reset while live.
	if info.Host == v1.SessionHost_SESSION_HOST_HEADLESS && live(info.State) {
		return "", &opError{"busy", "a headless run is live; rebuild it once it ends", http.StatusConflict}
	}
	h.keepSources(session)
	if err := h.store.ResetTimeline(session); err != nil {
		return "", &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	delete(h.builders, session)
	delete(h.pending, session)
	delete(h.queuedItems, session)
	if h.mirroring[session] {
		if agent := h.agents[info.Node]; agent != nil {
			agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_StopMirror_{StopMirror: &v1.AgentCommand_StopMirror{Session: session}}}))
		}
		delete(h.mirroring, session)
		h.ensureMirror(session)
	}
	return session, nil
}

func (h *Hub) target(session string) (*v1.SessionInfo, *wire.Conn, *opError) {
	info := h.sessions[session]
	if info == nil {
		return nil, nil, errNotFound
	}
	agent := h.agents[info.Node]
	if agent == nil {
		return nil, nil, errNodeOffline
	}
	return info, agent, nil
}

func (h *Hub) decide(by string, d *v1.ApprovalDecision) (string, *opError) {
	a := h.approvals[d.ApprovalId]
	if a == nil {
		return "", &opError{Code: "not_found", Message: "approval already resolved", Status: http.StatusNotFound}
	}
	agent := h.agents[a.Node]
	if agent == nil {
		return "", errNodeOffline
	}
	agent.Send(&v1.Frame{Body: &v1.Frame_ApprovalDecision{ApprovalDecision: d}})
	delete(h.approvals, d.ApprovalId)
	h.broadcast(&v1.Frame{Body: &v1.Frame_ApprovalResolved{ApprovalResolved: &v1.ApprovalResolved{
		ApprovalId: a.ApprovalId, Session: a.Session, Decision: d.Decision, By: by,
	}}})
	return a.Session, nil
}

// ---- agents ----

func (h *Hub) serveAgent(conn *wire.Conn, st *v1.NodeStatus, device, ip string) {
	node := st.Node
	h.mu.Lock()
	if old := h.agents[node]; old != nil {
		old.Close(errors.New("replaced by a new connection"))
	}
	h.agents[node] = conn
	h.agentDevices[node] = device
	h.agentIPs[node] = ip
	st.Online, st.LastSeenMs = true, time.Now().UnixMilli()
	h.putNode(st)
	h.scanRoots(node)
	h.requestHistory(node)
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
		idx := b.SessionIndex
		known := map[string]bool{}
		for _, s := range idx.Sessions {
			s.Node = node
			known[s.Id] = true
			h.mergeSession(s)
		}
		for _, id := range idx.Removed {
			h.removeSession(node, id)
		}
		if idx.Full {
			for id, s := range h.sessions {
				if s.Node == node && !known[id] {
					h.removeSession(node, id)
				}
			}
		}
	case *v1.Frame_RawEvents:
		h.ingest(node, b.RawEvents)
	case *v1.Frame_PlanUsage:
		h.setPlan(node, b.PlanUsage)
	case *v1.Frame_UsageReport:
		if err := h.store.PutUsage(node, b.UsageReport.Entries); err != nil {
			h.log.Error("store usage", "node", node, "err", err)
		}
	case *v1.Frame_ApprovalRequested:
		a := b.ApprovalRequested
		a.Node, a.CreatedMs = node, time.Now().UnixMilli()
		if a.Kind != v1.ApprovalRequest_KIND_FOLDER_TRUST && a.Kind != v1.ApprovalRequest_KIND_PROMPT {
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
	case *v1.Frame_ScreenSnapshot:
		h.noteScreen(node, b.ScreenSnapshot)
	case *v1.Frame_ModeResult:
		h.noteModeResult(node, b.ModeResult)
	case *v1.Frame_CommandResult:
		h.noteCommandResult(node, b.CommandResult)
	case *v1.Frame_HistoryChunk:
		c := b.HistoryChunk
		offset := h.ingestChunk(node, c)
		if agent := h.agents[node]; agent != nil {
			agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_HistoryAck_{HistoryAck: &v1.AgentCommand_HistoryAck{Session: c.Session, File: c.File, Offset: offset}}}))
		}
	case *v1.Frame_HistorySynced:
		h.noteHistorySynced(node, b.HistorySynced.AtMs)
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
		in.Archived = cur.Archived && !busy(in.State)
		in.Parent, in.ForkPoint, in.Lineage = cur.Parent, cur.ForkPoint, cur.Lineage
		in.Scratch, in.Global = cur.Scratch, cur.Global
		in.PermissionMode, in.ModeRevertMs, in.ModeRevertTo = cur.PermissionMode, cur.ModeRevertMs, cur.ModeRevertTo
		in.BackedUpMs, in.BackedUpBytes = cur.BackedUpMs, cur.BackedUpBytes
		// A global session's copy is refreshed whenever a turn ends.
		if in.Global && busy(cur.State) && !busy(in.State) {
			defer h.uploadTranscript(in)
		}
		if busy(cur.State) && !busy(in.State) {
			defer h.noteTurnEnded(in.Id)
		}
		if in.State != cur.State {
			defer h.noteStateEvent(in)
		}
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
		h.keepImages(s, node, out.Images)
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
	// A pending switch wins over transcript lines written before it landed.
	if p.Mode != "" && !h.switchingMode(s) {
		n.PermissionMode = p.Mode
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
	if p.Mode != "" {
		dst.Mode = p.Mode
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
	h.tagSources(s, items)
	h.expandLongText(s, items)
	items = h.dropStaleQueued(s, items)
	stored, seq, err := h.store.PutItems(s, items)
	if err != nil {
		h.log.Error("store items", "session", s, "err", err)
		return
	}
	if len(stored) == 0 {
		return
	}
	h.keepMessages(s, stored)
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

// removeSession forgets a session its node no longer has. Live sessions
// are kept: their transcript may simply not exist yet.
func (h *Hub) removeSession(node, id string) {
	s := h.sessions[id]
	if s == nil || s.Node != node || live(s.State) {
		return
	}
	delete(h.sessions, id)
	delete(h.builders, id)
	delete(h.pending, id)
	delete(h.mirroring, id)
	if err := h.store.DeleteSession(id); err != nil {
		h.log.Error("delete session", "session", id, "err", err)
	}
	h.broadcast(&v1.Frame{Body: &v1.Frame_SessionRemoved{SessionRemoved: &v1.SessionRemoved{Session: id}}})
}

// ---- shared state ----

func (h *Hub) putSession(info *v1.SessionInfo) {
	_, known := h.sessions[info.Id]
	h.sessions[info.Id] = info
	if !known {
		defer h.noteNewSession(info)
	}
	if err := h.store.PutSession(info); err != nil {
		h.log.Error("store session", "session", info.Id, "err", err)
	}
	h.broadcast(&v1.Frame{Body: &v1.Frame_SessionInfo{SessionInfo: proto.Clone(info).(*v1.SessionInfo)}})
}

func (h *Hub) putNode(st *v1.NodeStatus) {
	// Kept while offline, so an app can still tell its own machine's node.
	if ip := h.agentIPs[st.Node]; ip != "" {
		st.Ip = ip
	} else if old := h.nodes[st.Node]; old != nil {
		st.Ip = old.Ip
	}
	// Agents don't report it; the hub keeps it across their updates.
	if old := h.nodes[st.Node]; old != nil && st.HistorySyncedMs == 0 {
		st.HistorySyncedMs = old.HistorySyncedMs
	}
	h.nodes[st.Node] = st
	if err := h.store.PutNode(st); err != nil {
		h.log.Error("store node", "node", st.Node, "err", err)
	}
	h.broadcast(&v1.Frame{Body: &v1.Frame_NodeStatus{NodeStatus: proto.Clone(st).(*v1.NodeStatus)}})
	if st.Online {
		h.maybeUpdateAgent(st.Node)
	}
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
