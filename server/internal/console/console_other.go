//go:build !windows

package console

import "errors"

// TerminalInputSupported is false on non-Windows systems where TIOCSTI is disabled.
const TerminalInputSupported = false

// Type returns an error on non-Windows platforms.
func Type(uint32, string) error {
	return errors.New("typing into a terminal is only supported on Windows")
}

// PressEscape returns an error on non-Windows platforms.
func PressEscape(uint32) error {
	return errors.New("typing into a terminal is only supported on Windows")
}

// PressKeys returns an error on non-Windows platforms.
func PressKeys(uint32, []string, string) error {
	return errors.New("typing into a terminal is only supported on Windows")
}

// Read returns an error on non-Windows platforms.
func Read(uint32) (string, error) {
	return "", errors.New("reading a terminal is only supported on Windows")
}

// PIDOfLocalPeer returns an error on non-Windows platforms.
func PIDOfLocalPeer(string, int) (uint32, error) {
	return 0, errors.New("not supported")
}
