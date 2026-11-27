package agent

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os/exec"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// startLineRun launches a CLI that takes one prompt and writes plain text.
// Its output is wrapped in stream-json so the hub can render it with the same
// timeline builder it uses for Claude Code, without teaching clients a second
// format.
func (a *Agent) startLineRun(o startOpts) (*run, error) {
	args := append([]string{}, o.profile.Args...)
	if o.model != "" {
		args = append(args, "--model", o.model)
	}
	prompt := o.prompt
	if o.systemPrompt != "" {
		prompt = o.systemPrompt + "\n\n" + prompt
	}
	args = append(args, prompt)

	cmd := exec.Command(o.profile.Command, args...)
	cmd.Dir = o.cwd
	hideWindow(cmd)
	r := &run{a: a, id: o.session, cmd: cmd, approvals: map[string]json.RawMessage{}, lastActive: time.Now(), done: make(chan struct{}), generic: true}
	cmd.Stderr = &r.stderr
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	a.log.Info("line run started", "session", o.session, "profile", o.profile.Id, "command", o.profile.Command, "cwd", o.cwd)
	r.setState(v1.SessionState_SESSION_STATE_RUNNING)
	go r.lineLoop(stdout)
	go r.wait()
	return r, nil
}

func (r *run) lineLoop(stdout io.Reader) {
	br := bufio.NewReaderSize(stdout, 1<<20)
	lineNo := 0
	var batch []string
	flush := func() {
		if len(batch) == 0 {
			return
		}
		r.a.send(&v1.Frame{Body: &v1.Frame_RawEvents{RawEvents: &v1.RawEvents{
			Session: r.id, Source: v1.RawEvents_SOURCE_STREAM, Lines: batch,
		}}})
		batch = nil
	}
	for {
		line, err := br.ReadBytes('\n')
		if len(line) > 0 {
			text := strings.TrimRight(string(line), "\r\n")
			if strings.TrimSpace(text) != "" {
				lineNo++
				batch = append(batch, lineEvent(r.id, lineNo, text))
			}
		}
		if err != nil || br.Buffered() == 0 || len(batch) >= batchLines {
			flush()
		}
		if err != nil {
			break
		}
	}
	lineNo++
	batch = append(batch, lineResult(r.id, lineNo))
	flush()
}

func lineEvent(session string, n int, text string) string {
	b, _ := json.Marshal(map[string]any{
		"type": "assistant",
		"uuid": fmt.Sprintf("%s-line-%d", session, n),
		"message": map[string]any{
			"id":      fmt.Sprintf("%s-msg-%d", session, n),
			"content": []map[string]any{{"type": "text", "text": text}},
		},
	})
	return string(b)
}

func lineResult(session string, n int) string {
	b, _ := json.Marshal(map[string]any{
		"type": "result", "uuid": fmt.Sprintf("%s-result-%d", session, n),
		"subtype": "success", "is_error": false,
	})
	return string(b)
}
