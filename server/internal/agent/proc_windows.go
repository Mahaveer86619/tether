package agent

import (
	"os/exec"
	"syscall"
)

// The Windows agent runs without a console; console programs it starts
// would otherwise each open a window of their own.
func hideWindow(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000} // CREATE_NO_WINDOW
}

func processAlive(pid uint32) bool {
	const queryLimitedInformation, stillActive = 0x1000, 259
	h, err := syscall.OpenProcess(queryLimitedInformation, false, pid)
	if err != nil {
		// Access denied still means the process exists.
		return err == syscall.ERROR_ACCESS_DENIED
	}
	defer syscall.CloseHandle(h)
	var code uint32
	return syscall.GetExitCodeProcess(h, &code) != nil || code == stillActive
}
