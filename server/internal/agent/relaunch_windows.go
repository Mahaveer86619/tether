package agent

import (
	"log/slog"
	"os/exec"
	"syscall"
)

// Relaunch asks Task Scheduler to start the agent again a few seconds
// after this process exits; the task ignores a start while it's running.
func Relaunch(log *slog.Logger) {
	cmd := exec.Command("cmd", "/c", `timeout /t 5 /nobreak >nul & schtasks /Run /TN "Tether Agent"`)
	// DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP | CREATE_NO_WINDOW, so it outlives the agent.
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x00000008 | 0x00000200 | 0x08000000}
	if err := cmd.Start(); err != nil {
		log.Error("schedule the restart", "err", err)
	}
}
