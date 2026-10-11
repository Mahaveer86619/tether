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
		Model   string          `json:"model"`
		Content json.RawMessage `json:"content"`
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
		t.meta.add(line)
	}
}

func (m *meta) add(line []byte) {
	var l metaLine
	if json.Unmarshal(line, &l) != nil {
		return
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
		if l.IsSidechain {
			return
		}
		m.count++
		if l.Message.Model != "" && l.Message.Model != "<synthetic>" {
			m.model = l.Message.Model
		}
	case "user":
		if l.IsSidechain || l.IsMeta {
			return
		}
		var s string
		if json.Unmarshal(l.Message.Content, &s) != nil {
			return
		}
		m.count++
		if m.firstPrompt == "" && !strings.HasPrefix(strings.TrimSpace(s), "<") {
			m.firstPrompt = s
		}
	}
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
