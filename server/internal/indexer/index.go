package indexer

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
	files map[string]*Transcript
}

// Transcript tracks one session's transcript file and parsed metadata.
type Transcript struct {
	Path   string
	Size   int64
	Mod    time.Time
	Off    int64
	Meta   Meta
	Usage  map[string]*v1.UsageEntry
	Unsent map[string]bool
}

// Meta holds the session metadata collected from transcript events.
type Meta struct {
	Cwd, Branch, Version, Model string
	AiTitle, CustomTitle        string
	FirstPrompt, LastPrompt     string
	Created                     int64
	Count                       int32
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

// New creates an Index scanning the given projects directory.
func New(dir string) *Index {
	return &Index{dir: dir, files: map[string]*Transcript{}}
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
		if t != nil && t.Path == p && t.Size == st.Size() && t.Mod.Equal(st.ModTime()) {
			continue
		}
		if t == nil || t.Path != p || st.Size() < t.Off {
			t = &Transcript{Path: p}
		}
		if err := t.read(); err != nil {
			continue
		}
		t.Size, t.Mod = st.Size(), st.ModTime()
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

func (t *Transcript) read() error {
	f, err := os.Open(t.Path)
	if err != nil {
		return err
	}
	defer f.Close()
	if _, err := f.Seek(t.Off, io.SeekStart); err != nil {
		return err
	}
	r := bufio.NewReaderSize(f, 1<<20)
	for {
		line, err := r.ReadBytes('\n')
		if err != nil {
			// A partial last line is still being written; read it next time.
			return nil
		}
		t.Off += int64(len(line))
		if u := t.Meta.Add(line); u != nil {
			if t.Usage == nil {
				t.Usage, t.Unsent = map[string]*v1.UsageEntry{}, map[string]bool{}
			}
			// A message spans several lines; the later ones carry the final counts.
			t.Usage[u.MessageId] = u
			t.Unsent[u.MessageId] = true
		}
	}
}

// Add folds one transcript line into the metadata, and returns the token
// usage it carries, if it's an assistant message.
func (m *Meta) Add(line []byte) *v1.UsageEntry {
	var l metaLine
	if json.Unmarshal(line, &l) != nil {
		return nil
	}
	if m.Created == 0 {
		if ts, err := time.Parse(time.RFC3339Nano, l.Timestamp); err == nil {
			m.Created = ts.UnixMilli()
		}
	}
	// The folder a session started in: the shell may cd elsewhere later, but
	// the transcript (and claude --resume) stay with the first one.
	if m.Cwd == "" && l.Cwd != "" {
		m.Cwd = l.Cwd
	}
	if l.GitBranch != "" {
		m.Branch = l.GitBranch
	}
	if l.Version != "" {
		m.Version = l.Version
	}
	switch l.Type {
	case "ai-title":
		m.AiTitle = l.AITitle
	case "custom-title":
		m.CustomTitle = l.CustomTitle
	case "last-prompt":
		m.LastPrompt = l.LastPrompt
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
		m.Count++
		if l.Message.Model != "" && l.Message.Model != "<synthetic>" {
			m.Model = l.Message.Model
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
		m.Count++
		if m.FirstPrompt == "" && !strings.HasPrefix(strings.TrimSpace(s), "<") {
			m.FirstPrompt = s
		}
	}
	return nil
}

// Path returns the transcript file for a session, if known.
func (ix *Index) Path(id string) string {
	ix.mu.Lock()
	defer ix.mu.Unlock()
	if t := ix.files[id]; t != nil {
		return t.Path
	}
	return ""
}

// Cwd returns the working directory a session started in, if known.
func (ix *Index) Cwd(id string) string {
	ix.mu.Lock()
	defer ix.mu.Unlock()
	if t := ix.files[id]; t != nil {
		return t.Meta.Cwd
	}
	return ""
}

// Modified reports when the transcript was last written.
func (ix *Index) Modified(id string) (time.Time, bool) {
	ix.mu.Lock()
	defer ix.mu.Unlock()
	if t := ix.files[id]; t != nil {
		return t.Mod, true
	}
	return time.Time{}, false
}

// IDs lists sessions with at least one message.
func (ix *Index) IDs() []string {
	ix.mu.Lock()
	defer ix.mu.Unlock()
	var out []string
	for id, t := range ix.files {
		if t.Meta.Count > 0 {
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
	m := t.Meta
	return &v1.SessionInfo{
		Id:            id,
		Title:         firstNonEmpty(m.CustomTitle, m.AiTitle, clip(m.FirstPrompt, 80)),
		Cwd:           m.Cwd,
		GitBranch:     m.Branch,
		CreatedMs:     m.Created,
		UpdatedMs:     t.Mod.UnixMilli(),
		MessageCount:  m.Count,
		LastPrompt:    clip(firstNonEmpty(m.LastPrompt, m.FirstPrompt), 200),
		ClaudeVersion: m.Version,
		Model:         m.Model,
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
		for msg, u := range t.Usage {
			if all || t.Unsent[msg] {
				u.Session = id
				out = append(out, u)
			}
		}
		clear(t.Unsent)
	}
	return out
}
