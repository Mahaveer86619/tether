package jobs

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// The test binary doubles as the job: JOBS_HELPER picks what it does.
func TestMain(m *testing.M) {
	switch os.Getenv("JOBS_HELPER") {
	case "counter":
		// A child in the same group, which must die with the job.
		if dir := os.Getenv("JOBS_CHILD_PID"); dir != "" {
			child := exec.Command(os.Args[0])
			child.Env = append(os.Environ(), "JOBS_HELPER=sleep", "JOBS_CHILD_PID=")
			if err := child.Start(); err == nil {
				_ = os.WriteFile(dir, []byte(strconv.Itoa(child.Process.Pid)), 0o600)
			}
		}
		for i := 0; ; i++ {
			fmt.Println("count", i)
			time.Sleep(100 * time.Millisecond)
		}
	case "sleep":
		time.Sleep(time.Hour)
		os.Exit(0)
	case "spam":
		line := strings.Repeat("x", 200)
		for i := 0; ; i++ {
			fmt.Println(i, line)
			if i%50 == 0 {
				time.Sleep(10 * time.Millisecond)
			}
		}
	case "fail":
		fmt.Println("failing")
		os.Exit(3)
	}
	os.Exit(m.Run())
}

func helperCommand() string {
	return `"` + os.Args[0] + `"`
}

type recorder struct {
	mu   sync.Mutex
	jobs []*v1.Job
}

func (r *recorder) report(j *v1.Job) {
	r.mu.Lock()
	r.jobs = append(r.jobs, j)
	r.mu.Unlock()
}

func newSupervisor(t *testing.T, dir string) (*Supervisor, *recorder) {
	t.Helper()
	r := &recorder{}
	s := New(dir, nil, r.report, nil)
	s.Grace = 2 * time.Second
	s.RestartDelay = 50 * time.Millisecond
	t.Cleanup(s.Close)
	return s, r
}

func waitFor(t *testing.T, what string, ok func() bool) {
	t.Helper()
	deadline := time.Now().Add(20 * time.Second)
	for time.Now().Before(deadline) {
		if ok() {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatal("timed out waiting for " + what)
}

// lastCount is the last counter the helper printed, or -1.
func lastCount(s *Supervisor, id string) int {
	lines := s.Tail(id, 5)
	for i := len(lines) - 1; i >= 0; i-- {
		if n, ok := strings.CutPrefix(lines[i], "count "); ok {
			v, _ := strconv.Atoi(n)
			return v
		}
	}
	return -1
}

// killGroup is the test's own cleanup for a job it started.
func cleanupJob(t *testing.T, s *Supervisor, id string) {
	t.Cleanup(func() { _ = s.Stop(id) })
}

func TestACounterJobPausesResumesAndStopsWithItsChildren(t *testing.T) {
	s, _ := newSupervisor(t, t.TempDir())
	childFile := filepath.Join(t.TempDir(), "child.pid")
	spec := &v1.JobSpec{Name: "counter", Cwd: t.TempDir(), Command: helperCommand(),
		Env: map[string]string{"JOBS_HELPER": "counter", "JOBS_CHILD_PID": childFile}}
	j, err := s.Start("c1", spec, nil)
	if err != nil {
		t.Fatal(err)
	}
	cleanupJob(t, s, "c1")
	if j.State != v1.JobState_JOB_STATE_RUNNING || j.Pid == 0 {
		t.Fatalf("started job: %v", j)
	}
	waitFor(t, "the counter to reach 3", func() bool { return lastCount(s, "c1") >= 3 })
	var childPid int
	waitFor(t, "the child's pid", func() bool {
		b, _ := os.ReadFile(childFile)
		childPid, _ = strconv.Atoi(string(b))
		return childPid > 0
	})

	if err := s.Pause("c1"); err != nil {
		t.Fatal(err)
	}
	if st := s.Get("c1").State; st != v1.JobState_JOB_STATE_PAUSED {
		t.Fatalf("state after pause: %v", st)
	}
	time.Sleep(300 * time.Millisecond)
	paused := lastCount(s, "c1")
	time.Sleep(time.Second)
	if now := lastCount(s, "c1"); now != paused {
		t.Fatalf("the counter moved while paused: %d -> %d", paused, now)
	}

	if err := s.Resume("c1"); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "the counter to move on after resume", func() bool { return lastCount(s, "c1") >= paused+3 })

	if err := s.Pause("c1"); err != nil {
		t.Fatal(err)
	}
	if err := s.Stop("c1"); err != nil {
		t.Fatal(err)
	}
	got := s.Get("c1")
	if got.State != v1.JobState_JOB_STATE_STOPPED {
		t.Fatalf("state after stop: %v (%s)", got.State, got.Error)
	}
	if processAlive(int(got.Pid)) {
		t.Fatal("the job's process is still running")
	}
	waitFor(t, "the child to be gone", func() bool { return !processAlive(childPid) })
}

func TestAJobFoundGoneAfterAnAgentRestartIsLostAndOneStillRunningIsAdopted(t *testing.T) {
	dir := t.TempDir()
	s1, _ := newSupervisor(t, dir)
	spec := &v1.JobSpec{Cwd: t.TempDir(), Command: helperCommand(), Env: map[string]string{"JOBS_HELPER": "counter"}}
	if _, err := s1.Start("alive", spec, nil); err != nil {
		t.Fatal(err)
	}
	if _, err := s1.Start("gone", spec, nil); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "both to count", func() bool { return lastCount(s1, "alive") >= 1 && lastCount(s1, "gone") >= 1 })
	gonePid := int(s1.Get("gone").Pid)
	// The agent goes away; then the device loses one of the processes.
	s1.Close()
	s1.mu.Lock()
	s1.jobs["gone"].group.kill()
	s1.mu.Unlock()
	waitFor(t, "the lost process to end", func() bool { return !processAlive(gonePid) })

	s2, r := newSupervisor(t, dir)
	s2.Recover()
	cleanupJob(t, s2, "alive")
	if st := s2.Get("gone"); st.State != v1.JobState_JOB_STATE_LOST {
		t.Fatalf("a job whose process is gone: %v, want lost", st.State)
	}
	alive := s2.Get("alive")
	if alive.State != v1.JobState_JOB_STATE_RUNNING {
		t.Fatalf("a job still running: %v (%s)", alive.State, alive.Error)
	}
	if len(r.jobs) != 2 {
		t.Fatalf("reported %d jobs after recovering, want 2", len(r.jobs))
	}
	before := lastCount(s2, "alive")
	waitFor(t, "the adopted job's log to grow", func() bool { return lastCount(s2, "alive") > before })
	if err := s2.Pause("alive"); err != nil {
		t.Fatal(err)
	}
	if err := s2.Stop("alive"); err != nil {
		t.Fatal(err)
	}
	if st := s2.Get("alive").State; st != v1.JobState_JOB_STATE_STOPPED {
		t.Fatalf("adopted job after stop: %v", st)
	}
	if processAlive(int(alive.Pid)) {
		t.Fatal("the adopted job's process is still running")
	}
}

func TestTheLogStaysUnderItsCapAndKeepsTheTail(t *testing.T) {
	s, _ := newSupervisor(t, t.TempDir())
	s.LogCap = 64 << 10
	var mu sync.Mutex
	got := 0
	s.lines = func(_ string, lines []string) {
		mu.Lock()
		got += len(lines)
		mu.Unlock()
	}
	spec := &v1.JobSpec{Cwd: t.TempDir(), Command: helperCommand(), Env: map[string]string{"JOBS_HELPER": "spam"}}
	if _, err := s.Start("spam", spec, nil); err != nil {
		t.Fatal(err)
	}
	cleanupJob(t, s, "spam")
	waitFor(t, "the log to be rotated", func() bool {
		_, err := os.Stat(s.LogPath("spam") + ".1")
		return err == nil
	})
	if err := s.Stop("spam"); err != nil {
		t.Fatal(err)
	}
	s.follow("spam")
	for _, p := range []string{s.LogPath("spam"), s.LogPath("spam") + ".1"} {
		st, err := os.Stat(p)
		if err != nil {
			t.Fatal(err)
		}
		// One tick's worth of output may land on top of the cap.
		if st.Size() > s.LogCap+maxReadPerTick {
			t.Fatalf("%s is %d bytes, over the cap", p, st.Size())
		}
	}
	if tail := s.Tail("spam", 20); len(tail) != 20 {
		t.Fatalf("tail has %d lines", len(tail))
	}
	mu.Lock()
	defer mu.Unlock()
	if got < 100 {
		t.Fatalf("only %d lines were streamed", got)
	}
}

func TestAFailingJobRestartsUpToItsLimit(t *testing.T) {
	s, _ := newSupervisor(t, t.TempDir())
	spec := &v1.JobSpec{Cwd: t.TempDir(), Command: helperCommand(), Env: map[string]string{"JOBS_HELPER": "fail"},
		Restart: "on-failure", RestartLimit: 2}
	if _, err := s.Start("f", spec, nil); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "the restarts to run out", func() bool {
		j := s.Get("f")
		return j.Restarts == 2 && j.State == v1.JobState_JOB_STATE_FAILED && !strings.Contains(j.Error, "restarting")
	})
	if j := s.Get("f"); j.ExitCode != 3 {
		t.Fatalf("exit code %d", j.ExitCode)
	}
	if n := strings.Count(strings.Join(s.Tail("f", 50), "\n"), "failing"); n != 3 {
		t.Fatalf("ran %d times, want 3", n)
	}
}

func TestAJobInAMissingFolderFails(t *testing.T) {
	s, _ := newSupervisor(t, t.TempDir())
	j, err := s.Start("m", &v1.JobSpec{Cwd: filepath.Join(t.TempDir(), "nope"), Command: "echo hi"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if j.State != v1.JobState_JOB_STATE_FAILED || !strings.Contains(j.Error, "does not exist") {
		t.Fatalf("got %v %q", j.State, j.Error)
	}
}

func TestSecretsAreNotWrittenToTheRecord(t *testing.T) {
	dir := t.TempDir()
	s, _ := newSupervisor(t, dir)
	spec := &v1.JobSpec{Cwd: t.TempDir(), Command: helperCommand(), Env: map[string]string{"JOBS_HELPER": "fail"}}
	if _, err := s.Start("sec", spec, map[string]string{"API_KEY": "hunter2"}); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "the job to end", func() bool { return s.Get("sec").State == v1.JobState_JOB_STATE_FAILED })
	b, err := os.ReadFile(filepath.Join(dir, "sec", "job.json"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(b), "hunter2") {
		t.Fatal("the secret is in the job's record")
	}
}
