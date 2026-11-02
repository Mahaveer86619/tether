package agent

import (
	"errors"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Switching a live session's permission mode. A headless run takes a
// control request; an interactive one cycles modes with Shift+Tab, so the
// agent presses it until the mode line at the bottom of the screen shows
// the one asked for. See docs/hosting.md#permission-modes.

var modeLines = []struct {
	re   *regexp.Regexp
	mode string
}{
	{regexp.MustCompile(`(?i)accept edits on`), "acceptEdits"},
	{regexp.MustCompile(`(?i)plan mode on`), "plan"},
	{regexp.MustCompile(`(?i)auto[- ]mode on`), "auto"},
	{regexp.MustCompile(`(?i)bypass permissions on`), "bypassPermissions"},
}

const interruptWait = 6 * time.Second

var workingLine = regexp.MustCompile(`(?i)esc to interrupt`)

// working reports whether the screen shows Claude Code mid-turn ("esc to
// interrupt" by its spinner).
func working(screen string) bool {
	lines := strings.Split(strings.TrimRight(screen, "\n "), "\n")
	if len(lines) > 8 {
		lines = lines[len(lines)-8:]
	}
	return workingLine.MatchString(strings.Join(lines, "\n"))
}

// screenMode reads the mode off the bottom of a screen; Claude Code shows
// nothing there in the default mode.
func screenMode(screen string) string {
	lines := strings.Split(strings.TrimRight(screen, "\n "), "\n")
	if len(lines) > 6 {
		lines = lines[len(lines)-6:]
	}
	tail := strings.Join(lines, "\n")
	for _, m := range modeLines {
		if m.re.MatchString(tail) {
			return m.mode
		}
	}
	return "default"
}

func (a *Agent) setMode(m *v1.AgentCommand_SetMode) {
	err := a.switchMode(m.Session, m.Mode)
	res := &v1.ModeResult{Session: m.Session, Mode: m.Mode}
	if err != nil {
		res.Error = err.Error()
		a.log.Warn("set permission mode", "session", m.Session, "mode", m.Mode, "err", err)
	}
	a.send(&v1.Frame{Body: &v1.Frame_ModeResult{ModeResult: res}})
}

func (a *Agent) switchMode(session, mode string) error {
	if r := a.run(session); r != nil {
		return r.setMode(mode)
	}
	t, err := a.screenTarget(session)
	if err != nil {
		// No live process: the next resume starts in the mode the hub keeps.
		return nil
	}
	for range 6 {
		screen, err := a.readScreen(t)
		if err != nil {
			return err
		}
		if parseDialog(screen) != nil {
			return errors.New("a dialog is open; answer it first")
		}
		if screenMode(screen) == mode {
			return nil
		}
		if err := a.pressKeys(t, []string{"BTab"}, ""); err != nil {
			return err
		}
		time.Sleep(400 * time.Millisecond)
	}
	return errors.New("Shift+Tab didn't reach that mode; it may be turned off in Claude Code's settings")
}

func (r *run) setMode(mode string) error {
	return r.write(map[string]any{
		"type":       "control_request",
		"request_id": uuid.NewString(),
		"request":    map[string]any{"subtype": "set_permission_mode", "mode": mode},
	})
}
