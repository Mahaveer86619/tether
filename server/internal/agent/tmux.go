package agent

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

const (
	tmuxSession = "tether"
	// Pane option holding the Claude Code session id, so windows can be
	// matched to sessions again after the agent restarts.
	tmuxSessionOpt = "@tether_session"
	trustWatch     = 20 * time.Second
)

// tmuxHost runs interactive Claude Code sessions in windows of one tmux
// session, so they can be attached to from any terminal.
type tmuxHost struct {
	bin string
}

func newTmuxHost() *tmuxHost {
	bin, err := exec.LookPath("tmux")
	if err != nil {
		return nil
	}
	return &tmuxHost{bin: bin}
}

func (t *tmuxHost) cmd(args ...string) (string, error) {
	var stderr bytes.Buffer
	c := exec.Command(t.bin, args...)
	c.Stderr = &stderr
	out, err := c.Output()
	if err != nil {
		return "", fmt.Errorf("tmux %s: %v: %s", args[0], err, strings.TrimSpace(stderr.String()))
	}
	return strings.TrimSpace(string(out)), nil
}

func windowName(session string) string { return "claude-" + session[:8] }

func attachCommand(session string) string {
	return fmt.Sprintf("tmux attach -t %s:%s", tmuxSession, windowName(session))
}

// start opens a new window running claude with args and returns its pane id.
func (t *tmuxHost) start(session, cwd string, claude []string) (string, error) {
	base := []string{"-d", "-P", "-F", "#{pane_id}", "-n", windowName(session), "-c", cwd}
	var args []string
	if _, err := t.cmd("has-session", "-t", "="+tmuxSession); err != nil {
		args = append([]string{"new-session", "-s", tmuxSession, "-x", "200", "-y", "50"}, base...)
	} else {
		args = append([]string{"new-window", "-t", "=" + tmuxSession + ":"}, base...)
	}
	args = append(args, "--")
	args = append(args, claude...)
	pane, err := t.cmd(args...)
	if err != nil {
		return "", err
	}
	if _, err := t.cmd("set-option", "-p", "-t", pane, tmuxSessionOpt, session); err != nil {
		return pane, err
	}
	return pane, nil
}

// panes maps session ids to the panes running them.
func (t *tmuxHost) panes() map[string]string {
	out, err := t.cmd("list-panes", "-s", "-t", "="+tmuxSession, "-F", "#{pane_id}\t#{"+tmuxSessionOpt+"}\t#{pane_dead}")
	if err != nil {
		return nil
	}
	m := map[string]string{}
	for _, line := range strings.Split(out, "\n") {
		f := strings.Split(line, "\t")
		if len(f) == 3 && f[1] != "" && f[2] != "1" {
			m[f[1]] = f[0]
		}
	}
	return m
}

// paste types text into the pane as one bracketed paste, then submits it,
// so multi-line messages arrive whole.
func (t *tmuxHost) paste(pane, text string) error {
	if _, err := t.cmd("set-buffer", "-b", "tether", "--", text); err != nil {
		return err
	}
	if _, err := t.cmd("paste-buffer", "-p", "-d", "-b", "tether", "-t", pane); err != nil {
		return err
	}
	// The TUI handles the paste asynchronously; Enter sent too early is lost.
	time.Sleep(300 * time.Millisecond)
	_, err := t.cmd("send-keys", "-t", pane, "Enter")
	return err
}

func (t *tmuxHost) keys(pane string, keys ...string) error {
	_, err := t.cmd(append([]string{"send-keys", "-t", pane}, keys...)...)
	return err
}

func (t *tmuxHost) capture(pane string) string {
	out, _ := t.cmd("capture-pane", "-p", "-t", pane)
	return out
}

// awaitingTrust reports whether the pane shows Claude Code's folder-trust
// dialog, which interactive sessions show for folders not opened before.
func awaitingTrust(screen string) bool {
	return strings.Contains(screen, "trust this folder")
}
