package agent

import (
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode/utf16"
	"unsafe"
)

var (
	kernel32               = syscall.NewLazyDLL("kernel32.dll")
	procFreeConsole        = kernel32.NewProc("FreeConsole")
	procAttachConsole      = kernel32.NewProc("AttachConsole")
	procWriteConsoleInputW = kernel32.NewProc("WriteConsoleInputW")
	procGetConsoleSBInfo   = kernel32.NewProc("GetConsoleScreenBufferInfo")
	procReadConsoleOutChar = kernel32.NewProc("ReadConsoleOutputCharacterW")
	iphlpapi               = syscall.NewLazyDLL("iphlpapi.dll")
	procGetExtendedTcpTbl  = iphlpapi.NewProc("GetExtendedTcpTable")

	// A process has at most one console attached at a time.
	consoleMu sync.Mutex
)

const terminalInputSupported = true

type keyEventRecord struct {
	KeyDown         int32
	RepeatCount     uint16
	VirtualKeyCode  uint16
	VirtualScanCode uint16
	UnicodeChar     uint16
	ControlKeyState uint32
}

type inputRecord struct {
	EventType uint16
	_         uint16
	Event     keyEventRecord
}

const (
	keyEvent = 0x0001
	vkReturn = 0x0D
	// Key records per write: 256 keys down and up, so 128 characters.
	typeChunk = 256
)

func keyPair(vk, scan, ch uint16) []inputRecord {
	down := inputRecord{EventType: keyEvent, Event: keyEventRecord{KeyDown: 1, RepeatCount: 1, VirtualKeyCode: vk, VirtualScanCode: scan, UnicodeChar: ch}}
	up := down
	up.Event.KeyDown = 0
	return []inputRecord{down, up}
}

// typeIntoConsole types text into the console of process pid and presses
// Enter, as if the user had typed it. Line breaks become Ctrl+J, Claude
// Code's newline key, so a multi-line message is submitted once.
func typeIntoConsole(pid uint32, text string) error {
	var recs []inputRecord
	for _, r := range text {
		switch r {
		case '\r':
			continue
		case '\n':
			recs = append(recs, keyPair('J', 0x24, '\n')...)
			continue
		}
		for _, u := range utf16.Encode([]rune{r}) {
			recs = append(recs, keyPair(0, 0, u)...)
		}
	}
	// A long message written in one go can overrun the console's input
	// buffer and lose its start; write it in slices instead.
	for len(recs) > 0 {
		n := min(len(recs), typeChunk)
		if err := writeConsole(pid, recs[:n]); err != nil {
			return err
		}
		recs = recs[n:]
		if len(recs) > 0 {
			time.Sleep(15 * time.Millisecond)
		}
	}
	if text != "" {
		// The TUI reads a burst of keys as a paste, and an Enter inside a
		// paste is only a newline; send it on its own once the paste lands.
		time.Sleep(pasteSettle(len(text)))
	}
	return writeConsole(pid, keyPair(vkReturn, 0x1C, '\r'))
}

func pasteSettle(n int) time.Duration {
	return min(300*time.Millisecond+time.Duration(n)*200*time.Microsecond, 2*time.Second)
}

// pressEscape interrupts Claude Code's current turn in that console.
func pressEscape(pid uint32) error {
	return writeConsole(pid, keyPair(0x1B, 0x01, 0x1B))
}

const shiftPressed = 0x0010

// consoleKeys are SendKeys names as virtual keys and scan codes.
var consoleKeys = map[string][2]uint16{
	"Enter": {vkReturn, 0x1C}, "Escape": {0x1B, 0x01}, "Up": {0x26, 0x48}, "Down": {0x28, 0x50},
	"Left": {0x25, 0x4B}, "Right": {0x27, 0x4D}, "Tab": {0x09, 0x0F}, "BTab": {0x09, 0x0F},
	"Space": {0x20, 0x39}, "Backspace": {0x08, 0x0E},
}

// pressConsoleKeys presses named keys one at a time, then types text.
func pressConsoleKeys(pid uint32, keys []string, text string) error {
	for _, k := range keys {
		var recs []inputRecord
		if vk, ok := consoleKeys[k]; ok {
			var ch uint16
			switch k {
			case "Enter":
				ch = '\r'
			case "Escape":
				ch = 0x1B
			case "Tab", "BTab":
				ch = '\t'
			case "Space":
				ch = ' '
			case "Backspace":
				ch = 0x08
			}
			recs = keyPair(vk[0], vk[1], ch)
			if k == "BTab" {
				for i := range recs {
					recs[i].Event.ControlKeyState = shiftPressed
				}
			}
		} else {
			r := []rune(k)
			if len(r) != 1 {
				return fmt.Errorf("unknown key %s", k)
			}
			for _, u := range utf16.Encode(r) {
				recs = append(recs, keyPair(0, 0, u)...)
			}
		}
		if err := writeConsole(pid, recs); err != nil {
			return err
		}
		time.Sleep(80 * time.Millisecond)
	}
	if text == "" {
		return nil
	}
	var recs []inputRecord
	for _, r := range text {
		for _, u := range utf16.Encode([]rune{r}) {
			recs = append(recs, keyPair(0, 0, u)...)
		}
	}
	return writeConsole(pid, recs)
}

type coord struct{ X, Y int16 }

type smallRect struct{ Left, Top, Right, Bottom int16 }

type screenBufferInfo struct {
	Size              coord
	CursorPosition    coord
	Attributes        uint16
	Window            smallRect
	MaximumWindowSize coord
}

// readConsole returns the visible window of process pid's console as text.
func readConsole(pid uint32) (string, error) {
	conout, err := syscall.UTF16PtrFromString("CONOUT$")
	if err != nil {
		return "", err
	}
	consoleMu.Lock()
	defer consoleMu.Unlock()
	procFreeConsole.Call()
	if ok, _, err := procAttachConsole.Call(uintptr(pid)); ok == 0 {
		return "", fmt.Errorf("attach to the terminal of process %d: %w", pid, err)
	}
	defer procFreeConsole.Call()
	h, err := syscall.CreateFile(conout,
		syscall.GENERIC_READ|syscall.GENERIC_WRITE, syscall.FILE_SHARE_READ|syscall.FILE_SHARE_WRITE,
		nil, syscall.OPEN_EXISTING, 0, 0)
	if err != nil {
		return "", fmt.Errorf("open terminal output: %w", err)
	}
	defer syscall.CloseHandle(h)
	var info screenBufferInfo
	if ok, _, err := procGetConsoleSBInfo.Call(uintptr(h), uintptr(unsafe.Pointer(&info))); ok == 0 {
		return "", fmt.Errorf("read terminal size: %w", err)
	}
	width := int(info.Window.Right-info.Window.Left) + 1
	var b strings.Builder
	buf := make([]uint16, width)
	for y := info.Window.Top; y <= info.Window.Bottom; y++ {
		var read uint32
		at := uintptr(uint32(uint16(info.Window.Left)) | uint32(uint16(y))<<16)
		if ok, _, err := procReadConsoleOutChar.Call(uintptr(h), uintptr(unsafe.Pointer(&buf[0])), uintptr(width), at, uintptr(unsafe.Pointer(&read))); ok == 0 {
			return "", fmt.Errorf("read terminal: %w", err)
		}
		b.WriteString(strings.TrimRight(string(utf16.Decode(buf[:read])), " "))
		b.WriteByte('\n')
	}
	return b.String(), nil
}

func writeConsole(pid uint32, recs []inputRecord) error {
	conin, err := syscall.UTF16PtrFromString("CONIN$")
	if err != nil {
		return err
	}
	consoleMu.Lock()
	defer consoleMu.Unlock()
	procFreeConsole.Call()
	if ok, _, err := procAttachConsole.Call(uintptr(pid)); ok == 0 {
		return fmt.Errorf("attach to the terminal of process %d: %w", pid, err)
	}
	defer procFreeConsole.Call()

	h, err := syscall.CreateFile(conin,
		syscall.GENERIC_READ|syscall.GENERIC_WRITE, syscall.FILE_SHARE_READ|syscall.FILE_SHARE_WRITE,
		nil, syscall.OPEN_EXISTING, 0, 0)
	if err != nil {
		return fmt.Errorf("open terminal input: %w", err)
	}
	defer syscall.CloseHandle(h)

	var written uint32
	if ok, _, err := procWriteConsoleInputW.Call(uintptr(h), uintptr(unsafe.Pointer(&recs[0])), uintptr(len(recs)), uintptr(unsafe.Pointer(&written))); ok == 0 {
		return fmt.Errorf("write to terminal: %w", err)
	}
	if int(written) != len(recs) {
		return fmt.Errorf("terminal accepted %d of %d keys", written, len(recs))
	}
	return nil
}

type tcpRowOwnerPID struct {
	State, LocalAddr, LocalPort, RemoteAddr, RemotePort, OwningPID uint32
}

// pidOfLocalPeer finds the process that owns the client end of a loopback
// TCP connection, e.g. the Claude Code process posting a hook.
func pidOfLocalPeer(remoteAddr string, serverPort int) (uint32, error) {
	_, portStr, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		return 0, err
	}
	clientPort, err := strconv.Atoi(portStr)
	if err != nil {
		return 0, err
	}
	const afInet, tcpTableOwnerPIDAll = 2, 5
	var size uint32
	procGetExtendedTcpTbl.Call(0, uintptr(unsafe.Pointer(&size)), 0, afInet, tcpTableOwnerPIDAll, 0)
	if size == 0 {
		return 0, errors.New("empty TCP table")
	}
	buf := make([]byte, size)
	if r, _, _ := procGetExtendedTcpTbl.Call(uintptr(unsafe.Pointer(&buf[0])), uintptr(unsafe.Pointer(&size)), 0, afInet, tcpTableOwnerPIDAll, 0); r != 0 {
		return 0, fmt.Errorf("GetExtendedTcpTable: %d", r)
	}
	n := *(*uint32)(unsafe.Pointer(&buf[0]))
	rows := unsafe.Slice((*tcpRowOwnerPID)(unsafe.Pointer(&buf[4])), n)
	port := func(p uint32) int { return int(p&0xff)<<8 | int(p>>8&0xff) }
	for _, row := range rows {
		if port(row.LocalPort) == clientPort && port(row.RemotePort) == serverPort {
			return row.OwningPID, nil
		}
	}
	return 0, fmt.Errorf("no process owns port %d", clientPort)
}
