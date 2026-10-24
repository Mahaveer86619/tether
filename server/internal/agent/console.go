package agent

import "github.com/Mahaveer86619/tether/server/internal/console"

const terminalInputSupported = console.TerminalInputSupported

func typeIntoConsole(pid uint32, text string) error {
	return console.Type(pid, text)
}

func pressEscape(pid uint32) error {
	return console.PressEscape(pid)
}

func pressConsoleKeys(pid uint32, keys []string, text string) error {
	return console.PressKeys(pid, keys, text)
}

func readConsole(pid uint32) (string, error) {
	return console.Read(pid)
}

func pidOfLocalPeer(remoteAddr string, serverPort int) (uint32, error) {
	return console.PIDOfLocalPeer(remoteAddr, serverPort)
}
