package hub

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/render"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

// History: the hub keeps every session's transcript, sent by the agents in
// chunks and resumed by byte offset, as an append-only copy of the lines
// (redacted) plus events in the database for timelines, search and export.
// The app reads history only from here. See docs/history.md.

const (
	// The first bytes of a file the hub remembers, to tell a rewrite.
	historyHead     = 4096
	historySyncEvery = 5 * time.Minute
	historyTextMax  = 4000
	toolResultMax   = 2000
)

var (
	safeSession = regexp.MustCompile(`^[A-Za-z0-9-]{8,64}$`)
	safeSubfile = regexp.MustCompile(`^subagents/[A-Za-z0-9._-]{1,128}\.jsonl$`)
)

func (h *Hub) historyDir() string { return filepath.Join(h.cfg.DataDir, "history") }

// rawPath is where the hub keeps its copy of a transcript file.
func (h *Hub) rawPath(session, file string) string {
	if file == "" {
		file = "transcript.jsonl"
	}
	return filepath.Join(h.historyDir(), session, filepath.FromSlash(file))
}

// historyPositions is what the hub has of a node's files. Caller holds h.mu.
func (h *Hub) historyPositions(node string) []*v1.HistoryPosition {
	files, err := h.store.HistoryFiles(node)
	if err != nil {
		h.log.Error("history files", "node", node, "err", err)
		return nil
	}
	out := make([]*v1.HistoryPosition, 0, len(files))
	for _, f := range files {
		sum := sha256.Sum256(f.Head)
		out = append(out, &v1.HistoryPosition{Session: f.Session, File: f.File, Offset: f.Offset, Head: hex.EncodeToString(sum[:]), HeadLen: int64(len(f.Head))})
	}
	return out
}

// requestHistory asks an agent for what the history lacks. Caller holds h.mu.
func (h *Hub) requestHistory(node string) {
	if agent := h.agents[node]; agent != nil && h.agentAtLeast(node, historySyncVersion) {
		agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_SyncHistory_{SyncHistory: &v1.AgentCommand_SyncHistory{Positions: h.historyPositions(node)}}}))
	}
}

// The first agent that sends its transcripts for the history.
const historySyncVersion = "0.17.0"

func (h *Hub) historyLoop(ctx context.Context) {
	h.importBackups(ctx)
	sync := time.NewTicker(historySyncEvery)
	defer sync.Stop()
	retention := time.NewTicker(retentionEvery)
	defer retention.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-sync.C:
			h.mu.Lock()
			for node := range h.agents {
				h.requestHistory(node)
			}
			h.mu.Unlock()
		case <-retention.C:
			h.mu.Lock()
			h.applyHistoryRetention(time.Now())
			h.mu.Unlock()
		}
	}
}

// ingestChunk takes in a chunk and returns the offset the history has now
// for the file: the agent sends from there next. Caller holds h.mu.
func (h *Hub) ingestChunk(node string, c *v1.HistoryChunk) int64 {
	if !safeSession.MatchString(c.Session) || c.File != "" && !safeSubfile.MatchString(c.File) {
		return 0
	}
	f, err := h.store.HistoryFile(c.Session, c.File)
	if err != nil {
		h.log.Error("history file", "session", c.Session, "err", err)
		return c.Offset
	}
	if c.Reset_ && f != nil {
		if err := h.store.ResetHistoryFile(c.Session, c.File); err != nil {
			h.log.Error("reset history", "session", c.Session, "err", err)
			return f.Offset
		}
		_ = os.Remove(h.rawPath(c.Session, c.File))
		f = nil
	}
	if f == nil {
		if c.Offset != 0 {
			return 0
		}
		_ = os.Remove(h.rawPath(c.Session, c.File))
		f = &store.HistoryFile{Session: c.Session, File: c.File}
	}
	f.Node = node
	data, start := c.Data, c.Offset
	switch {
	case start > f.Offset:
		return f.Offset // a gap: the agent goes back
	case start < f.Offset:
		skip := f.Offset - start
		if skip >= int64(len(data))+c.Skip {
			return f.Offset // already have it
		}
		if skip > int64(len(data)) {
			c.Skip -= skip - int64(len(data))
			data = nil
		} else {
			data = data[skip:]
		}
		start = f.Offset
	}
	if len(f.Head) < historyHead && start == int64(len(f.Head)) {
		f.Head = append(f.Head, data[:min(len(data), historyHead-len(f.Head))]...)
	}
	events, raw := h.historyEvents(c.Session, node, data, start, &f.LastTs)
	if len(raw) > 0 {
		if err := appendFile(h.rawPath(c.Session, c.File), raw); err != nil {
			h.log.Error("history copy", "session", c.Session, "err", err)
			return f.Offset
		}
	}
	f.Offset = start + int64(len(data)) + c.Skip
	f.RawBytes += int64(len(raw))
	f.UpdatedMs = time.Now().UnixMilli()
	if err := h.store.AppendHistory(f, events); err != nil {
		h.log.Error("store history", "session", c.Session, "err", err)
	}
	return f.Offset
}

func appendFile(path string, b []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	_, err = f.Write(b)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	return err
}

// noteHistorySynced records when a node last had everything in the
// history. Caller holds h.mu.
func (h *Hub) noteHistorySynced(node string, at int64) {
	if n := h.nodes[node]; n != nil {
		next := proto.Clone(n).(*v1.NodeStatus)
		next.HistorySyncedMs = at
		h.putNode(next)
	}
}

// ---- lines to events ----

type histLine struct {
	Type        string          `json:"type"`
	UUID        string          `json:"uuid"`
	Timestamp   string          `json:"timestamp"`
	Cwd         string          `json:"cwd"`
	IsMeta      bool            `json:"isMeta"`
	Message     json.RawMessage `json:"message"`
	Summary     string          `json:"summary"`
	Content     json.RawMessage `json:"content"`
	Subtype     string          `json:"subtype"`
	Attachment  struct {
		Type   string          `json:"type"`
		Prompt json.RawMessage `json:"prompt"`
	} `json:"attachment"`
}

type histMessage struct {
	Model   string          `json:"model"`
	Content json.RawMessage `json:"content"`
}

type histBlock struct {
	Type    string          `json:"type"`
	Text    string          `json:"text"`
	Name    string          `json:"name"`
	Input   json.RawMessage `json:"input"`
	Content json.RawMessage `json:"content"`
}

// historyEvents turns whole lines into events, and returns the lines as the
// hub keeps them (redacted when set to). lastTs carries the newest time
// seen, for lines with none.
func (h *Hub) historyEvents(session, node string, data []byte, start int64, lastTs *int64) ([]*v1.HistoryEvent, []byte) {
	var events []*v1.HistoryEvent
	raw := make([]byte, 0, len(data))
	offset := start
	for len(data) > 0 {
		line := data
		if i := bytes.IndexByte(data, '\n'); i >= 0 {
			line = data[:i+1]
		}
		data = data[len(line):]
		lineOffset := offset
		offset += int64(len(line))
		kept, redacted := line, false
		if h.cfg.HistoryRedact {
			kept, redacted = redactBytes(line)
		}
		raw = append(raw, kept...)
		e := lineEvent(bytes.TrimSpace(line))
		if e == nil {
			continue
		}
		if e.TsMs == 0 {
			e.TsMs = *lastTs
		} else {
			*lastTs = e.TsMs
		}
		e.Session, e.Node, e.Offset = session, node, lineOffset
		if h.cfg.HistoryRedact {
			var r bool
			e.Text, r = redactString(e.Text)
			e.Redacted = redacted || r
		}
		events = append(events, e)
	}
	return events, raw
}

// lineEvent is the event a transcript line makes, or nil for lines that
// aren't part of the conversation (snapshots, bookkeeping).
func lineEvent(line []byte) *v1.HistoryEvent {
	if len(line) == 0 {
		return nil
	}
	var l histLine
	if json.Unmarshal(line, &l) != nil {
		return nil
	}
	e := &v1.HistoryEvent{EventId: l.UUID, Cwd: l.Cwd}
	if t, err := time.Parse(time.RFC3339Nano, l.Timestamp); err == nil {
		e.TsMs = t.UnixMilli()
	}
	switch l.Type {
	case "user":
		if l.IsMeta {
			return nil
		}
		var m histMessage
		_ = json.Unmarshal(l.Message, &m)
		texts, results := userParts(m.Content)
		switch {
		case texts != "":
			e.Kind, e.Text = "user", texts
		case results != "":
			e.Kind, e.Text = "tool_result", results
		default:
			return nil
		}
	case "assistant":
		var m histMessage
		_ = json.Unmarshal(l.Message, &m)
		e.Model = m.Model
		var blocks []histBlock
		if json.Unmarshal(m.Content, &blocks) != nil {
			return nil
		}
		var texts, tools, names []string
		for _, b := range blocks {
			switch b.Type {
			case "text":
				if t := strings.TrimSpace(b.Text); t != "" {
					texts = append(texts, t)
				}
			case "tool_use":
				names = append(names, b.Name)
				tools = append(tools, b.Name+": "+toolInput(b.Name, b.Input))
			}
		}
		e.Tool = strings.Join(names, ",")
		switch {
		case len(texts) > 0:
			e.Kind, e.Text = "assistant", strings.Join(texts, "\n\n")
		case len(tools) > 0:
			e.Kind, e.Text = "tool_use", strings.Join(tools, "\n")
		default:
			return nil
		}
	case "summary":
		e.Kind, e.Text = "summary", l.Summary
	case "system":
		var text string
		_ = json.Unmarshal(l.Content, &text)
		if strings.TrimSpace(text) == "" {
			return nil
		}
		e.Kind, e.Text = "system", text
	case "attachment":
		if l.Attachment.Type != "queued_command" {
			return nil
		}
		var text string
		if json.Unmarshal(l.Attachment.Prompt, &text) != nil || strings.TrimSpace(text) == "" {
			return nil
		}
		e.Kind, e.Text = "user", text
	default:
		return nil
	}
	e.Text, _ = render.Unpaste(e.Text)
	e.Text = clipText(e.Text, historyTextMax)
	return e
}

// userParts is a user message's own words, and its tool results.
func userParts(content json.RawMessage) (string, string) {
	var s string
	if json.Unmarshal(content, &s) == nil {
		return strings.TrimSpace(s), ""
	}
	var blocks []histBlock
	if json.Unmarshal(content, &blocks) != nil {
		return "", ""
	}
	var texts, results []string
	for _, b := range blocks {
		switch b.Type {
		case "text":
			if t := strings.TrimSpace(b.Text); t != "" && !strings.HasPrefix(t, "<system-reminder>") {
				texts = append(texts, t)
			}
		case "tool_result":
			if t := resultText(b.Content); t != "" {
				results = append(results, clipText(t, toolResultMax))
			}
		}
	}
	return strings.Join(texts, "\n\n"), strings.Join(results, "\n\n")
}

func resultText(content json.RawMessage) string {
	var s string
	if json.Unmarshal(content, &s) == nil {
		return strings.TrimSpace(s)
	}
	var blocks []histBlock
	if json.Unmarshal(content, &blocks) != nil {
		return ""
	}
	var parts []string
	for _, b := range blocks {
		if b.Type == "text" && strings.TrimSpace(b.Text) != "" {
			parts = append(parts, strings.TrimSpace(b.Text))
		}
	}
	return strings.Join(parts, "\n")
}

// toolInput is a tool call's input in a line: the command, file or pattern.
func toolInput(name string, input json.RawMessage) string {
	var in map[string]any
	if json.Unmarshal(input, &in) != nil {
		return ""
	}
	for _, k := range []string{"command", "file_path", "path", "pattern", "url", "query", "description", "prompt"} {
		if v, ok := in[k].(string); ok && v != "" {
			return clip(strings.ReplaceAll(v, "\n", " "), 300)
		}
	}
	return clip(string(input), 300)
}

// ---- redaction ----

// Secrets taken out of stored history: the match is replaced by
// [REDACTED:<kind>], which keeps a JSON line valid.
var secretPatterns = []struct {
	kind string
	re   *regexp.Regexp
	keep int // leading submatch groups kept, e.g. "password="
}{
	{"private-key", regexp.MustCompile(`-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----`), 0},
	{"anthropic-key", regexp.MustCompile(`sk-ant-[A-Za-z0-9_-]{20,}`), 0},
	{"openai-key", regexp.MustCompile(`sk-(?:proj-)?[A-Za-z0-9_-]{32,}`), 0},
	{"github-token", regexp.MustCompile(`(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})`), 0},
	{"aws-key", regexp.MustCompile(`(?:AKIA|ASIA)[0-9A-Z]{16}`), 0},
	{"google-key", regexp.MustCompile(`AIza[0-9A-Za-z_-]{35}`), 0},
	{"slack-token", regexp.MustCompile(`xox[baprs]-[A-Za-z0-9-]{10,}`), 0},
	{"jwt", regexp.MustCompile(`eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}`), 0},
	{"secret", regexp.MustCompile(`(?i)((?:password|passwd|secret|token|api[_-]?key|access[_-]?token|auth[_-]?token)(?:\\?["'])?\s*[:=]\s*(?:\\?["'])?)([^\s"'\\,;]{8,})`), 1},
}

func redactString(s string) (string, bool) {
	changed := false
	for _, p := range secretPatterns {
		s = p.re.ReplaceAllStringFunc(s, func(m string) string {
			changed = true
			if p.keep > 0 {
				sub := p.re.FindStringSubmatch(m)
				return sub[1] + "[REDACTED:" + p.kind + "]"
			}
			return "[REDACTED:" + p.kind + "]"
		})
	}
	return s, changed
}

func redactBytes(b []byte) ([]byte, bool) {
	s, changed := redactString(string(b))
	if !changed {
		return b, false
	}
	return []byte(s), true
}

// ---- backfill and retention ----

const backfillKey = "history_backfill_v1"

// importBackups takes the transcripts the hub already backed up into the
// history once, so agents only send what came after them.
func (h *Hub) importBackups(ctx context.Context) {
	h.mu.Lock()
	done, _ := h.store.Get(backfillKey)
	h.mu.Unlock()
	if done != nil {
		return
	}
	h.mu.Lock()
	list, err := h.store.BackupFiles()
	h.mu.Unlock()
	if err != nil {
		h.log.Error("list backups", "err", err)
		return
	}
	imported := 0
	for _, a := range list {
		if ctx.Err() != nil {
			return
		}
		file := ""
		if a.Path != backupTranscript {
			if !strings.HasPrefix(a.Path, "subagents/") {
				continue
			}
			file = a.Path
		}
		h.mu.Lock()
		info := h.sessions[a.Session]
		have, _ := h.store.HistoryFile(a.Session, file)
		h.mu.Unlock()
		if info == nil || have != nil {
			continue
		}
		if err := h.importFile(info.Node, a.Session, file, h.blobPath(a.Sha256)); err != nil {
			h.log.Warn("import backup into history", "session", a.Session, "file", file, "err", err)
			continue
		}
		imported++
	}
	h.mu.Lock()
	_ = h.store.Put(backfillKey, []byte(time.Now().Format(time.RFC3339)))
	h.mu.Unlock()
	h.log.Info("history: imported backups", "files", imported)
}

// importFile feeds a stored copy of a transcript to the history in chunks
// of whole lines, taking the lock per chunk. A last line without its line
// break is left for the agent to send.
func (h *Hub) importFile(node, session, file, path string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	r := bufio.NewReaderSize(f, 64<<10)
	var offset int64
	var chunk []byte
	flush := func() {
		if len(chunk) > 0 {
			h.mu.Lock()
			offset = h.ingestChunk(node, &v1.HistoryChunk{Session: session, File: file, Offset: offset, Data: chunk})
			h.mu.Unlock()
			chunk = chunk[:0]
		}
	}
	for {
		line, err := r.ReadBytes('\n')
		if err == nil {
			chunk = append(chunk, line...)
			if len(chunk) >= historyChunk {
				flush()
			}
			continue
		}
		flush()
		if err == io.EOF {
			return nil
		}
		return err
	}
}

// The most a chunk holds, unless a single line is longer.
const historyChunk = 256 << 10

// applyHistoryRetention drops the history of sessions untouched for longer
// than the retention, then the oldest until it fits the size limit.
// Caller holds h.mu.
func (h *Hub) applyHistoryRetention(now time.Time) {
	if h.cfg.HistoryKeepDays <= 0 && h.cfg.HistoryMaxMB <= 0 {
		return
	}
	ids, updated, sizes, err := h.store.HistorySessionsByAge()
	if err != nil {
		h.log.Error("history retention", "err", err)
		return
	}
	var total int64
	for _, b := range sizes {
		total += b
	}
	cutoff := now.Add(-time.Duration(h.cfg.HistoryKeepDays) * 24 * time.Hour).UnixMilli()
	limit := int64(h.cfg.HistoryMaxMB) << 20
	for i, id := range ids {
		old := h.cfg.HistoryKeepDays > 0 && updated[i] < cutoff
		big := h.cfg.HistoryMaxMB > 0 && total > limit
		if !old && !big {
			break
		}
		if err := h.store.DeleteHistory(id); err != nil {
			h.log.Error("drop history", "session", id, "err", err)
			continue
		}
		_ = os.RemoveAll(filepath.Join(h.historyDir(), id))
		total -= sizes[i]
		h.log.Info("history: dropped", "session", id, "old", old, "over_size", big)
	}
}

// stateFile holds the hub's own events for a session: its state changes.
const stateFile = "@hub"

// noteStateEvent records a session's change of state in its history.
// Caller holds h.mu.
func (h *Hub) noteStateEvent(s *v1.SessionInfo) {
	f, err := h.store.HistoryFile(s.Id, stateFile)
	if err != nil {
		return
	}
	if f == nil {
		f = &store.HistoryFile{Session: s.Id, File: stateFile}
	}
	now := time.Now().UnixMilli()
	f.Node, f.LastTs, f.UpdatedMs = s.Node, now, now
	e := &v1.HistoryEvent{Offset: f.Offset, TsMs: now, Kind: "state", Text: stateName(s.State), Model: s.Model, Cwd: s.Cwd}
	f.Offset++
	if err := h.store.AppendHistory(f, []*v1.HistoryEvent{e}); err != nil {
		h.log.Error("history state", "session", s.Id, "err", err)
	}
}

// clipText cuts text to n runes, keeping its line breaks and spacing.
func clipText(s string, n int) string {
	if len(s) <= n {
		return s
	}
	if r := []rune(s); len(r) > n {
		return string(r[:n-1]) + "…"
	}
	return s
}
