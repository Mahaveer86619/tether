package main

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"sync"
)

type runner interface {
	Run(ctx context.Context, args ...string) (string, error)
}

type execRunner struct {
	bin string
}

func (r *execRunner) Run(ctx context.Context, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, r.bin, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		detail := strings.TrimSpace(stderr.String())
		if detail == "" {
			detail = strings.TrimSpace(stdout.String())
		}
		if detail != "" {
			return "", fmt.Errorf("%s %s: %w: %s", r.bin, strings.Join(args, " "), err, clip(detail, 200))
		}
		return "", fmt.Errorf("%s %s: %w", r.bin, strings.Join(args, " "), err)
	}
	return stdout.String(), nil
}

type herdrAdapter struct {
	runner  runner
	pane    string
	source  string
	agent   string
	verbose bool

	mu  sync.Mutex
	seq int64
}

func (a *herdrAdapter) enabled() bool {
	return a != nil && a.runner != nil && a.pane != ""
}

func (a *herdrAdapter) nextSeq() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.seq++
	return strconv.FormatInt(a.seq, 10)
}

func (a *herdrAdapter) reportAgent(ctx context.Context, state, message, sessionID string) error {
	if !a.enabled() {
		return nil
	}
	switch state {
	case "idle", "working", "blocked", "unknown":
	default:
		state = "unknown"
	}
	args := []string{"pane", "report-agent", a.pane, "--source", a.source, "--agent", a.agent, "--state", state, "--seq", a.nextSeq()}
	if message = clip(message, 80); message != "" {
		args = append(args, "--message", message)
	}
	if sessionID != "" {
		args = append(args, "--agent-session-id", sessionID)
	}
	_, err := a.runner.Run(ctx, args...)
	return err
}

func (a *herdrAdapter) reportMetadata(ctx context.Context, title string, tokens map[string]string) error {
	if !a.enabled() {
		return nil
	}
	args := []string{"pane", "report-metadata", a.pane, "--source", a.source, "--seq", a.nextSeq()}
	if title = clip(title, 80); title != "" {
		args = append(args, "--title", title)
	}
	keys := make([]string, 0, len(tokens))
	for k := range tokens {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		v := clip(strings.ReplaceAll(tokens[k], "\n", " "), 80)
		if v == "" {
			continue
		}
		args = append(args, "--token", k+"="+v)
	}
	_, err := a.runner.Run(ctx, args...)
	return err
}

func (a *herdrAdapter) logf(format string, args ...any) {
	if a != nil && a.verbose {
		fmt.Fprintf(os.Stderr, "tether-herdr: "+format+"\n", args...)
	}
}
