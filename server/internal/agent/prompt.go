package agent

import (
	"context"
	"errors"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/console"
)

// Claude Code shows some dialogs only on its screen: feedback surveys,
// pickers, menus that no hook reports. Unanswered, they leave a session
// stuck with nothing in the app to act on. The agent reads the screens of
// the interactive sessions it can see (tmux panes, and Windows consoles it
// can attach to), turns a dialog into a prompt card, and offers the raw
// screen and key presses for anything it can't parse. See
// docs/hosting.md#dialogs-on-screen.

const (
	screenEvery = 2 * time.Second
)

type dialog = console.Dialog

func parseDialog(screen string) *console.Dialog {
	return console.ParseDialog(screen)
}

// screenTarget is how to read and drive one interactive session.
type screenTarget struct {
	session string
	pane    string // tmux
	pid     uint32 // a Windows console
}

func (a *Agent) screenTarget(session string) (screenTarget, error) {
	if pane := a.pane(session); pane != "" {
		return screenTarget{session: session, pane: pane}, nil
	}
	if hs, live := a.hookState(session); live && hs.pid != 0 && terminalInputSupported {
		return screenTarget{session: session, pid: hs.pid}, nil
	}
	if a.run(session) != nil {
		return screenTarget{}, errors.New("a headless run has no terminal; its questions come as cards")
	}
	return screenTarget{}, errors.New("no terminal Tether can reach for this session")
}

func (a *Agent) readScreen(t screenTarget) (string, error) {
	if t.pane != "" {
		return a.tmux.cmd("capture-pane", "-p", "-t", t.pane)
	}
	return readConsole(t.pid)
}

// pressKeys presses keys (see v1.SendKeys) and then types text.
func (a *Agent) pressKeys(t screenTarget, keys []string, text string) error {
	if t.pane != "" {
		for _, k := range keys {
			name, ok := tmuxKeys[k]
			if !ok {
				if utf8.RuneCountInString(k) != 1 {
					return errors.New("unknown key " + k)
				}
				name = k
			}
			if err := a.tmux.keys(t.pane, name); err != nil {
				return err
			}
			time.Sleep(80 * time.Millisecond)
		}
		if text != "" {
			_, err := a.tmux.cmd("send-keys", "-t", t.pane, "-l", "--", text)
			return err
		}
		return nil
	}
	return pressConsoleKeys(t.pid, keys, text)
}

var tmuxKeys = map[string]string{
	"Enter": "Enter", "Escape": "Escape", "Up": "Up", "Down": "Down", "Left": "Left", "Right": "Right",
	"Tab": "Tab", "BTab": "BTab", "Space": "Space", "Backspace": "BSpace",
}

// capture answers CaptureScreen.
func (a *Agent) capture(session string) {
	snap := &v1.ScreenSnapshot{Session: session, CapturedMs: time.Now().UnixMilli()}
	t, err := a.screenTarget(session)
	if err == nil {
		snap.Text, err = a.readScreen(t)
	}
	if err != nil {
		snap.Error = err.Error()
	}
	a.send(&v1.Frame{Body: &v1.Frame_ScreenSnapshot{ScreenSnapshot: snap}})
}

// sendKeys answers SendKeys, then sends the screen so the app sees the effect.
func (a *Agent) sendKeys(k *v1.SendKeys) {
	t, err := a.screenTarget(k.Session)
	if err == nil {
		err = a.pressKeys(t, k.Keys, k.Text)
	}
	if err != nil {
		a.log.Warn("send keys", "session", k.Session, "err", err)
		a.send(&v1.Frame{Body: &v1.Frame_ScreenSnapshot{ScreenSnapshot: &v1.ScreenSnapshot{
			Session: k.Session, Error: "Couldn't press the keys: " + err.Error(), CapturedMs: time.Now().UnixMilli(),
		}}})
		return
	}
	time.Sleep(400 * time.Millisecond)
	a.capture(k.Session)
}

// screenPrompt is a dialog shown as a card, until it leaves the screen.
type screenPrompt struct {
	id, sig string
	target  screenTarget
}

// watchScreens looks for on-screen dialogs in every interactive session
// that isn't idle.
func (a *Agent) watchScreens(ctx context.Context) {
	t := time.NewTicker(screenEvery)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
		for _, target := range a.watchedScreens() {
			screen, err := a.readScreen(target)
			if err != nil {
				continue
			}
			a.noteScreen(target, screen)
		}
	}
}

func (a *Agent) watchedScreens() []screenTarget {
	a.mu.Lock()
	defer a.mu.Unlock()
	var out []screenTarget
	for session, pane := range a.panes {
		out = append(out, screenTarget{session: session, pane: pane})
	}
	if terminalInputSupported {
		for session, hs := range a.hooks {
			if _, tmux := a.panes[session]; tmux || hs.pid == 0 || hs.closed || time.Since(hs.last) > hookStale ||
				hs.state == v1.SessionState_SESSION_STATE_IDLE {
				continue
			}
			out = append(out, screenTarget{session: session, pid: hs.pid})
		}
	}
	return out
}

// noteScreen raises, replaces or withdraws a session's prompt card.
func (a *Agent) noteScreen(t screenTarget, screen string) {
	d := parseDialog(screen)
	a.mu.Lock()
	cur := a.prompts[t.session]
	// A hook already asked about this (a tool permission), or the startup
	// trust watcher owns the folder dialog.
	covered := a.hookPending(t.session) || (t.pane != "" && a.trustPending(t.pane))
	a.mu.Unlock()
	if d != nil && covered {
		d = nil
	}
	if d != nil && awaitingTrust(screen) && t.pane != "" && a.trustWatching(t.session) {
		d = nil
	}
	switch {
	case d == nil && cur != nil:
		a.dropPrompt(t.session, "screen")
	case d != nil && (cur == nil || cur.sig != d.Signature()):
		if cur != nil {
			a.dropPrompt(t.session, "screen")
		}
		p := &screenPrompt{id: uuid.NewString(), sig: d.Signature(), target: t}
		a.mu.Lock()
		a.prompts[t.session] = p
		a.mu.Unlock()
		a.send(&v1.Frame{Body: &v1.Frame_ApprovalRequested{ApprovalRequested: &v1.ApprovalRequest{
			ApprovalId: p.id, Session: t.session, Kind: v1.ApprovalRequest_KIND_PROMPT, ToolName: "Claude Code prompt",
			Description: d.Title, Options: d.Options, Selected: int32(d.Selected), Screen: console.LastLines(screen, 40),
			InputJson: "{}",
		}}})
		a.setHookState(t.session, v1.SessionState_SESSION_STATE_AWAITING_APPROVAL)
	}
}

func (a *Agent) dropPrompt(session, by string) {
	a.mu.Lock()
	p := a.prompts[session]
	delete(a.prompts, session)
	a.mu.Unlock()
	if p != nil {
		a.send(&v1.Frame{Body: &v1.Frame_ApprovalResolved{ApprovalResolved: &v1.ApprovalResolved{ApprovalId: p.id, Session: session, By: by}}})
	}
}

// hookPending: caller holds a.mu.
func (a *Agent) hookPending(session string) bool {
	for _, ha := range a.hookApprovals {
		if ha.session == session {
			return true
		}
	}
	return false
}

// trustPending: caller holds a.mu.
func (a *Agent) trustPending(pane string) bool {
	for _, p := range a.trust {
		if p == pane {
			return true
		}
	}
	return false
}

func (a *Agent) trustWatching(session string) bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	return time.Now().Before(a.trustUntil[session])
}

// answerPrompt drives a prompt card's dialog: Esc to dismiss, the survey's
// key, or the cursor moved to the option and Enter, checking the screen
// between key presses since the TUI drops keys while redrawing.
func (a *Agent) answerPrompt(id string, d *v1.ApprovalDecision) bool {
	a.mu.Lock()
	var p *screenPrompt
	for session, sp := range a.prompts {
		if sp.id == id {
			p = sp
			delete(a.prompts, session)
		}
	}
	a.mu.Unlock()
	if p == nil {
		return false
	}
	go func() {
		if err := a.driveDialog(p.target, d); err != nil {
			a.log.Warn("answer prompt", "session", p.target.session, "err", err)
		}
		a.setHookState(p.target.session, v1.SessionState_SESSION_STATE_RUNNING)
	}()
	return true
}

func (a *Agent) driveDialog(t screenTarget, d *v1.ApprovalDecision) error {
	if d.Decision != v1.Decision_DECISION_ALLOW {
		return a.pressKeys(t, []string{"Escape"}, "")
	}
	for range 30 {
		screen, err := a.readScreen(t)
		if err != nil {
			return err
		}
		cur := parseDialog(screen)
		if cur == nil {
			return nil
		}
		target := int(d.Option) - 1
		if target < 0 {
			target = cur.Selected
		}
		if target < 0 || target >= len(cur.Options) {
			return errors.New("the option isn't on the screen any more")
		}
		var key string
		switch {
		case len(cur.Keys) > 0:
			key = cur.Keys[target]
		case cur.Selected < target:
			key = "Down"
		case cur.Selected > target:
			key = "Up"
		default:
			key = "Enter"
		}
		if err := a.pressKeys(t, []string{key}, ""); err != nil {
			return err
		}
		if key == "Enter" || len(cur.Keys) > 0 {
			return nil
		}
		time.Sleep(250 * time.Millisecond)
	}
	return errors.New("the dialog didn't respond to the keys")
}
