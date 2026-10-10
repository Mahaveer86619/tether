// Package agent runs on each machine with Claude Code. It indexes local
// sessions, runs headless sessions for the hub, and mirrors transcripts.
package agent

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

const (
	scanInterval   = 3 * time.Second
	tailInterval   = 500 * time.Millisecond
	idleRunTimeout = 15 * time.Minute
	// A transcript written this recently without a Tether run is treated as
	// an open terminal session.
	terminalWindow = 90 * time.Second
	mirrorChunk    = 1 << 20
	maxBackoff     = 30 * time.Second
)

type Config struct {
	HubURL      string
	Token       string
	Node        string
	Claude      string
	ProjectsDir string
	Version     string
	Log         *slog.Logger
}

type Agent struct {
	cfg   Config
	log   *slog.Logger
	index *Index

	mu       sync.Mutex
	conn     *wire.Conn
	runs     map[string]*run
	ended    map[string]*v1.SessionInfo
	mirrors  map[string]context.CancelFunc
	reported map[string]*v1.SessionInfo
	claudeV  string
}

func New(cfg Config) *Agent {
	return &Agent{
		cfg:      cfg,
		log:      cfg.Log,
		index:    NewIndex(cfg.ProjectsDir),
		runs:     map[string]*run{},
		ended:    map[string]*v1.SessionInfo{},
		mirrors:  map[string]context.CancelFunc{},
		reported: map[string]*v1.SessionInfo{},
	}
}

// Run connects to the hub and keeps reconnecting until ctx ends.
func (a *Agent) Run(ctx context.Context) error {
	a.claudeV = claudeVersion(a.cfg.Claude)
	if err := a.index.Scan(); err != nil {
		a.log.Warn("initial scan", "err", err)
	}
	a.log.Info("indexed sessions", "count", len(a.index.IDs()), "dir", a.cfg.ProjectsDir)
	go a.scanLoop(ctx)

	backoff := time.Second
	for {
		started := time.Now()
		err := a.session(ctx)
		if ctx.Err() != nil {
			a.shutdown()
			return ctx.Err()
		}
		if time.Since(started) > time.Minute {
			backoff = time.Second
		}
		a.log.Warn("hub connection lost", "err", err, "retry_in", backoff)
		select {
		case <-ctx.Done():
			a.shutdown()
			return ctx.Err()
		case <-time.After(backoff):
		}
		backoff = min(backoff*2, maxBackoff)
	}
}

func (a *Agent) session(ctx context.Context) error {
	dctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	conn, err := wire.Dial(dctx, a.cfg.HubURL)
	cancel()
	if err != nil {
		return err
	}
	conn.Send(&v1.Frame{Body: &v1.Frame_AgentHello{AgentHello: &v1.AgentHello{Token: a.cfg.Token, Status: a.status()}}})

	a.mu.Lock()
	a.conn = conn
	a.reported = map[string]*v1.SessionInfo{}
	a.mu.Unlock()
	a.log.Info("connected to hub", "url", a.cfg.HubURL)
	a.publish(true)

	go func() {
		select {
		case <-ctx.Done():
			conn.Close(ctx.Err())
		case <-conn.Done():
		}
	}()
	err = conn.Run(a.onFrame)

	a.mu.Lock()
	a.conn = nil
	for s, stop := range a.mirrors {
		stop()
		delete(a.mirrors, s)
	}
	a.mu.Unlock()
	return err
}

func (a *Agent) status() *v1.NodeStatus {
	host, _ := os.Hostname()
	a.mu.Lock()
	running := int32(len(a.runs))
	a.mu.Unlock()
	return &v1.NodeStatus{
		Node: a.cfg.Node, Online: true, Os: runtime.GOOS, Hostname: host,
		ClaudeVersion: a.claudeV, AgentVersion: a.cfg.Version, RunningSessions: running,
	}
}

func (a *Agent) send(f *v1.Frame) {
	a.mu.Lock()
	c := a.conn
	a.mu.Unlock()
	if c != nil {
		c.Send(f)
	}
}

func (a *Agent) onFrame(f *v1.Frame) {
	switch b := f.Body.(type) {
	case *v1.Frame_AgentCommand:
		switch op := b.AgentCommand.Op.(type) {
		case *v1.AgentCommand_Start:
			s := op.Start
			a.start(startOpts{session: s.Session, cwd: s.Cwd, prompt: s.Prompt, model: s.Model,
				permissionMode: s.PermissionMode, name: s.Name, resume: s.Resume, fork: s.Fork})
		case *v1.AgentCommand_Send:
			a.sendInput(op.Send.Session, op.Send.Text)
		case *v1.AgentCommand_Interrupt_:
			if r := a.run(op.Interrupt.Session); r != nil {
				if err := r.interrupt(); err != nil {
					a.log.Warn("interrupt", "session", r.id, "err", err)
				}
			}
		case *v1.AgentCommand_Mirror_:
			a.startMirror(op.Mirror.Session, op.Mirror.FromOffset)
		case *v1.AgentCommand_StopMirror_:
			a.mu.Lock()
			if stop := a.mirrors[op.StopMirror.Session]; stop != nil {
				stop()
				delete(a.mirrors, op.StopMirror.Session)
			}
			a.mu.Unlock()
		}
	case *v1.Frame_ApprovalDecision:
		d := b.ApprovalDecision
		a.mu.Lock()
		runs := make([]*run, 0, len(a.runs))
		for _, r := range a.runs {
			runs = append(runs, r)
		}
		a.mu.Unlock()
		for _, r := range runs {
			if r.answer(d.ApprovalId, d.Decision == v1.Decision_DECISION_ALLOW, d.Message) {
				return
			}
		}
	}
}

func (a *Agent) run(session string) *run {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.runs[session]
}

func (a *Agent) start(o startOpts) {
	if r := a.run(o.session); r != nil {
		if err := r.send(o.prompt); err != nil {
			a.fail(o.session, err)
		}
		return
	}
	if o.resume != "" && o.cwd == "" {
		o.cwd = a.index.Cwd(o.resume)
	}
	if info := a.info(o.resume); o.resume != "" && !o.fork && info != nil && info.State == v1.SessionState_SESSION_STATE_TERMINAL_ACTIVE {
		a.fail(o.session, errTerminalActive)
		return
	}
	r, err := a.startRun(o)
	if err != nil {
		a.fail(o.session, err)
		return
	}
	a.mu.Lock()
	a.runs[o.session] = r
	delete(a.ended, o.session)
	a.mu.Unlock()
	a.sendStatus()
	if err := r.send(o.prompt); err != nil {
		a.fail(o.session, err)
	}
}

func (a *Agent) sendInput(session, text string) {
	if r := a.run(session); r != nil {
		if err := r.send(text); err != nil {
			a.fail(session, err)
		}
		return
	}
	a.start(startOpts{session: session, resume: session, prompt: text})
}

func (a *Agent) endRun(r *run) {
	st, errText := r.State()
	a.mu.Lock()
	if a.runs[r.id] == r {
		delete(a.runs, r.id)
	}
	a.ended[r.id] = &v1.SessionInfo{Id: r.id, State: st, Error: errText, UpdatedMs: time.Now().UnixMilli()}
	a.mu.Unlock()
	a.sendStatus()
	a.report(r.id)
}

func (a *Agent) fail(session string, err error) {
	a.log.Warn("run failed", "session", session, "err", err)
	a.mu.Lock()
	a.ended[session] = &v1.SessionInfo{Id: session, State: v1.SessionState_SESSION_STATE_ERROR, Error: err.Error(), UpdatedMs: time.Now().UnixMilli()}
	a.mu.Unlock()
	a.report(session)
}

func (a *Agent) terminalActive(session string) bool {
	mod, ok := a.index.Modified(session)
	return ok && time.Since(mod) < terminalWindow
}

func (a *Agent) sendStatus() {
	a.send(&v1.Frame{Body: &v1.Frame_NodeStatus{NodeStatus: a.status()}})
}

// info is the agent's current view of one session.
func (a *Agent) info(session string) *v1.SessionInfo {
	info := a.index.Info(session)
	a.mu.Lock()
	r := a.runs[session]
	ended := a.ended[session]
	a.mu.Unlock()
	if info == nil {
		if r == nil && ended == nil {
			return nil
		}
		info = &v1.SessionInfo{Id: session}
	}
	info.Node = a.cfg.Node
	mod, _ := a.index.Modified(session)
	// Writes from our own finished run are not a terminal.
	ownWrite := ended != nil && !mod.After(time.UnixMilli(ended.UpdatedMs).Add(5*time.Second))
	switch {
	case r != nil:
		info.State, info.Error = r.State()
	case a.terminalActive(session) && !ownWrite:
		info.State = v1.SessionState_SESSION_STATE_TERMINAL_ACTIVE
	case ended != nil && ended.State == v1.SessionState_SESSION_STATE_ERROR:
		info.State, info.Error = ended.State, ended.Error
	default:
		info.State = v1.SessionState_SESSION_STATE_IDLE
	}
	return info
}

func (a *Agent) report(session string) {
	if info := a.info(session); info != nil {
		a.sendInfos([]*v1.SessionInfo{info}, false)
	}
}

// publish sends every session whose info changed since it was last sent.
func (a *Agent) publish(full bool) {
	ids := a.index.IDs()
	a.mu.Lock()
	for id := range a.runs {
		ids = append(ids, id)
	}
	a.mu.Unlock()
	seen := map[string]bool{}
	var infos []*v1.SessionInfo
	for _, id := range ids {
		if seen[id] {
			continue
		}
		seen[id] = true
		if info := a.info(id); info != nil {
			infos = append(infos, info)
		}
	}
	a.sendInfos(infos, full)
}

func (a *Agent) sendInfos(infos []*v1.SessionInfo, full bool) {
	a.mu.Lock()
	var changed []*v1.SessionInfo
	for _, info := range infos {
		if prev := a.reported[info.Id]; prev != nil && proto.Equal(prev, info) {
			continue
		}
		a.reported[info.Id] = info
		changed = append(changed, info)
	}
	c := a.conn
	a.mu.Unlock()
	if c == nil || (len(changed) == 0 && !full) {
		return
	}
	c.Send(&v1.Frame{Body: &v1.Frame_SessionIndex{SessionIndex: &v1.SessionIndex{Full: full, Sessions: changed}}})
}

func (a *Agent) scanLoop(ctx context.Context) {
	t := time.NewTicker(scanInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if err := a.index.Scan(); err != nil {
				a.log.Warn("scan", "err", err)
			}
			a.publish(false)
			a.closeIdleRuns()
		}
	}
}

func (a *Agent) closeIdleRuns() {
	a.mu.Lock()
	defer a.mu.Unlock()
	for _, r := range a.runs {
		r.mu.Lock()
		idle := r.state == v1.SessionState_SESSION_STATE_READY && time.Since(r.lastActive) > idleRunTimeout
		r.mu.Unlock()
		if idle {
			r.closeInput()
		}
	}
}

func (a *Agent) shutdown() {
	a.mu.Lock()
	defer a.mu.Unlock()
	for _, r := range a.runs {
		r.closeInput()
	}
}

// ---- transcript mirroring ----

var mirrorTypes = map[string]bool{"user": true, "assistant": true, "system": true, "ai-title": true, "custom-title": true}

func (a *Agent) startMirror(session string, from int64) {
	ctx, cancel := context.WithCancel(context.Background())
	a.mu.Lock()
	if stop := a.mirrors[session]; stop != nil {
		stop()
	}
	a.mirrors[session] = cancel
	a.mu.Unlock()
	go a.mirror(ctx, session, from)
}

// mirror streams a transcript from an offset and keeps tailing it, which is
// how terminal sessions show up live in the app.
func (a *Agent) mirror(ctx context.Context, session string, off int64) {
	t := time.NewTicker(tailInterval)
	defer t.Stop()
	for {
		if path := a.index.Path(session); path != "" {
			next, err := a.mirrorOnce(session, path, off)
			if err != nil {
				a.log.Warn("mirror", "session", session, "err", err)
			}
			off = next
		}
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

func (a *Agent) mirrorOnce(session, path string, off int64) (int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return off, err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return off, err
	}
	if st.Size() < off {
		off = 0
	}
	if st.Size() == off {
		return off, nil
	}
	if _, err := f.Seek(off, io.SeekStart); err != nil {
		return off, err
	}
	r := bufio.NewReaderSize(f, 1<<20)
	var lines []string
	size := 0
	flush := func() {
		a.send(&v1.Frame{Body: &v1.Frame_RawEvents{RawEvents: &v1.RawEvents{
			Session: session, Source: v1.RawEvents_SOURCE_TRANSCRIPT, Lines: lines, EndOffset: off,
		}}})
		lines, size = nil, 0
	}
	for {
		line, err := r.ReadBytes('\n')
		if err != nil {
			break
		}
		off += int64(len(line))
		var head struct {
			Type string `json:"type"`
		}
		if json.Unmarshal(line, &head) != nil || !mirrorTypes[head.Type] {
			continue
		}
		lines = append(lines, strings.TrimRight(string(line), "\r\n"))
		size += len(line)
		if size >= mirrorChunk {
			flush()
		}
	}
	flush()
	return off, nil
}

func claudeVersion(bin string) string {
	out, err := exec.Command(bin, "--version").Output()
	if err != nil {
		return ""
	}
	v, _, _ := strings.Cut(strings.TrimSpace(string(out)), " ")
	return v
}
