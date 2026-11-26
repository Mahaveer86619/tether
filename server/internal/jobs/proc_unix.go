//go:build !windows

package jobs

import (
	"context"
	"errors"
	"os/exec"
	"sync"
	"syscall"
)

// procGroup is a job's process group: the job's process leads it, and its
// children join it unless they make groups of their own.
type procGroup struct {
	pgid    int
	created int64

	mu     sync.Mutex
	closed bool
}

func shellCommand(ctx context.Context, command string) *exec.Cmd {
	return exec.CommandContext(ctx, "/bin/sh", "-c", command)
}

func startGroup(cmd *exec.Cmd) (*procGroup, error) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	return &procGroup{pgid: cmd.Process.Pid}, nil
}

// adoptGroup takes back a group an earlier agent started. A process group
// keeps its leader's id while any member lives, so the id can't be another
// group's meanwhile.
func adoptGroup(pid int, _ int64) (*procGroup, bool) {
	g := &procGroup{pgid: pid}
	if pid <= 1 || !g.alive() {
		return nil, false
	}
	return g, true
}

// signal does nothing once the group is closed: its id may then belong to
// someone else's group.
func (g *procGroup) signal(sig syscall.Signal) error {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.closed {
		return syscall.ESRCH
	}
	return syscall.Kill(-g.pgid, sig)
}

func (g *procGroup) alive() bool {
	err := g.signal(0)
	return err == nil || errors.Is(err, syscall.EPERM)
}

// terminate asks the group to end, and reports whether it could ask.
func (g *procGroup) terminate() bool { return g.signal(syscall.SIGTERM) == nil }

func (g *procGroup) kill() { _ = g.signal(syscall.SIGKILL) }

func (g *procGroup) suspend() error { return g.signal(syscall.SIGSTOP) }

func (g *procGroup) resume() error { return g.signal(syscall.SIGCONT) }

func (g *procGroup) close() {
	g.mu.Lock()
	g.closed = true
	g.mu.Unlock()
}
