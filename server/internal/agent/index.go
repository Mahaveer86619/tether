package agent

import (
	"bufio"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Index tracks the sessions Claude Code has written under ~/.claude/projects,
// reading each transcript incrementally. It never writes to those files.
type Index struct {
	dir string

	mu    sync.Mutex
	files map[string]*transcript
}

type transcript struct {
	path string
	size int64
	mod  time.Time
	off  int64
	meta meta
	// Token usage per message id, and the ones the hub hasn't been told yet.
	usage  map[string]*v1.UsageEntry
	unsent map[string]bool
}

type meta struct {
	cwd, branch, version, model string
	aiTitle, customTitle        string
	firstPrompt, lastPrompt     string
	created                     int64
	count                       int32
}

type metaLine struct {
	Type        string `json:"type"`
	Timestamp   string `json:"timestamp"`
	IsMeta      bool   `json:"isMeta"`
	IsSidechain bool   `json:"isSidechain"`
	Cwd         string `json:"cwd"`
	GitBranch   string `json:"gitBranch"`
	Version     string `json:"version"`
	AITitle     string `json:"aiTitle"`
	CustomTitle string `json:"customTitle"`
	LastPrompt  string `json:"lastPrompt"`
	Message     struct {
		ID      string          `json:"id"`
		Model   string          `json:"model"`
		Content json.RawMessage `json:"content"`
		Usage   *struct {
			Input      int64 `json:"input_tokens"`
			Output     int64 `json:"output_tokens"`
			CacheWrite int64 `json:"cache_creation_input_tokens"`
			CacheRead  int64 `json:"cache_read_input_tokens"`
		} `json:"usage"`
	} `json:"message"`
}

func NewIndex(dir string) *Index {
	return &Index{dir: dir, files: map[string]*transcript{}}
}

// Scan picks up new and changed transcripts and returns the sessions
// whose transcripts were deleted since the last scan.
func (ix *Index) Scan() ([]string, error) {
	paths, err := filepath.Glob(filepath.Join(ix.dir, "*", "*.jsonl"))
	if err != nil {
		return nil, err
	}
	seen := map[string]bool{}
	for _, p := range paths {
		id := strings.TrimSuffix(filepath.Base(p), ".jsonl")
		seen[id] = true
		st, err := os.Stat(p)
		if err != nil {
			continue
		}
		ix.mu.Lock()
		t := ix.files[id]
		ix.mu.Unlock()
		if t != nil && t.path == p && t.size == st.Size() && t.mod.Equal(st.ModTime()) {
			continue
		}
		if t == nil || t.path != p || st.Size() < t.off {
			t = &transcript{path: p}
		}
		if err := t.read(); err != nil {
			continue
		}
		t.size, t.mod = st.Size(), st.ModTime()
		ix.mu.Lock()
		ix.files[id] = t
		ix.mu.Unlock()
	}
	var removed []string
	ix.mu.Lock()
	for id := range ix.files {
		if !seen[id] {
			delete(ix.files, id)
			removed = append(removed, id)
		}
	}
	ix.mu.Unlock()
	return removed, nil
}

func (t *transcript) read() error {
	f, err := os.Open(t.path)
	if err != nil {
		return err
	}
	defer f.Close()
	if _, err := f.Seek(t.off, io.SeekStart); err != nil {
		return err
	}
	r := bufio.NewReaderSize(f, 1<<20)
	for {
		line, err := r.ReadBytes('\n')
		if err != nil {
			// A partial last line is still being written; read it next time.
			return nil
		}
		t.off += int64(len(line))
		if u := t.meta.add(line); u != nil {
			if t.usage == nil {
				t.usage, t.unsent = map[string]*v1.UsageEntry{}, map[string]bool{}
			}
			// A message spans several lines; the later ones carry the final counts.
			t.usage[u.MessageId] = u
			t.unsent[u.MessageId] = true
		}
	}
}

// add folds one transcript line into the metadata, and returns the token
// usage it carries, if it's an assistant message.
func (m *meta) add(line []byte) *v1.UsageEntry {
	var l metaLine
	if json.Unmarshal(line, &l) != nil {
		return nil
	}
	if m.created == 0 {
		if ts, err := time.Parse(time.RFC3339Nano, l.Timestamp); err == nil {
			m.created = ts.UnixMilli()
		}
	}
	// The folder a session started in: the shell may cd elsewhere later, but
	// the transcript (and claude --resume) stay with the first one.
	if m.cwd == "" && l.Cwd != "" {
		m.cwd = l.Cwd
	}
	if l.GitBranch != "" {
		m.branch = l.GitBranch
	}
	if l.Version != "" {
		m.version = l.Version
	}
	switch l.Type {
	case "ai-title":
		m.aiTitle = l.AITitle
	case "custom-title":
		m.customTitle = l.CustomTitle
	case "last-prompt":
		m.lastPrompt = l.LastPrompt
	case "assistant":
		var usage *v1.UsageEntry
		// Sub-agents' usage counts too, though their messages don't.
		if u := l.Message.Usage; u != nil && l.Message.ID != "" && l.Message.Model != "<synthetic>" {
			usage = &v1.UsageEntry{
				MessageId: l.Message.ID, Model: l.Message.Model,
				Input: u.Input, Output: u.Output, CacheWrite: u.CacheWrite, CacheRead: u.CacheRead,
			}
			if ts, err := time.Parse(time.RFC3339Nano, l.Timestamp); err == nil {
				usage.TsMs = ts.UnixMilli()
			}
		}
		if l.IsSidechain {
			return usage
		}
		m.count++
		if l.Message.Model != "" && l.Message.Model != "<synthetic>" {
			m.model = l.Message.Model
		}
		return usage
	case "user":
		if l.IsSidechain || l.IsMeta {
			return nil
		}
		var s string
		if json.Unmarshal(l.Message.Content, &s) != nil {
			return nil
		}
		m.count++
		if m.firstPrompt == "" && !strings.HasPrefix(strings.TrimSpace(s), "<") {
			m.firstPrompt = s
		}
	}
	return nil
}

// Path returns the transcript file for a session, if known.
func (ix *Index) Path(id string) string {
	ix.mu.Lock()
	defer ix.mu.Unlock()
	if t := ix.files[id]; t != nil {
		return t.path
	}
	return ""
}

func (ix *Index) Cwd(id string) string {
	ix.mu.Lock()
	defer ix.mu.Unlock()
	if t := ix.files[id]; t != nil {
		return t.meta.cwd
	}
	return ""
}

// Modified reports when the transcript was last written.
func (ix *Index) Modified(id string) (time.Time, bool) {
	ix.mu.Lock()
	defer ix.mu.Unlock()
	if t := ix.files[id]; t != nil {
		return t.mod, true
	}
	return time.Time{}, false
}

// IDs lists sessions with at least one message.
func (ix *Index) IDs() []string {
	ix.mu.Lock()
	defer ix.mu.Unlock()
	var out []string
	for id, t := range ix.files {
		if t.meta.count > 0 {
			out = append(out, id)
		}
	}
	return out
}

// Info describes a session; state is filled in by the caller.
func (ix *Index) Info(id string) *v1.SessionInfo {
	ix.mu.Lock()
	defer ix.mu.Unlock()
	t := ix.files[id]
	if t == nil {
		return nil
	}
	m := t.meta
	return &v1.SessionInfo{
		Id:            id,
		Title:         firstNonEmpty(m.customTitle, m.aiTitle, clip(m.firstPrompt, 80)),
		Cwd:           m.cwd,
		GitBranch:     m.branch,
		CreatedMs:     m.created,
		UpdatedMs:     t.mod.UnixMilli(),
		MessageCount:  m.count,
		LastPrompt:    clip(firstNonEmpty(m.lastPrompt, m.firstPrompt), 200),
		ClaudeVersion: m.version,
		Model:         m.model,
	}
}

func clip(s string, n int) string {
	s = strings.Join(strings.Fields(s), " ")
	if r := []rune(s); len(r) > n {
		return string(r[:n-1]) + "…"
	}
	return s
}

func firstNonEmpty(ss ...string) string {
	for _, s := range ss {
		if s != "" {
			return s
		}
	}
	return ""
}

// TakeUsage returns the token usage not handed over yet, or all of it
// (for a fresh hub connection, which may have missed earlier reports).
func (ix *Index) TakeUsage(all bool) []*v1.UsageEntry {
	ix.mu.Lock()
	defer ix.mu.Unlock()
	var out []*v1.UsageEntry
	for id, t := range ix.files {
		for msg, u := range t.usage {
			if all || t.unsent[msg] {
				u.Session = id
				out = append(out, u)
			}
		}
		clear(t.unsent)
	}
	return out
}
