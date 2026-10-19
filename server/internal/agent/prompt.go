package agent

import (
	"context"
	"errors"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
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
	// Lines from the bottom a dialog can start in; older lines are history.
	dialogWindow = 24
)

// dialog is a choice read off the screen.
type dialog struct {
	title    string
	options  []string
	keys     []string // inline surveys: the key that picks each option
	selected int      // the cursor's option, or -1
}

func (d *dialog) signature() string {
	return d.title + "\x00" + strings.Join(d.options, "\x00")
}

var (
	boxChars    = "│┃|╭╮╰╯─━┌┐└┘├┤"
	menuLine    = regexp.MustCompile(`^(\s*)([❯›>]?)\s*(?:(\d{1,2})[.)]\s+)?(\S.*?)\s*$`)
	inlineEntry = regexp.MustCompile(`(\d):\s*([^\s\d][^:]*?)(?:\s{2,}|$)`)
	hintLine    = regexp.MustCompile(`(?i)(esc|enter|↑|↓|tab) to `)
	// Option lines may carry marks like ✔ (the current value) after the text.
	marks = regexp.MustCompile(`\s+[✔✓]\s*$`)
)

// cleanLine strips a dialog box's borders.
func cleanLine(l string) string {
	l = strings.TrimRight(l, " ")
	trimmed := strings.Trim(l, " ")
	if trimmed != "" && strings.Trim(trimmed, boxChars+" ") == "" {
		return ""
	}
	for _, c := range []string{"│", "┃"} {
		if strings.HasPrefix(strings.TrimLeft(l, " "), c) {
			l = strings.TrimLeft(l, " ")
			l = strings.TrimPrefix(l, c)
		}
		l = strings.TrimSuffix(strings.TrimRight(l, " "), c)
	}
	return strings.TrimRight(l, " ")
}

// parseDialog finds the dialog at the bottom of a screen, if there is one:
// a vertical menu with a cursor (❯) on one option, or a one-line survey
// like "1: Bad  2: Fine  3: Good  0: Dismiss".
func parseDialog(screen string) *dialog {
	raw := strings.Split(strings.ReplaceAll(screen, "\r", ""), "\n")
	lines := make([]string, len(raw))
	for i, l := range raw {
		lines[i] = cleanLine(l)
	}
	last := len(lines) - 1
	for last >= 0 && strings.TrimSpace(lines[last]) == "" {
		last--
	}
	start := max(0, last-dialogWindow+1)
	if d := parseMenu(lines, start, last); d != nil {
		return d
	}
	return parseInline(lines, start, last)
}

func parseMenu(lines []string, start, last int) *dialog {
	// Find the cursor, then the run of sibling options around it.
	cursor := -1
	for i := last; i >= start; i-- {
		if m := menuLine.FindStringSubmatch(lines[i]); m != nil && m[2] == "❯" {
			cursor = i
			break
		}
	}
	if cursor < 0 {
		return nil
	}
	cm := menuLine.FindStringSubmatch(lines[cursor])
	numbered := cm[3] != ""
	indent := utf8.RuneCountInString(cm[1])
	isOption := func(i int) (string, bool) {
		m := menuLine.FindStringSubmatch(lines[i])
		if m == nil || hintLine.MatchString(lines[i]) {
			return "", false
		}
		if numbered {
			return m[4], m[3] != ""
		}
		// Unnumbered: same column as the cursor line's text.
		col := utf8.RuneCountInString(m[1])
		if m[2] == "" {
			col -= 2
		}
		return m[4], m[2] == "❯" || (col >= indent-1 && col <= indent+1)
	}
	first, end := cursor, cursor
	for i := cursor - 1; i >= start; i-- {
		if strings.TrimSpace(lines[i]) == "" {
			break
		}
		if _, ok := isOption(i); ok {
			first = i
		} else if !numbered {
			break
		}
	}
	for i := cursor + 1; i <= last; i++ {
		if strings.TrimSpace(lines[i]) == "" || hintLine.MatchString(lines[i]) {
			break
		}
		if _, ok := isOption(i); ok {
			end = i
		} else if !numbered {
			break
		}
	}
	d := &dialog{selected: -1}
	for i := first; i <= end; i++ {
		if text, ok := isOption(i); ok {
			if i == cursor {
				d.selected = len(d.options)
			}
			d.options = append(d.options, marks.ReplaceAllString(text, ""))
		}
	}
	if len(d.options) < 2 {
		return nil
	}
	d.title = titleAbove(lines, first, start)
	return d
}

func parseInline(lines []string, start, last int) *dialog {
	for i := last; i >= start; i-- {
		ms := inlineEntry.FindAllStringSubmatch(lines[i], -1)
		if len(ms) < 2 {
			continue
		}
		d := &dialog{selected: -1}
		for _, m := range ms {
			d.keys = append(d.keys, m[1])
			d.options = append(d.options, strings.TrimSpace(m[2]))
		}
		d.title = titleAbove(lines, i, start)
		return d
	}
	return nil
}

// titleAbove is the nearest text above a dialog's options: its question.
func titleAbove(lines []string, first, start int) string {
	for i := first - 1; i >= start; i-- {
		t := strings.TrimSpace(lines[i])
		if t == "" {
			continue
		}
		return strings.TrimLeft(t, "●⏺✻* ")
	}
	return "Claude Code is asking"
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
	case d != nil && (cur == nil || cur.sig != d.signature()):
		if cur != nil {
			a.dropPrompt(t.session, "screen")
		}
		p := &screenPrompt{id: uuid.NewString(), sig: d.signature(), target: t}
		a.mu.Lock()
		a.prompts[t.session] = p
		a.mu.Unlock()
		a.send(&v1.Frame{Body: &v1.Frame_ApprovalRequested{ApprovalRequested: &v1.ApprovalRequest{
			ApprovalId: p.id, Session: t.session, Kind: v1.ApprovalRequest_KIND_PROMPT, ToolName: "Claude Code prompt",
			Description: d.title, Options: d.options, Selected: int32(d.selected), Screen: lastLines(screen, 40),
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
			target = cur.selected
		}
		if target < 0 || target >= len(cur.options) {
			return errors.New("the option isn't on the screen any more")
		}
		var key string
		switch {
		case len(cur.keys) > 0:
			key = cur.keys[target]
		case cur.selected < target:
			key = "Down"
		case cur.selected > target:
			key = "Up"
		default:
			key = "Enter"
		}
		if err := a.pressKeys(t, []string{key}, ""); err != nil {
			return err
		}
		if key == "Enter" || len(cur.keys) > 0 {
			return nil
		}
		time.Sleep(250 * time.Millisecond)
	}
	return errors.New("the dialog didn't respond to the keys")
}

func lastLines(s string, n int) string {
	lines := strings.Split(strings.TrimRight(s, "\n "), "\n")
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	return strings.Join(lines, "\n")
}
