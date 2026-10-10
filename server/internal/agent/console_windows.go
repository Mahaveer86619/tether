package agent

import (
	"errors"
	"fmt"
	"net"
	"strconv"
	"sync"
	"syscall"
	"unicode/utf16"
	"unsafe"
)

var (
	kernel32               = syscall.NewLazyDLL("kernel32.dll")
	procFreeConsole        = kernel32.NewProc("FreeConsole")
	procAttachConsole      = kernel32.NewProc("AttachConsole")
	procWriteConsoleInputW = kernel32.NewProc("WriteConsoleInputW")
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
)

func keyPair(vk, scan, ch uint16) []inputRecord {
	down := inputRecord{EventType: keyEvent, Event: keyEventRecord{KeyDown: 1, RepeatCount: 1, VirtualKeyCode: vk, VirtualScanCode: scan, UnicodeChar: ch}}
	up := down
	up.Event.KeyDown = 0
	return []inputRecord{down, up}
}

// typeIntoConsole types text into the console of process pid and presses
// Enter, as if the user had typed it. Line breaks become Claude Code's
// "\ + Enter" newline so a multi-line message is submitted once.
func typeIntoConsole(pid uint32, text string) error {
	var recs []inputRecord
	for _, r := range text {
		if r == '\r' {
			continue
		}
		if r == '\n' {
			recs = append(recs, keyPair(0, 0, '\\')...)
			recs = append(recs, keyPair(vkReturn, 0x1C, '\r')...)
			continue
		}
		for _, u := range utf16.Encode([]rune{r}) {
			recs = append(recs, keyPair(0, 0, u)...)
		}
	}
	recs = append(recs, keyPair(vkReturn, 0x1C, '\r')...)
	return writeConsole(pid, recs)
}

// pressEscape interrupts Claude Code's current turn in that console.
func pressEscape(pid uint32) error {
	return writeConsole(pid, keyPair(0x1B, 0x01, 0x1B))
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
