//go:build !windows

package agent

import "errors"

// Other systems don't allow typing into another process's terminal
// (TIOCSTI is disabled on modern Linux); run sessions in tmux instead.
const terminalInputSupported = false

func typeIntoConsole(uint32, string) error {
	return errors.New("typing into a terminal is only supported on Windows")
}

func pressEscape(uint32) error {
	return errors.New("typing into a terminal is only supported on Windows")
}

func pidOfLocalPeer(string, int) (uint32, error) {
	return 0, errors.New("not supported")
}
