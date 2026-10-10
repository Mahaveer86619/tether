package agent

import (
	"bufio"
	"encoding/json"
	"errors"
	"io"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

const (
	approvalTimeout = 30 * time.Minute
	stderrKeep      = 4 << 10
	batchLines      = 64
)

// run is one headless `claude -p` process in stream-json mode. It stays
// alive between turns so follow-up messages reuse it.
type run struct {
	a  *Agent
	id string

	cmd   *exec.Cmd
	stdin io.WriteCloser

	mu         sync.Mutex
	state      v1.SessionState
	errText    string
	approvals  map[string]json.RawMessage
	lastActive time.Time
	stderr     tailBuffer
	done       chan struct{}
}

type startOpts struct {
	session, cwd, prompt, model, permissionMode, name, resume string
	fork                                                      bool
}

func (a *Agent) startRun(o startOpts) (*run, error) {
	args := []string{
		"-p",
		"--output-format", "stream-json",
		"--input-format", "stream-json",
		"--include-partial-messages",
		"--verbose",
		"--replay-user-messages",
		"--permission-prompt-tool", "stdio",
	}
	args = append(args, sessionArgs(o)...)

	cmd := exec.Command(a.cfg.Claude, args...)
	cmd.Dir = o.cwd
	hideWindow(cmd)
	r := &run{a: a, id: o.session, cmd: cmd, approvals: map[string]json.RawMessage{}, lastActive: time.Now(), done: make(chan struct{})}
	cmd.Stderr = &r.stderr
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	r.stdin = stdin
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	a.log.Info("run started", "session", o.session, "cwd", o.cwd, "resume", o.resume, "fork", o.fork)
	go r.readLoop(stdout)
	go r.wait()
	return r, nil
}

func (r *run) setState(s v1.SessionState) {
	r.mu.Lock()
	r.state = s
	r.lastActive = time.Now()
	r.mu.Unlock()
	r.a.report(r.id)
}

func (r *run) State() (v1.SessionState, string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.state, r.errText
}

func (r *run) send(text string) error {
	r.setState(v1.SessionState_SESSION_STATE_RUNNING)
	return r.write(map[string]any{
		"type":    "user",
		"message": map[string]any{"role": "user", "content": text},
	})
}

func (r *run) interrupt() error {
	return r.write(map[string]any{
		"type":       "control_request",
		"request_id": uuid.NewString(),
		"request":    map[string]any{"subtype": "interrupt"},
	})
}

// answer resolves a permission prompt. It reports false if this run does
// not own the approval.
func (r *run) answer(approvalID string, allow bool, message string) bool {
	r.mu.Lock()
	input, ok := r.approvals[approvalID]
	delete(r.approvals, approvalID)
	r.mu.Unlock()
	if !ok {
		return false
	}
	resp := map[string]any{"behavior": "deny", "message": firstNonEmpty(message, "Denied from Tether")}
	if allow {
		resp = map[string]any{"behavior": "allow", "updatedInput": input}
	}
	err := r.write(map[string]any{
		"type": "control_response",
		"response": map[string]any{
			"subtype":    "success",
			"request_id": approvalID,
			"response":   resp,
		},
	})
	if err != nil {
		r.a.log.Error("answer approval", "session", r.id, "err", err)
	}
	r.setState(v1.SessionState_SESSION_STATE_RUNNING)
	return true
}

func (r *run) closeInput() { _ = r.stdin.Close() }

func (r *run) write(v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	_, err = r.stdin.Write(append(b, '\n'))
	return err
}

type controlLine struct {
	Type      string `json:"type"`
	RequestID string `json:"request_id"`
	Request   struct {
		Subtype     string          `json:"subtype"`
		ToolName    string          `json:"tool_name"`
		Input       json.RawMessage `json:"input"`
		Description string          `json:"description"`
	} `json:"request"`
}

func (r *run) readLoop(stdout io.Reader) {
	br := bufio.NewReaderSize(stdout, 1<<20)
	var batch []string
	flush := func() {
		if len(batch) > 0 {
			r.a.send(&v1.Frame{Body: &v1.Frame_RawEvents{RawEvents: &v1.RawEvents{
				Session: r.id, Source: v1.RawEvents_SOURCE_STREAM, Lines: batch,
			}}})
			batch = nil
		}
	}
	for {
		line, err := br.ReadBytes('\n')
		if len(line) > 0 {
			if fwd := r.handleLine(line); fwd {
				batch = append(batch, strings.TrimRight(string(line), "\r\n"))
			}
		}
		// Batch only what is already buffered so live output is never held back.
		if err != nil || br.Buffered() == 0 || len(batch) >= batchLines {
			flush()
		}
		if err != nil {
			return
		}
	}
}

// handleLine reacts to control traffic and reports whether the line should
// be forwarded to the hub.
func (r *run) handleLine(line []byte) bool {
	var c controlLine
	if json.Unmarshal(line, &c) != nil {
		return false
	}
	switch c.Type {
	case "control_request":
		if c.Request.Subtype != "can_use_tool" {
			_ = r.write(map[string]any{"type": "control_response", "response": map[string]any{
				"subtype": "error", "request_id": c.RequestID, "error": "unsupported by tether",
			}})
			return false
		}
		input := c.Request.Input
		if len(input) == 0 {
			input = json.RawMessage("{}")
		}
		r.mu.Lock()
		r.approvals[c.RequestID] = input
		r.mu.Unlock()
		r.setState(v1.SessionState_SESSION_STATE_AWAITING_APPROVAL)
		r.a.send(&v1.Frame{Body: &v1.Frame_ApprovalRequested{ApprovalRequested: &v1.ApprovalRequest{
			ApprovalId: c.RequestID, Session: r.id, ToolName: c.Request.ToolName,
			InputJson: string(input), Description: c.Request.Description,
		}}})
		go func(id string) {
			time.Sleep(approvalTimeout)
			r.answer(id, false, "Approval timed out")
		}(c.RequestID)
		return false
	case "control_response", "keep_alive":
		return false
	case "result":
		r.setState(v1.SessionState_SESSION_STATE_READY)
	}
	return true
}

func (r *run) wait() {
	err := r.cmd.Wait()
	close(r.done)
	r.mu.Lock()
	switch {
	case err != nil && r.state != v1.SessionState_SESSION_STATE_READY:
		r.state = v1.SessionState_SESSION_STATE_ERROR
		r.errText = firstNonEmpty(strings.TrimSpace(r.stderr.String()), err.Error())
	default:
		r.state = v1.SessionState_SESSION_STATE_IDLE
	}
	r.mu.Unlock()
	r.a.log.Info("run ended", "session", r.id, "err", err)
	r.a.endRun(r)
}

// tailBuffer keeps the last few KB written to it.
type tailBuffer struct {
	mu  sync.Mutex
	buf []byte
}

func (t *tailBuffer) Write(p []byte) (int, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.buf = append(t.buf, p...)
	if len(t.buf) > stderrKeep {
		t.buf = t.buf[len(t.buf)-stderrKeep:]
	}
	return len(p), nil
}

func (t *tailBuffer) String() string {
	t.mu.Lock()
	defer t.mu.Unlock()
	return string(t.buf)
}

var errTerminalActive = errors.New("session is open in a terminal; fork it instead")
