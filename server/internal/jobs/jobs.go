// Package jobs starts and supervises the agent's jobs: servers, scripts and
// training runs that outlive the app, with their output in a capped log.
// See docs/architecture/jobs.md.
package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"sync"
	"time"

	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

const (
	DefaultLogCap       = 8 << 20
	DefaultGrace        = 10 * time.Second
	defaultRestartLimit = 5
	checkpointTimeout   = 2 * time.Minute
	tailEvery           = 500 * time.Millisecond
	watchEvery          = time.Second
	keepEnded           = 7 * 24 * time.Hour
	maxRestartDelay     = 30 * time.Second
)

var (
	ErrNotFound   = errors.New("no such job")
	ErrRunning    = errors.New("the job is already running")
	ErrNotRunning = errors.New("the job is not running")
	ErrNotPaused  = errors.New("the job is not paused")
)

type Supervisor struct {
	dir    string
	log    *slog.Logger
	report func(*v1.Job)
	lines  func(id string, lines []string)

	// Set before Recover or the first Start.
	LogCap       int64
	Grace        time.Duration
	RestartDelay time.Duration

	mu     sync.Mutex
	jobs   map[string]*job
	quit   chan struct{}
	closed bool
}

type job struct {
	info *v1.Job
	// Values from the project's sealed files; never written to disk.
	secret   map[string]string
	group    *procGroup
	created  int64
	stopping bool
	// Closed when the current process and its group have ended.
	done chan struct{}
	// Counts starts, so a wait or a delayed restart from an earlier one
	// leaves a newer one alone.
	gen     int
	offset  int64
	partial []byte
}

// record is what is kept on disk per job, so a restarted agent can find
// what it was running.
type record struct {
	Job     json.RawMessage `json:"job"`
	Created int64           `json:"proc_created"`
}

// New makes a supervisor keeping its records and logs under dir. report and
// lines are called without the supervisor's lock held.
func New(dir string, log *slog.Logger, report func(*v1.Job), lines func(string, []string)) *Supervisor {
	if log == nil {
		log = slog.Default()
	}
	s := &Supervisor{dir: dir, log: log, report: report, lines: lines,
		LogCap: DefaultLogCap, Grace: DefaultGrace, RestartDelay: time.Second,
		jobs: map[string]*job{}, quit: make(chan struct{})}
	go s.tailLoop()
	return s
}

// Close stops following logs. Jobs keep running.
func (s *Supervisor) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.closed {
		s.closed = true
		close(s.quit)
	}
}

func live(st v1.JobState) bool {
	switch st {
	case v1.JobState_JOB_STATE_STARTING, v1.JobState_JOB_STATE_RUNNING, v1.JobState_JOB_STATE_PAUSED:
		return true
	}
	return false
}

func (s *Supervisor) jobDir(id string) string { return filepath.Join(s.dir, id) }

// LogPath is where a job's output goes.
func (s *Supervisor) LogPath(id string) string { return filepath.Join(s.jobDir(id), "output.log") }

// Recover reads the records of an earlier run: a job whose process is
// still there is followed again, one that is gone is lost.
func (s *Supervisor) Recover() {
	entries, err := os.ReadDir(s.dir)
	if err != nil {
		return
	}
	var changed []*v1.Job
	s.mu.Lock()
	for _, e := range entries {
		if !e.IsDir() || s.jobs[e.Name()] != nil {
			continue
		}
		b, err := os.ReadFile(filepath.Join(s.dir, e.Name(), "job.json"))
		if err != nil {
			continue
		}
		var rec record
		info := &v1.Job{}
		if json.Unmarshal(b, &rec) != nil || protojson.Unmarshal(rec.Job, info) != nil || info.Id != e.Name() {
			continue
		}
		if !live(info.State) && time.Since(time.UnixMilli(info.UpdatedMs)) > keepEnded {
			_ = os.RemoveAll(filepath.Join(s.dir, e.Name()))
			continue
		}
		j := &job{info: info, created: rec.Created}
		if st, err := os.Stat(s.LogPath(info.Id)); err == nil {
			j.offset = st.Size()
		}
		s.jobs[info.Id] = j
		if !live(info.State) {
			continue
		}
		if g, ok := adoptGroup(int(info.Pid), rec.Created); ok {
			j.group, j.done = g, make(chan struct{})
			if info.State == v1.JobState_JOB_STATE_STARTING {
				info.State = v1.JobState_JOB_STATE_RUNNING
			}
			go s.watchAdopted(j, j.gen, g)
		} else {
			info.State = v1.JobState_JOB_STATE_LOST
			info.Error = "it was not running when the agent started again; the device may have restarted"
			info.EndedMs = time.Now().UnixMilli()
		}
		info.UpdatedMs = time.Now().UnixMilli()
		s.save(j)
		changed = append(changed, proto.Clone(info).(*v1.Job))
	}
	s.mu.Unlock()
	for _, c := range changed {
		s.report(c)
	}
}

// List is every job the supervisor knows, oldest first.
func (s *Supervisor) List() []*v1.Job {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]*v1.Job, 0, len(s.jobs))
	for _, j := range s.jobs {
		out = append(out, proto.Clone(j.info).(*v1.Job))
	}
	sort.Slice(out, func(i, k int) bool { return out[i].CreatedMs < out[k].CreatedMs })
	return out
}

func (s *Supervisor) Get(id string) *v1.Job {
	s.mu.Lock()
	defer s.mu.Unlock()
	if j := s.jobs[id]; j != nil {
		return proto.Clone(j.info).(*v1.Job)
	}
	return nil
}

// Start runs a new job, or a known one that has ended again. It reports
// the job as failed, rather than returning an error, when it can't start.
func (s *Supervisor) Start(id string, spec *v1.JobSpec, secret map[string]string) (*v1.Job, error) {
	if id == "" || spec == nil || spec.Command == "" {
		return nil, errors.New("a job needs an id and a command")
	}
	s.mu.Lock()
	j := s.jobs[id]
	if j != nil && (live(j.info.State) || j.group != nil) {
		s.mu.Unlock()
		return nil, ErrRunning
	}
	now := time.Now().UnixMilli()
	if j == nil {
		j = &job{info: &v1.Job{Id: id, CreatedMs: now}}
		s.jobs[id] = j
	}
	j.info.Spec = proto.Clone(spec).(*v1.JobSpec)
	j.info.Restarts = 0
	j.secret = secret
	s.launch(j)
	out := proto.Clone(j.info).(*v1.Job)
	s.mu.Unlock()
	s.report(out)
	return out, nil
}

// launch starts j's process. Caller holds s.mu.
func (s *Supervisor) launch(j *job) {
	j.gen++
	j.stopping = false
	info, spec := j.info, j.info.Spec
	now := time.Now()
	info.StartedMs, info.EndedMs, info.ExitCode, info.Pid, info.Error = now.UnixMilli(), 0, 0, 0, ""
	info.UpdatedMs = now.UnixMilli()
	fail := func(err error) {
		info.State, info.Error, info.EndedMs = v1.JobState_JOB_STATE_FAILED, err.Error(), now.UnixMilli()
		s.save(j)
	}
	if st, err := os.Stat(spec.Cwd); spec.Cwd == "" || err != nil || !st.IsDir() {
		fail(fmt.Errorf("the folder %q does not exist on this device", spec.Cwd))
		return
	}
	if err := os.MkdirAll(s.jobDir(info.Id), 0o700); err != nil {
		fail(err)
		return
	}
	out, err := os.OpenFile(s.LogPath(info.Id), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		fail(err)
		return
	}
	fmt.Fprintf(out, "--- %s started: %s\n", now.Format(time.RFC3339), spec.Command)
	cmd := shellCommand(context.Background(), spec.Command)
	cmd.Dir = spec.Cwd
	cmd.Env = s.env(j)
	cmd.Stdout, cmd.Stderr = out, out
	g, err := startGroup(cmd)
	out.Close()
	if err != nil {
		fail(fmt.Errorf("could not start: %w", err))
		return
	}
	j.group, j.created, j.done = g, g.created, make(chan struct{})
	info.Pid = int32(cmd.Process.Pid)
	info.State = v1.JobState_JOB_STATE_RUNNING
	if spec.Port > 0 {
		info.State = v1.JobState_JOB_STATE_STARTING
		go s.waitPort(j, j.gen, int(spec.Port))
	}
	s.save(j)
	go s.wait(j, j.gen, cmd, g)
}

func (s *Supervisor) env(j *job) []string {
	env := os.Environ()
	for k, v := range j.info.Spec.Env {
		env = append(env, k+"="+v)
	}
	for k, v := range j.secret {
		env = append(env, k+"="+v)
	}
	return env
}

// wait follows a process the supervisor started until it ends, then ends
// what is left of its group and applies the restart policy.
func (s *Supervisor) wait(j *job, gen int, cmd *exec.Cmd, g *procGroup) {
	err := cmd.Wait()
	code := -1
	if cmd.ProcessState != nil {
		code = cmd.ProcessState.ExitCode()
	}
	if s.isClosed() {
		g.close()
		return
	}
	g.kill()
	g.close()
	s.ended(j, gen, code, err, true)
}

// watchAdopted follows a process found after an agent restart. It isn't the
// agent's child, so its exit code can't be known.
func (s *Supervisor) watchAdopted(j *job, gen int, g *procGroup) {
	t := time.NewTicker(watchEvery)
	defer t.Stop()
	for range t.C {
		if !g.alive() || s.isClosed() {
			break
		}
	}
	g.close()
	if !s.isClosed() {
		s.ended(j, gen, -1, nil, false)
	}
}

// isClosed reports whether the agent is going away: what happens to its jobs
// then is for the next agent to find.
func (s *Supervisor) isClosed() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.closed
}

func (s *Supervisor) ended(j *job, gen, code int, waitErr error, known bool) {
	s.mu.Lock()
	if j.gen != gen {
		s.mu.Unlock()
		return
	}
	info := j.info
	now := time.Now().UnixMilli()
	info.EndedMs, info.UpdatedMs, info.ExitCode = now, now, int32(code)
	j.group = nil
	close(j.done)
	switch {
	case j.stopping:
		info.State, info.Error = v1.JobState_JOB_STATE_STOPPED, ""
	case !known:
		info.State, info.Error = v1.JobState_JOB_STATE_EXITED, "ended while the agent was restarted; its exit code is unknown"
	case code == 0:
		info.State, info.Error = v1.JobState_JOB_STATE_EXITED, ""
	default:
		info.State = v1.JobState_JOB_STATE_FAILED
		info.Error = "exit code " + strconv.Itoa(code)
		if code < 0 && waitErr != nil {
			info.Error = waitErr.Error()
		}
	}
	if s.shouldRestart(j) {
		info.Restarts++
		delay := min(s.RestartDelay<<(info.Restarts-1), maxRestartDelay)
		if info.Error != "" {
			info.Error += "; "
		}
		info.Error += fmt.Sprintf("restarting in %s (%d of %d)", delay, info.Restarts, restartLimit(info.Spec))
		time.AfterFunc(delay, func() {
			s.mu.Lock()
			if j.gen != gen || j.stopping || j.group != nil || s.closed {
				s.mu.Unlock()
				return
			}
			restarts := info.Restarts
			s.launch(j)
			info.Restarts = restarts
			out := proto.Clone(info).(*v1.Job)
			s.mu.Unlock()
			s.report(out)
		})
	}
	s.save(j)
	out := proto.Clone(info).(*v1.Job)
	s.mu.Unlock()
	s.report(out)
}

func restartLimit(spec *v1.JobSpec) int32 {
	if spec.RestartLimit > 0 {
		return spec.RestartLimit
	}
	return defaultRestartLimit
}

// shouldRestart applies the job's restart policy. Caller holds s.mu.
func (s *Supervisor) shouldRestart(j *job) bool {
	if j.stopping || s.closed || j.info.Restarts >= restartLimit(j.info.Spec) {
		return false
	}
	switch j.info.Spec.Restart {
	case "always":
		return j.info.State == v1.JobState_JOB_STATE_EXITED || j.info.State == v1.JobState_JOB_STATE_FAILED
	case "on-failure":
		return j.info.State == v1.JobState_JOB_STATE_FAILED
	}
	return false
}

// waitPort marks a server running once its port takes connections.
func (s *Supervisor) waitPort(j *job, gen, port int) {
	addr := net.JoinHostPort("localhost", strconv.Itoa(port))
	for {
		time.Sleep(tailEvery)
		s.mu.Lock()
		if j.gen != gen || j.info.State != v1.JobState_JOB_STATE_STARTING {
			s.mu.Unlock()
			return
		}
		s.mu.Unlock()
		c, err := net.DialTimeout("tcp", addr, 300*time.Millisecond)
		if err != nil {
			continue
		}
		c.Close()
		s.mu.Lock()
		if j.gen != gen || j.info.State != v1.JobState_JOB_STATE_STARTING {
			s.mu.Unlock()
			return
		}
		j.info.State, j.info.UpdatedMs = v1.JobState_JOB_STATE_RUNNING, time.Now().UnixMilli()
		s.save(j)
		out := proto.Clone(j.info).(*v1.Job)
		s.mu.Unlock()
		s.report(out)
		return
	}
}

// Stop runs the job's checkpoint command if it has one, asks the process
// group to end, and ends it after the grace period. It returns once the
// group is gone.
func (s *Supervisor) Stop(id string) error {
	s.mu.Lock()
	j := s.jobs[id]
	if j == nil {
		s.mu.Unlock()
		return ErrNotFound
	}
	j.stopping = true
	g, done, paused := j.group, j.done, j.info.State == v1.JobState_JOB_STATE_PAUSED
	spec := j.info.Spec
	env := s.env(j)
	s.mu.Unlock()
	if g == nil {
		return nil
	}
	if spec.Checkpoint != "" {
		s.checkpoint(id, spec, env)
	}
	if paused {
		_ = g.resume()
	}
	if g.terminate() {
		select {
		case <-done:
			return nil
		case <-time.After(s.Grace):
		}
	}
	g.kill()
	select {
	case <-done:
		return nil
	case <-time.After(10 * time.Second):
		return errors.New("the job's processes did not end")
	}
}

func (s *Supervisor) checkpoint(id string, spec *v1.JobSpec, env []string) {
	out, err := os.OpenFile(s.LogPath(id), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return
	}
	defer out.Close()
	fmt.Fprintf(out, "--- %s checkpoint: %s\n", time.Now().Format(time.RFC3339), spec.Checkpoint)
	ctx, cancel := context.WithTimeout(context.Background(), checkpointTimeout)
	defer cancel()
	cmd := shellCommand(ctx, spec.Checkpoint)
	cmd.Dir, cmd.Env, cmd.Stdout, cmd.Stderr = spec.Cwd, env, out, out
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(out, "--- checkpoint failed: %v\n", err)
	}
}

// Pause suspends every process of the job. Their memory, and a GPU's, stays
// held.
func (s *Supervisor) Pause(id string) error {
	return s.setPaused(id, true)
}

func (s *Supervisor) Resume(id string) error {
	return s.setPaused(id, false)
}

func (s *Supervisor) setPaused(id string, pause bool) error {
	s.mu.Lock()
	j := s.jobs[id]
	if j == nil {
		s.mu.Unlock()
		return ErrNotFound
	}
	st := j.info.State
	switch {
	case j.group == nil:
		s.mu.Unlock()
		return ErrNotRunning
	case pause && st == v1.JobState_JOB_STATE_PAUSED, !pause && st != v1.JobState_JOB_STATE_PAUSED:
		s.mu.Unlock()
		if pause {
			return nil
		}
		return ErrNotPaused
	}
	var err error
	if pause {
		err = j.group.suspend()
		j.info.State = v1.JobState_JOB_STATE_PAUSED
	} else {
		err = j.group.resume()
		j.info.State = v1.JobState_JOB_STATE_RUNNING
	}
	if err != nil {
		j.info.State = st
		s.mu.Unlock()
		return err
	}
	j.info.UpdatedMs = time.Now().UnixMilli()
	s.save(j)
	out := proto.Clone(j.info).(*v1.Job)
	s.mu.Unlock()
	s.report(out)
	return nil
}

// Restart stops the job if it runs and starts it again; a nil spec or
// secret keeps the job's own.
func (s *Supervisor) Restart(id string, spec *v1.JobSpec, secret map[string]string) (*v1.Job, error) {
	s.mu.Lock()
	j := s.jobs[id]
	if j != nil {
		if spec == nil {
			spec = j.info.Spec
		}
		if secret == nil {
			secret = j.secret
		}
	}
	s.mu.Unlock()
	if spec == nil {
		return nil, ErrNotFound
	}
	if j != nil {
		if err := s.Stop(id); err != nil {
			return nil, err
		}
	}
	return s.Start(id, spec, secret)
}

// Forget deletes an ended job's record and log.
func (s *Supervisor) Forget(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	j := s.jobs[id]
	if j == nil {
		return ErrNotFound
	}
	if j.group != nil {
		return ErrRunning
	}
	j.gen++
	j.stopping = true
	delete(s.jobs, id)
	return os.RemoveAll(s.jobDir(id))
}

// save writes j's record. Caller holds s.mu.
func (s *Supervisor) save(j *job) {
	b, err := protojson.Marshal(j.info)
	if err == nil {
		b, err = json.Marshal(record{Job: b, Created: j.created})
	}
	if err == nil {
		err = os.MkdirAll(s.jobDir(j.info.Id), 0o700)
	}
	if err == nil {
		tmp := filepath.Join(s.jobDir(j.info.Id), "job.json.tmp")
		if err = os.WriteFile(tmp, b, 0o600); err == nil {
			err = os.Rename(tmp, filepath.Join(s.jobDir(j.info.Id), "job.json"))
		}
	}
	if err != nil {
		s.log.Warn("save job", "job", j.info.Id, "err", err)
	}
}
