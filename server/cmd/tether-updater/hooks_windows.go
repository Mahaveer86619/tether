package main

import (
	"errors"
	"os"
	"os/exec"
	"syscall"
	"time"

	"github.com/Mahaveer86619/tether/server/internal/winupdate"
)

const (
	detachedProcess       = 0x00000008
	createNewProcessGroup = 0x00000200
)

func platformHooks() winupdate.Hooks {
	return winupdate.Hooks{
		Wait: func(pid int, d time.Duration) error {
			h, err := syscall.OpenProcess(syscall.SYNCHRONIZE, false, uint32(pid))
			if err != nil {
				return nil // already gone
			}
			defer syscall.CloseHandle(h)
			ev, err := syscall.WaitForSingleObject(h, uint32(d/time.Millisecond))
			if err != nil {
				return err
			}
			if ev == syscall.WAIT_TIMEOUT {
				return errors.New("timed out")
			}
			return nil
		},
		Start: func(exe string, env []string) (func(), error) {
			cmd := exec.Command(exe)
			cmd.Env = append(os.Environ(), env...)
			cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: detachedProcess | createNewProcessGroup}
			if err := cmd.Start(); err != nil {
				return nil, err
			}
			return func() { _ = cmd.Process.Kill() }, nil
		},
	}
}
