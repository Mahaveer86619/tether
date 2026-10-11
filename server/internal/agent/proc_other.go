//go:build !windows

package agent

import (
	"errors"
	"os/exec"
	"syscall"
)

func hideWindow(*exec.Cmd) {}

func processAlive(pid uint32) bool {
	err := syscall.Kill(int(pid), 0)
	return err == nil || errors.Is(err, syscall.EPERM)
}
