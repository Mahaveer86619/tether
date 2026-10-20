// Package agent runs on each machine with Claude Code. It indexes local
// sessions, hosts sessions for the hub (in tmux where available, headless
// otherwise), tracks every session's state through Claude Code hooks, and
// mirrors transcripts.
package agent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
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
	stopGrace      = 5 * time.Second
)

type Config struct {
	HubURL string
	// SHA-256 of the hub's self-signed certificate, if it uses one.
	HubFingerprint string
	Token          string
	Node           string
	Claude         string
	ProjectsDir    string
	// Host is "auto", "tmux" or "headless".
	Host string
	// HookAddr is where the hook receiver listens; empty disables it.
	HookAddr string
	// SettingsPath is the Claude Code settings file hooks are installed into;
	// empty leaves settings alone.
	SettingsPath string
	// ScratchDir holds one folder per hub session.
	ScratchDir string
	// MCP registers the hub's MCP server with Claude Code.
	MCP     bool
	Version string
	Log     *slog.Logger
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
	trustUntil    map[string]time.Time     // session -> while watchTrust owns its folder dialog
	prompts       map[string]*screenPrompt // session -> the dialog shown as a card
	hooks         map[string]*hookSession
	hookApprovals map[string]*hookApproval
	uploaded      map[string]bool    // files already sent to the artifact store
	hashes        map[hashKey]string // file hashes for snapshots, while unchanged
	snapMu        sync.Mutex         // one snapshot at a time
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
		trustUntil:    map[string]time.Time{},
		prompts:       map[string]*screenPrompt{},
		hooks:         map[string]*hookSession{},
		hookApprovals: map[string]*hookApproval{},
		uploaded:      map[string]bool{},
		hashes:        map[hashKey]string{},
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
	if _, err := a.index.Scan(); err != nil {
		a.log.Warn("initial scan", "err", err)
	}
	a.log.Info("indexed sessions", "count", len(a.index.IDs()), "dir", a.cfg.ProjectsDir, "host", host)
	go a.scanLoop(ctx)
	go a.watchScreens(ctx)
	go a.planLoop(ctx)
	if a.cfg.MCP {
		go a.registerMCP()
	}

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
	conn, err := wire.Dial(dctx, a.cfg.HubURL, a.cfg.HubFingerprint)
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
	go a.checkPlan(ctx)

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
				permissionMode: s.PermissionMode, name: s.Name, resume: s.Resume, fork: s.Fork, createCwd: s.CreateCwd, attachments: s.Attachments,
				scratch: s.Scratch, restoreTranscript: s.RestoreTranscript, restoreCodebase: s.RestoreCodebase, restoreSnapshot: s.RestoreSnapshot})
		case *v1.AgentCommand_Snapshot:
			go a.snapshotCodebase(op.Snapshot.Codebase, op.Snapshot.Session)
		case *v1.AgentCommand_Scan:
			go a.scanCodebases(op.Scan.Roots)
		case *v1.AgentCommand_Fetch:
			go a.fetchAttachment(op.Fetch)
		case *v1.AgentCommand_Keys:
			go a.sendKeys(op.Keys)
		case *v1.AgentCommand_Capture:
			go a.capture(op.Capture.Session)
		case *v1.AgentCommand_SetMode_:
			go a.setMode(op.SetMode)
		case *v1.AgentCommand_Send:
			a.sendInput(op.Send.Session, op.Send.Text, op.Send.Attachments, op.Send.PermissionMode)
		case *v1.AgentCommand_Interrupt_:
			a.interrupt(op.Interrupt.Session)
		case *v1.AgentCommand_Stop_:
			a.stop(op.Stop.Session)
		case *v1.AgentCommand_Forget_:
			a.forgetScratch(op.Forget.Session)
		case *v1.AgentCommand_UploadTranscript_:
			go a.uploadTranscript(op.UploadTranscript.Session)
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
	if a.answerPrompt(d.ApprovalId, d) {
		return
	}
	if a.answerHook(d) {
		return
	}
	for _, r := range runs {
		if r.answer(d.ApprovalId, d.Decision == v1.Decision_DECISION_ALLOW, d.Message, d.Answers) {
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
		a.sendInput(o.session, o.prompt, o.attachments, o.permissionMode)
		return
	}
	if o.resume != "" && o.cwd == "" {
		o.cwd = a.index.Cwd(o.resume)
	}
	if o.resume != "" && !o.fork && a.openElsewhere(o.resume) {
		a.fail(o.session, errTerminalActive)
		return
	}
	if o.scratch {
		o.cwd, o.createCwd = filepath.Join(a.cfg.ScratchDir, o.session), true
	}
	if o.restoreCodebase != "" {
		dir := filepath.Join(a.codebasesDir(), o.restoreCodebase)
		if err := a.restoreCodebase(o.restoreCodebase, o.restoreSnapshot, dir); err != nil {
			a.fail(o.session, fmt.Errorf("restore the codebase: %w", err))
			return
		}
		rel, err := within(dir, o.cwd)
		if o.cwd == "" || err != nil {
			rel = dir
		}
		o.cwd, o.createCwd = rel, true
	}
	if o.cwd == "" {
		o.cwd, _ = os.UserHomeDir()
	}
	if o.createCwd {
		if err := os.MkdirAll(o.cwd, 0o755); err != nil {
			a.fail(o.session, fmt.Errorf("create project folder: %w", err))
			return
		}
	}
	if st, err := os.Stat(o.cwd); err != nil || !st.IsDir() {
		a.fail(o.session, errors.New("working directory "+o.cwd+" does not exist"))
		return
	}
	if o.restoreTranscript != "" {
		if err := a.restoreTranscript(o.restoreTranscript, o.cwd, o.resume); err != nil {
			a.fail(o.session, fmt.Errorf("restore the transcript: %w", err))
			return
		}
	}
	if len(o.attachments) > 0 {
		extra, err := a.fetchAttachments(o.cwd, o.attachments)
		if err != nil {
			a.fail(o.session, err)
			return
		}
		o.prompt += extra
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
	a.mu.Lock()
	a.trustUntil[o.session] = time.Now().Add(trustWatch)
	a.mu.Unlock()
	go a.watchTrust(o.session, o.cwd, pane, o.createCwd)
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
func (a *Agent) watchTrust(session, cwd, pane string, created bool) {
	deadline := time.Now().Add(trustWatch)
	for time.Now().Before(deadline) {
		time.Sleep(500 * time.Millisecond)
		if !awaitingTrust(a.tmux.capture(pane)) {
			continue
		}
		id := uuid.NewString()
		// The user just made this folder as a new project from the app;
		// asking whether to trust it again would only be noise.
		if created {
			a.answerTrust(id, pane, true)
			return
		}
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

func (a *Agent) sendInput(session, text string, attachments []*v1.Artifact, mode string) {
	if len(attachments) > 0 {
		cwd := a.index.Cwd(session)
		if cwd == "" {
			cwd, _ = os.UserHomeDir()
		}
		extra, err := a.fetchAttachments(cwd, attachments)
		if err != nil {
			a.fail(session, err)
			return
		}
		text += extra
	}
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
	if hs, live := a.hookState(session); live && hs.pid != 0 {
		a.typeIntoTerminal(session, hs.pid, text)
		return
	}
	a.start(startOpts{session: session, resume: session, prompt: text, permissionMode: mode})
}

// typeIntoTerminal sends a message to a session open in the user's own
// terminal by typing it there. Failures are shown on the session rather
// than marking it errored, since the terminal itself is fine.
func (a *Agent) typeIntoTerminal(session string, pid uint32, text string) {
	err := typeIntoConsole(pid, text)
	a.mu.Lock()
	if hs := a.hooks[session]; hs != nil {
		if err != nil {
			hs.errText = "Couldn't type into the terminal: " + err.Error()
		} else {
			hs.errText = ""
		}
	}
	a.mu.Unlock()
	if err != nil {
		a.log.Warn("type into terminal", "session", session, "pid", pid, "err", err)
	}
	a.report(session)
}

func (a *Agent) interrupt(session string) {
	var err error
	interactive := false
	if pane := a.pane(session); pane != "" {
		err, interactive = a.tmux.keys(pane, "Escape"), true
	} else if r := a.run(session); r != nil {
		err = r.interrupt()
	} else if hs, live := a.hookState(session); live && hs.pid != 0 {
		err, interactive = pressEscape(hs.pid), true
	}
	if err != nil {
		a.log.Warn("interrupt", "session", session, "err", err)
		return
	}
	// Claude Code fires no Stop hook when a turn is interrupted, so nothing
	// else would move an interactive session out of "running".
	if interactive {
		go func() {
			time.Sleep(time.Second)
			a.setHookState(session, v1.SessionState_SESSION_STATE_READY)
		}()
	}
}

// stop ends a session the agent hosts: /exit for tmux, so Claude Code
// saves cleanly, with the window killed if that doesn't work; closing input
// for headless runs, then killing the process if it lingers.
func (a *Agent) stop(session string) {
	if pane := a.pane(session); pane != "" {
		_ = a.tmux.keys(pane, "Escape")
		time.Sleep(300 * time.Millisecond)
		if err := a.tmux.paste(pane, "/exit"); err != nil {
			a.log.Warn("exit tmux session", "session", session, "err", err)
		}
		go func() {
			time.Sleep(stopGrace)
			if a.tmux.panes()[session] == pane {
				_ = a.tmux.killPane(pane)
			}
			if a.refreshPanes() {
				a.sendStatus()
			}
			a.report(session)
		}()
		return
	}
	if r := a.run(session); r != nil {
		r.closeInput()
		go func() {
			select {
			case <-r.done:
			case <-time.After(stopGrace):
				_ = r.cmd.Process.Kill()
			}
		}()
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
		info.Host == v1.SessionHost_SESSION_HOST_TERMINAL && info.State != v1.SessionState_SESSION_STATE_IDLE && !info.TerminalInput)
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
		info.TerminalInput = terminalInputSupported && hs.pid != 0
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
	a.sendUsage(full)
}

// sendUsage passes on token usage read from transcripts: what's new, or all
// of it on a new connection. The hub dedupes by message.
func (a *Agent) sendUsage(all bool) {
	a.mu.Lock()
	connected := a.conn != nil
	a.mu.Unlock()
	if !connected {
		return
	}
	entries := a.index.TakeUsage(all)
	for len(entries) > 0 {
		n := min(len(entries), 500)
		a.send(&v1.Frame{Body: &v1.Frame_UsageReport{UsageReport: &v1.UsageReport{Entries: entries[:n]}}})
		entries = entries[n:]
	}
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
			removed, err := a.index.Scan()
			if err != nil {
				a.log.Warn("scan", "err", err)
			}
			a.forget(append(removed, a.reapTerminals()...))
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

// reapTerminals closes hook-tracked sessions whose Claude Code process has
// exited without a SessionEnd hook, e.g. a terminal window that was closed.
// It returns those whose transcript is already gone.
func (a *Agent) reapTerminals() []string {
	a.mu.Lock()
	var dead []string
	for id, hs := range a.hooks {
		if !hs.closed && hs.pid != 0 && !processAlive(hs.pid) {
			hs.closed = true
			a.ended[id] = &v1.SessionInfo{Id: id, State: v1.SessionState_SESSION_STATE_IDLE, UpdatedMs: time.Now().UnixMilli()}
			dead = append(dead, id)
		}
	}
	a.mu.Unlock()
	var gone []string
	for _, id := range dead {
		a.report(id)
		if a.index.Path(id) == "" {
			gone = append(gone, id)
		}
	}
	return gone
}

// forget tells the hub about deleted transcripts, unless the session is
// still alive here.
func (a *Agent) forget(ids []string) {
	var gone []string
	for _, id := range ids {
		if _, hookLive := a.hookState(id); a.run(id) == nil && a.pane(id) == "" && !hookLive {
			a.mu.Lock()
			delete(a.reported, id)
			delete(a.ended, id)
			a.mu.Unlock()
			gone = append(gone, id)
		}
	}
	if len(gone) > 0 {
		a.send(&v1.Frame{Body: &v1.Frame_SessionIndex{SessionIndex: &v1.SessionIndex{Removed: gone}}})
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
