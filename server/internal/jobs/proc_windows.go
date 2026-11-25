package jobs

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"strconv"
	"sync"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

// procGroup is a job's Windows Job Object: every process the job starts
// joins it, so the whole tree can be suspended or ended together. It is
// made without kill-on-close, so the job outlives the agent.
type procGroup struct {
	job     windows.Handle
	pid     uint32
	created int64

	mu     sync.Mutex
	closed bool
}

var (
	kernel32          = windows.NewLazySystemDLL("kernel32.dll")
	procSuspendThread = kernel32.NewProc("SuspendThread")
)

const (
	createNoWindow   = 0x08000000
	processAccess    = windows.PROCESS_SET_QUOTA | windows.PROCESS_TERMINATE | windows.PROCESS_QUERY_LIMITED_INFORMATION
	maxPidsInJobList = 1024
)

func shellCommand(ctx context.Context, command string) *exec.Cmd {
	shell := os.Getenv("ComSpec")
	if shell == "" {
		shell = `C:\Windows\System32\cmd.exe`
	}
	cmd := exec.CommandContext(ctx, shell)
	// /s with the outer quotes passes the command to cmd exactly as written.
	cmd.SysProcAttr = &syscall.SysProcAttr{
		CmdLine:       `/d /s /c "` + command + `"`,
		HideWindow:    true,
		CreationFlags: createNoWindow,
	}
	return cmd
}

// startGroup starts the process suspended, puts it in a new Job Object,
// then lets it run, so no child it starts can escape the job.
func startGroup(cmd *exec.Cmd) (*procGroup, error) {
	if cmd.SysProcAttr == nil {
		cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	}
	cmd.SysProcAttr.CreationFlags |= windows.CREATE_SUSPENDED | windows.CREATE_NEW_PROCESS_GROUP | createNoWindow
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	pid := uint32(cmd.Process.Pid)
	g, err := newGroup(pid)
	if err != nil {
		_ = cmd.Process.Kill()
		return nil, err
	}
	if err := resumeThreads(map[uint32]bool{pid: true}); err != nil {
		g.kill()
		g.close()
		return nil, err
	}
	return g, nil
}

func newGroup(pid uint32) (*procGroup, error) {
	job, err := windows.CreateJobObject(nil, nil)
	if err != nil {
		return nil, err
	}
	g := &procGroup{job: job, pid: pid}
	created, err := g.assign(pid)
	if err != nil {
		windows.CloseHandle(job)
		return nil, err
	}
	g.created = created
	return g, nil
}

// assign adds a process to the group and returns when it was created.
func (g *procGroup) assign(pid uint32) (int64, error) {
	h, err := windows.OpenProcess(processAccess, false, pid)
	if err != nil {
		return 0, err
	}
	defer windows.CloseHandle(h)
	if err := windows.AssignProcessToJobObject(g.job, h); err != nil {
		return 0, err
	}
	return processCreated(h)
}

func processCreated(h windows.Handle) (int64, error) {
	var created, exited, kernel, user windows.Filetime
	if err := windows.GetProcessTimes(h, &created, &exited, &kernel, &user); err != nil {
		return 0, err
	}
	return created.Nanoseconds(), nil
}

// adoptGroup takes back a job an earlier agent started: the process must be
// alive and created when the record says, so a reused pid isn't taken for
// it. Its Job Object went with the old agent, so a new one is made and the
// process and its descendants put in it.
func adoptGroup(pid int, created int64) (*procGroup, bool) {
	if pid <= 0 || created == 0 {
		return nil, false
	}
	h, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, uint32(pid))
	if err != nil {
		return nil, false
	}
	var code uint32
	alive := windows.GetExitCodeProcess(h, &code) == nil && code == 259 // STILL_ACTIVE
	when, err := processCreated(h)
	windows.CloseHandle(h)
	if !alive || err != nil || when != created {
		return nil, false
	}
	g, err := newGroup(uint32(pid))
	if err != nil {
		return nil, false
	}
	for _, child := range descendants(uint32(pid), created) {
		_, _ = g.assign(child)
	}
	return g, true
}

// descendants are the processes below pid created after it; the time check
// skips processes whose parent id merely names a dead parent's reused pid.
func descendants(pid uint32, after int64) []uint32 {
	snap, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return nil
	}
	defer windows.CloseHandle(snap)
	children := map[uint32][]uint32{}
	var e windows.ProcessEntry32
	e.Size = uint32(unsafe.Sizeof(e))
	for err := windows.Process32First(snap, &e); err == nil; err = windows.Process32Next(snap, &e) {
		children[e.ParentProcessID] = append(children[e.ParentProcessID], e.ProcessID)
	}
	var out []uint32
	queue := []uint32{pid}
	seen := map[uint32]bool{pid: true}
	for len(queue) > 0 {
		p := queue[0]
		queue = queue[1:]
		for _, c := range children[p] {
			if seen[c] {
				continue
			}
			seen[c] = true
			if h, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, c); err == nil {
				when, err := processCreated(h)
				windows.CloseHandle(h)
				if err == nil && when >= after {
					out = append(out, c)
					queue = append(queue, c)
				}
			}
		}
	}
	return out
}

type pidList struct {
	assigned uint32
	listed   uint32
	ids      [maxPidsInJobList]uintptr
}

func (g *procGroup) pids() (map[uint32]bool, error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.closed {
		return nil, errors.New("the job has ended")
	}
	var list pidList
	if err := windows.QueryInformationJobObject(g.job, windows.JobObjectBasicProcessIdList,
		uintptr(unsafe.Pointer(&list)), uint32(unsafe.Sizeof(list)), nil); err != nil {
		return nil, err
	}
	out := make(map[uint32]bool, list.listed)
	for _, id := range list.ids[:min(list.listed, maxPidsInJobList)] {
		out[uint32(id)] = true
	}
	return out, nil
}

func (g *procGroup) alive() bool {
	pids, err := g.pids()
	return err == nil && len(pids) > 0
}

// terminate asks the job's main process to close, as closing its window
// would. Console programs can't be asked, so it reports false and the
// caller ends the job at once.
func (g *procGroup) terminate() bool {
	cmd := exec.Command("taskkill", "/T", "/PID", strconv.Itoa(int(g.pid)))
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: createNoWindow}
	return cmd.Run() == nil
}

func (g *procGroup) kill() {
	g.mu.Lock()
	defer g.mu.Unlock()
	if !g.closed {
		_ = windows.TerminateJobObject(g.job, 1)
	}
}

func (g *procGroup) suspend() error {
	pids, err := g.pids()
	if err != nil {
		return err
	}
	return eachThread(pids, func(t windows.Handle) error {
		if r, _, err := procSuspendThread.Call(uintptr(t)); int32(r) == -1 {
			return err
		}
		return nil
	})
}

func (g *procGroup) resume() error {
	pids, err := g.pids()
	if err != nil {
		return err
	}
	return resumeThreads(pids)
}

func resumeThreads(pids map[uint32]bool) error {
	return eachThread(pids, func(t windows.Handle) error {
		_, err := windows.ResumeThread(t)
		return err
	})
}

// eachThread calls fn with every thread of the processes in pids.
func eachThread(pids map[uint32]bool, fn func(windows.Handle) error) error {
	snap, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPTHREAD, 0)
	if err != nil {
		return err
	}
	defer windows.CloseHandle(snap)
	var e windows.ThreadEntry32
	e.Size = uint32(unsafe.Sizeof(e))
	var first error
	found := false
	for err := windows.Thread32First(snap, &e); err == nil; err = windows.Thread32Next(snap, &e) {
		if !pids[e.OwnerProcessID] {
			continue
		}
		t, err := windows.OpenThread(windows.THREAD_SUSPEND_RESUME, false, e.ThreadID)
		if err != nil {
			first = firstErr(first, err)
			continue
		}
		found = true
		first = firstErr(first, fn(t))
		windows.CloseHandle(t)
	}
	if !found && first == nil {
		return errors.New("the job has no threads left")
	}
	return first
}

func firstErr(first, err error) error {
	if first != nil {
		return first
	}
	return err
}

// close lets go of the Job Object; after it, kill does nothing, since the
// handle's value may name something else.
func (g *procGroup) close() {
	g.mu.Lock()
	defer g.mu.Unlock()
	if !g.closed {
		g.closed = true
		windows.CloseHandle(g.job)
	}
}
