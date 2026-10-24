package console

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

// TerminalInputSupported is true on Windows where Tether can attach to console processes.
const TerminalInputSupported = true

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

// Type sends text into a Windows console process by attaching to it and
// injecting WriteConsoleInputW records.
func Type(pid uint32, text string) error {
	var recs []inputRecord
	for _, r := range text {
		switch r {
		case '\r':
			continue
		case '\n':
			recs = append(recs, keyPair(vkReturn, 0x1C, '\r')...)
		default:
			for _, u := range utf16.Encode([]rune{r}) {
				recs = append(recs, keyPair(0, 0, u)...)
			}
		}
	}
	for i := 0; i < len(recs); i += typeChunk {
		end := min(i+typeChunk, len(recs))
		if err := writeInput(pid, recs[i:end]); err != nil {
			return err
		}
		if end < len(recs) {
			time.Sleep(30 * time.Millisecond)
		}
	}
	return nil
}

// PressEscape injects the Escape key.
func PressEscape(pid uint32) error {
	const vkEscape = 0x1B
	return writeInput(pid, keyPair(vkEscape, 0x01, 0x1B))
}

var winKeys = map[string]struct{ vk, scan uint16 }{
	"Enter":     {vkReturn, 0x1C},
	"Escape":    {0x1B, 0x01},
	"Up":        {0x26, 0x48},
	"Down":      {0x28, 0x50},
	"Left":      {0x25, 0x4B},
	"Right":     {0x27, 0x4D},
	"Tab":       {0x09, 0x0F},
	"Space":     {0x20, 0x39},
	"Backspace": {0x08, 0x0E},
}

// PressKeys injects virtual keys followed by typed text.
func PressKeys(pid uint32, keys []string, text string) error {
	var recs []inputRecord
	for _, k := range keys {
		spec, ok := winKeys[k]
		if !ok {
			return errors.New("unknown key " + k)
		}
		recs = append(recs, keyPair(spec.vk, spec.scan, 0)...)
	}
	if len(recs) > 0 {
		if err := writeInput(pid, recs); err != nil {
			return err
		}
		if text != "" {
			time.Sleep(150 * time.Millisecond)
		}
	}
	if text != "" {
		return Type(pid, text)
	}
	return nil
}

type coord struct{ X, Y int16 }
type smallRect struct{ Left, Top, Right, Bottom int16 }
type consoleScreenBufferInfo struct {
	Size       coord
	CursorPos  coord
	Attributes uint16
	Window     smallRect
	MaxWindow  coord
}

// Read copies the current console screen buffer of the process as text.
func Read(pid uint32) (string, error) {
	conout, err := syscall.UTF16PtrFromString("CONOUT$")
	if err != nil {
		return "", err
	}
	consoleMu.Lock()
	defer consoleMu.Unlock()
	procFreeConsole.Call()
	if ok, _, err := procAttachConsole.Call(uintptr(pid)); ok == 0 {
		return "", fmt.Errorf("attach to console of process %d: %w", pid, err)
	}
	defer procFreeConsole.Call()

	h, err := syscall.CreateFile(conout,
		syscall.GENERIC_READ|syscall.GENERIC_WRITE, syscall.FILE_SHARE_READ|syscall.FILE_SHARE_WRITE,
		nil, syscall.OPEN_EXISTING, 0, 0)
	if err != nil {
		return "", fmt.Errorf("open CONOUT$: %w", err)
	}
	defer syscall.CloseHandle(h)

	var info consoleScreenBufferInfo
	if ok, _, err := procGetConsoleSBInfo.Call(uintptr(h), uintptr(unsafe.Pointer(&info))); ok == 0 {
		return "", fmt.Errorf("get screen buffer info: %w", err)
	}

	w := int(info.Window.Right - info.Window.Left + 1)
	hLines := int(info.Window.Bottom - info.Window.Top + 1)
	if w <= 0 || hLines <= 0 || w > 500 || hLines > 200 {
		w, hLines = int(info.Size.X), int(info.Size.Y)
	}
	total := w * hLines
	if total <= 0 || total > 200000 {
		return "", fmt.Errorf("implausible console size %dx%d", w, hLines)
	}

	buf := make([]uint16, total)
	var read uint32
	origin := coord{X: info.Window.Left, Y: info.Window.Top}
	if ok, _, err := procReadConsoleOutChar.Call(uintptr(h), uintptr(unsafe.Pointer(&buf[0])),
		uintptr(total), *(*uintptr)(unsafe.Pointer(&origin)), uintptr(unsafe.Pointer(&read))); ok == 0 {
		return "", fmt.Errorf("read console characters: %w", err)
	}

	var b strings.Builder
	for row := 0; row < hLines; row++ {
		start := row * w
		end := min(start+w, int(read))
		if start >= len(buf) {
			break
		}
		line := strings.TrimRight(string(utf16.Decode(buf[start:end])), " ")
		b.WriteString(line)
		b.WriteByte('\n')
	}
	return strings.TrimRight(b.String(), "\n"), nil
}

func writeInput(pid uint32, recs []inputRecord) error {
	if len(recs) == 0 {
		return nil
	}
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

// PIDOfLocalPeer finds the process that owns the client end of a loopback
// TCP connection, e.g. the Claude Code process posting a hook.
func PIDOfLocalPeer(remoteAddr string, serverPort int) (uint32, error) {
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
