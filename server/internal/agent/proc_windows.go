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
