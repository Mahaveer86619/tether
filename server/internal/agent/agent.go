// Package agent runs on each machine with Claude Code. It indexes local
// sessions, hosts sessions for the hub (in tmux where available, headless
// otherwise), tracks every session's state through Claude Code hooks, and
// mirrors transcripts.
package agent

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

const (
	scanInterval   = 3 * time.Second
	tailInterval   = 500 * time.Millisecond
	idleRunTimeout = 15 * time.Minute
	// Without hooks, a transcript written this recently by something other
	// than the agent is treated as an open terminal session.
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
	// Host is "auto", "tmux" or "headless".
	Host string
	// HookAddr is where the hook receiver listens; empty disables it.
	HookAddr string
	// SettingsPath is the Claude Code settings file hooks are installed into;
	// empty leaves settings alone.
	SettingsPath string
	Version      string
	Log          *slog.Logger
}

type Agent struct {
	cfg   Config
	log   *slog.Logger
	index *Index
	tmux  *tmuxHost

	mu            sync.Mutex
	conn          *wire.Conn
	runs          map[string]*run
	panes         map[string]string
	trust         map[string]string
	hooks         map[string]*hookSession
	hookApprovals map[string]*hookApproval
	ended         map[string]*v1.SessionInfo
	mirrors       map[string]context.CancelFunc
	reported      map[string]*v1.SessionInfo
	claudeV       string
}

func New(cfg Config) (*Agent, error) {
	a := &Agent{
		cfg:           cfg,
		log:           cfg.Log,
		index:         NewIndex(cfg.ProjectsDir),
		runs:          map[string]*run{},
		panes:         map[string]string{},
		trust:         map[string]string{},
		hooks:         map[string]*hookSession{},
		hookApprovals: map[string]*hookApproval{},
		ended:         map[string]*v1.SessionInfo{},
		mirrors:       map[string]context.CancelFunc{},
		reported:      map[string]*v1.SessionInfo{},
	}
	switch cfg.Host {
	case "auto", "":
		a.tmux = newTmuxHost()
	case "tmux":
		if a.tmux = newTmuxHost(); a.tmux == nil {
			return nil, errors.New("tmux not found on PATH")
		}
	case "headless":
	default:
		return nil, errors.New("host must be auto, tmux or headless")
	}
	return a, nil
}

// Run connects to the hub and keeps reconnecting until ctx ends.
func (a *Agent) Run(ctx context.Context) error {
	a.claudeV = claudeVersion(a.cfg.Claude)
	if a.cfg.HookAddr != "" {
		if err := a.serveHooks(a.cfg.HookAddr); err != nil {
			return err
		}
		if a.cfg.SettingsPath != "" {
			if err := InstallHooks(a.cfg.SettingsPath, "http://"+a.cfg.HookAddr+hookPath); err != nil {
				return err
			}
			a.log.Info("hooks installed", "settings", a.cfg.SettingsPath)
		}
	}
	host := "headless"
	if a.tmux != nil {
		host = "tmux"
		a.refreshPanes()
	}
	if err := a.index.Scan(); err != nil {
		a.log.Warn("initial scan", "err", err)
	}
	a.log.Info("indexed sessions", "count", len(a.index.IDs()), "dir", a.cfg.ProjectsDir, "host", host)
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
	running := int32(len(a.runs) + len(a.panes))
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
			a.interrupt(op.Interrupt.Session)
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
		a.decide(b.ApprovalDecision)
	}
}

func (a *Agent) decide(d *v1.ApprovalDecision) {
	a.mu.Lock()
	pane, isTrust := a.trust[d.ApprovalId]
	delete(a.trust, d.ApprovalId)
	runs := make([]*run, 0, len(a.runs))
	for _, r := range a.runs {
		runs = append(runs, r)
	}
	a.mu.Unlock()

	if isTrust {
		go a.answerTrust(d.ApprovalId, pane, d.Decision == v1.Decision_DECISION_ALLOW)
		return
	}
	if a.answerHook(d) {
		return
	}
	for _, r := range runs {
		if r.answer(d.ApprovalId, d.Decision == v1.Decision_DECISION_ALLOW, d.Message) {
			return
		}
	}
}

func (a *Agent) run(session string) *run {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.runs[session]
}

func (a *Agent) pane(session string) string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.panes[session]
}

func (a *Agent) start(o startOpts) {
	if a.pane(o.session) != "" || a.run(o.session) != nil {
		a.sendInput(o.session, o.prompt)
		return
	}
	if o.resume != "" && o.cwd == "" {
		o.cwd = a.index.Cwd(o.resume)
	}
	if o.resume != "" && !o.fork && a.openElsewhere(o.resume) {
		a.fail(o.session, errTerminalActive)
		return
	}
	if o.cwd == "" {
		o.cwd, _ = os.UserHomeDir()
	}
	if st, err := os.Stat(o.cwd); err != nil || !st.IsDir() {
		a.fail(o.session, errors.New("working directory "+o.cwd+" does not exist"))
		return
	}
	if a.tmux != nil {
		a.startTmux(o)
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

func (a *Agent) startTmux(o startOpts) {
	args := []string{a.cfg.Claude}
	args = append(args, sessionArgs(o)...)
	if o.prompt != "" {
		args = append(args, o.prompt)
	}
	pane, err := a.tmux.start(o.session, o.cwd, args)
	if err != nil {
		a.fail(o.session, err)
		return
	}
	a.log.Info("tmux session started", "session", o.session, "pane", pane, "cwd", o.cwd, "resume", o.resume, "fork", o.fork)
	a.mu.Lock()
	a.panes[o.session] = pane
	delete(a.ended, o.session)
	a.hooks[o.session] = &hookSession{state: v1.SessionState_SESSION_STATE_RUNNING, last: time.Now()}
	a.mu.Unlock()
	a.sendStatus()
	a.report(o.session)
	go a.watchTrust(o.session, o.cwd, pane)
}

// sessionArgs are the Claude Code flags shared by tmux and headless runs.
func sessionArgs(o startOpts) []string {
	var args []string
	switch {
	case o.resume != "" && o.fork:
		args = append(args, "--resume", o.resume, "--fork-session", "--session-id", o.session)
	case o.resume != "":
		args = append(args, "--resume", o.resume)
	default:
		args = append(args, "--session-id", o.session)
	}
	if o.model != "" {
		args = append(args, "--model", o.model)
	}
	if o.permissionMode != "" {
		args = append(args, "--permission-mode", o.permissionMode)
	}
	if o.name != "" {
		args = append(args, "--name", o.name)
	}
	return args
}

// watchTrust turns Claude Code's folder-trust dialog into an approval in the
// app, since nothing else would answer it in a detached window.
func (a *Agent) watchTrust(session, cwd, pane string) {
	deadline := time.Now().Add(trustWatch)
	for time.Now().Before(deadline) {
		time.Sleep(500 * time.Millisecond)
		if !awaitingTrust(a.tmux.capture(pane)) {
			continue
		}
		id := uuid.NewString()
		a.mu.Lock()
		a.trust[id] = pane
		a.mu.Unlock()
		input, _ := json.Marshal(map[string]string{"path": cwd})
		a.send(&v1.Frame{Body: &v1.Frame_ApprovalRequested{ApprovalRequested: &v1.ApprovalRequest{
			ApprovalId: id, Session: session, Kind: v1.ApprovalRequest_KIND_FOLDER_TRUST, ToolName: "Trust folder",
			InputJson: string(input), Description: "Trust " + cwd + " so Claude Code can read, edit and run files there?",
		}}})
		a.setHookState(session, v1.SessionState_SESSION_STATE_AWAITING_APPROVAL)
		return
	}
}

// answerTrust drives the trust dialog by looking at the screen: keys sent
// while the TUI is still starting up are dropped, so it moves the selection,
// confirms, and checks again until the dialog is gone.
func (a *Agent) answerTrust(id, pane string, allow bool) {
	for range 20 {
		screen := a.tmux.capture(pane)
		if !awaitingTrust(screen) {
			a.log.Info("trust dialog answered", "approval", id, "allow", allow)
			return
		}
		key := "Enter"
		switch yes := trustSelected(screen); {
		case allow && !yes:
			key = "Down"
		case !allow && yes:
			key = "Up"
		}
		if err := a.tmux.keys(pane, key); err != nil {
			a.log.Warn("answer trust dialog", "err", err)
			return
		}
		time.Sleep(500 * time.Millisecond)
	}
	a.log.Warn("trust dialog did not close", "approval", id)
}

func (a *Agent) sendInput(session, text string) {
	if pane := a.pane(session); pane != "" {
		if err := a.tmux.paste(pane, text); err != nil {
			a.fail(session, err)
		}
		return
	}
	if r := a.run(session); r != nil {
		if err := r.send(text); err != nil {
			a.fail(session, err)
		}
		return
	}
	a.start(startOpts{session: session, resume: session, prompt: text})
}

func (a *Agent) interrupt(session string) {
	var err error
	if pane := a.pane(session); pane != "" {
		err = a.tmux.keys(pane, "Escape")
	} else if r := a.run(session); r != nil {
		err = r.interrupt()
	}
	if err != nil {
		a.log.Warn("interrupt", "session", session, "err", err)
	}
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
	a.log.Warn("session failed", "session", session, "err", err)
	a.mu.Lock()
	a.ended[session] = &v1.SessionInfo{Id: session, State: v1.SessionState_SESSION_STATE_ERROR, Error: err.Error(), UpdatedMs: time.Now().UnixMilli()}
	a.mu.Unlock()
	a.report(session)
}

// openElsewhere reports whether a live process the agent doesn't control
// is using the session.
func (a *Agent) openElsewhere(session string) bool {
	info := a.info(session)
	return info != nil && (info.State == v1.SessionState_SESSION_STATE_TERMINAL_ACTIVE ||
		info.Host == v1.SessionHost_SESSION_HOST_TERMINAL && info.State != v1.SessionState_SESSION_STATE_IDLE)
}

func (a *Agent) sendStatus() {
	a.send(&v1.Frame{Body: &v1.Frame_NodeStatus{NodeStatus: a.status()}})
}

// info is the agent's current view of one session.
func (a *Agent) info(session string) *v1.SessionInfo {
	if session == "" {
		return nil
	}
	info := a.index.Info(session)
	a.mu.Lock()
	r := a.runs[session]
	pane := a.panes[session]
	ended := a.ended[session]
	a.mu.Unlock()
	hs, hookLive := a.hookState(session)
	if info == nil {
		if r == nil && pane == "" && ended == nil && !hookLive {
			return nil
		}
		info = &v1.SessionInfo{Id: session}
	}
	info.Node = a.cfg.Node
	info.Host = v1.SessionHost_SESSION_HOST_NONE
	mod, _ := a.index.Modified(session)
	// Writes from our own finished run are not a terminal.
	ownWrite := ended != nil && !mod.After(time.UnixMilli(ended.UpdatedMs).Add(5*time.Second))

	switch {
	case r != nil:
		info.Host = v1.SessionHost_SESSION_HOST_HEADLESS
		info.State, info.Error = r.State()
	case pane != "":
		info.Host = v1.SessionHost_SESSION_HOST_TMUX
		info.AttachCommand = attachCommand(session)
		info.State = v1.SessionState_SESSION_STATE_READY
		if hs != nil {
			info.State, info.Error = hs.state, hs.errText
		}
	case hookLive:
		info.Host = v1.SessionHost_SESSION_HOST_TERMINAL
		info.State, info.Error = hs.state, hs.errText
	case hs == nil && !ownWrite && time.Since(mod) < terminalWindow:
		info.Host = v1.SessionHost_SESSION_HOST_TERMINAL
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
	for id := range a.panes {
		ids = append(ids, id)
	}
	for id := range a.hooks {
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
			if a.tmux != nil && a.refreshPanes() {
				a.sendStatus()
			}
			a.publish(false)
			a.closeIdleRuns()
		}
	}
}

// refreshPanes re-reads which tmux windows are alive and reports whether
// that changed.
func (a *Agent) refreshPanes() bool {
	panes := a.tmux.panes()
	if panes == nil {
		panes = map[string]string{}
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	changed := len(panes) != len(a.panes)
	for s, p := range panes {
		if a.panes[s] != p {
			changed = true
		}
	}
	for s := range a.panes {
		if _, ok := panes[s]; !ok {
			// The window closed; record when so its last transcript writes
			// aren't mistaken for a terminal.
			a.ended[s] = &v1.SessionInfo{Id: s, State: v1.SessionState_SESSION_STATE_IDLE, UpdatedMs: time.Now().UnixMilli()}
			if hs := a.hooks[s]; hs != nil {
				hs.closed = true
			}
		}
	}
	a.panes = panes
	return changed
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

// shutdown ends headless runs. tmux sessions are left running on purpose:
// they belong to the user and survive agent restarts.
func (a *Agent) shutdown() {
	a.mu.Lock()
	defer a.mu.Unlock()
	for _, r := range a.runs {
		r.closeInput()
	}
}

func claudeVersion(bin string) string {
	cmd := exec.Command(bin, "--version")
	hideWindow(cmd)
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	v, _, _ := strings.Cut(strings.TrimSpace(string(out)), " ")
	return v
}
