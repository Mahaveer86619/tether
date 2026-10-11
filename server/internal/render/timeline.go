package render

import (
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Patch carries session metadata learned from the event stream.
type Patch struct {
	Title    string
	Model    string
	Cwd      string
	Version  string
	Todos    []*v1.Todo
	TodosSet bool
	Cost     *float64
}

func (p *Patch) Empty() bool {
	return p.Title == "" && p.Model == "" && p.Cwd == "" && p.Version == "" && !p.TodosSet && p.Cost == nil
}

// Output is what one raw line produced.
type Output struct {
	Items []*v1.TimelineItem
	Patch Patch
	// Delta marks partial-text updates the caller may coalesce.
	Delta bool
}

// Builder turns Claude Code stream-json and transcript lines into timeline
// items. Both sources yield the same item ids, so a session can be fed from
// either, or both, and the result is idempotent.
type Builder struct {
	items    map[string]*v1.TimelineItem
	partials map[string]*strings.Builder
	curMsg   map[string]string
	blockIdx map[string]int
	// Stream and transcript share line uuids; reuse the index a line got first.
	lineIdx map[string]int
	// Lookup finds items the builder has not seen, e.g. after a hub restart.
	Lookup func(itemID string) *v1.TimelineItem
	now    func() time.Time
}

func NewBuilder() *Builder {
	return &Builder{
		items:    map[string]*v1.TimelineItem{},
		partials: map[string]*strings.Builder{},
		curMsg:   map[string]string{},
		blockIdx: map[string]int{},
		lineIdx:  map[string]int{},
		now:      time.Now,
	}
}

type rawLine struct {
	Type            string          `json:"type"`
	Subtype         string          `json:"subtype"`
	UUID            string          `json:"uuid"`
	Timestamp       string          `json:"timestamp"`
	IsMeta          bool            `json:"isMeta"`
	IsSidechain     bool            `json:"isSidechain"`
	ParentToolUseID string          `json:"parent_tool_use_id"`
	Message         json.RawMessage `json:"message"`
	Event           json.RawMessage `json:"event"`
	Content         json.RawMessage `json:"content"`
	Attachment      struct {
		Type        string `json:"type"`
		Prompt      string `json:"prompt"`
		CommandMode string `json:"commandMode"`
	} `json:"attachment"`

	Model       string `json:"model"`
	Cwd         string `json:"cwd"`
	Version     string `json:"claude_code_version"`
	AITitle     string `json:"aiTitle"`
	CustomTitle string `json:"customTitle"`

	IsError    bool    `json:"is_error"`
	NumTurns   int32   `json:"num_turns"`
	DurationMs int64   `json:"duration_ms"`
	Cost       float64 `json:"total_cost_usd"`
	Result     string  `json:"result"`
}

type message struct {
	ID      string          `json:"id"`
	Model   string          `json:"model"`
	Content json.RawMessage `json:"content"`
}

type contentBlock struct {
	Type      string          `json:"type"`
	Text      string          `json:"text"`
	Thinking  string          `json:"thinking"`
	ID        string          `json:"id"`
	Name      string          `json:"name"`
	Input     json.RawMessage `json:"input"`
	ToolUseID string          `json:"tool_use_id"`
	Content   json.RawMessage `json:"content"`
	IsError   bool            `json:"is_error"`
}

type streamEvent struct {
	Type    string `json:"type"`
	Index   int    `json:"index"`
	Message struct {
		ID string `json:"id"`
	} `json:"message"`
	ContentBlock contentBlock `json:"content_block"`
	Delta        struct {
		Type     string `json:"type"`
		Text     string `json:"text"`
		Thinking string `json:"thinking"`
	} `json:"delta"`
}

// Feed processes one JSON line.
func (b *Builder) Feed(line []byte) Output {
	var out Output
	var l rawLine
	if json.Unmarshal(line, &l) != nil {
		return out
	}
	ts := b.now().UnixMilli()
	if t, err := time.Parse(time.RFC3339Nano, l.Timestamp); err == nil {
		ts = t.UnixMilli()
	}
	emit := func(it *v1.TimelineItem) {
		it.TsMs = ts
		it.ParentToolUseId = l.ParentToolUseID
		b.items[it.ItemId] = it
		out.Items = append(out.Items, it)
	}

	switch l.Type {
	case "system":
		switch l.Subtype {
		case "init":
			out.Patch.Model, out.Patch.Cwd, out.Patch.Version = l.Model, l.Cwd, l.Version
		case "compact_boundary":
			emit(notice(itemID("compact", l.UUID, line), v1.Notice_LEVEL_INFO, "Conversation compacted"))
		case "api_error":
			emit(notice(itemID("apierr", l.UUID, line), v1.Notice_LEVEL_WARNING, "API error, retrying"))
		}
	case "ai-title":
		out.Patch.Title = l.AITitle
	case "custom-title":
		out.Patch.Title = l.CustomTitle
	case "stream_event":
		b.streamEvent(l, &out, emit)
	case "assistant":
		if l.IsSidechain {
			break
		}
		var m message
		if json.Unmarshal(l.Message, &m) != nil {
			break
		}
		if m.Model != "" && m.Model != "<synthetic>" {
			out.Patch.Model = m.Model
		}
		var blocks []contentBlock
		_ = json.Unmarshal(m.Content, &blocks)
		for i, cb := range blocks {
			key := fmt.Sprintf("%s:%d", l.UUID, i)
			idx, seen := b.lineIdx[key]
			if !seen || l.UUID == "" {
				idx = b.blockIdx[m.ID]
				b.blockIdx[m.ID] = idx + 1
				b.lineIdx[key] = idx
			}
			b.assistantBlock(m.ID, idx, cb, &out, emit)
		}
	case "user":
		if l.IsSidechain || l.IsMeta {
			break
		}
		var m message
		if json.Unmarshal(l.Message, &m) != nil {
			break
		}
		b.userMessage(l, m, &out, emit)
	case "attachment":
		// A message sent while Claude was busy, absorbed into the running turn.
		a := l.Attachment
		if a.Type == "queued_command" && (a.CommandMode == "" || a.CommandMode == "prompt") && !l.IsSidechain {
			if text := strings.TrimSpace(a.Prompt); text != "" {
				emit(&v1.TimelineItem{ItemId: itemID("user", l.UUID, []byte(text)), Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: text}}})
			}
		}
	case "result":
		cost := l.Cost
		out.Patch.Cost = &cost
		emit(&v1.TimelineItem{
			ItemId: itemID("result", l.UUID, line),
			Kind: &v1.TimelineItem_Result{Result: &v1.ResultSummary{
				IsError: l.IsError, Subtype: l.Subtype, NumTurns: l.NumTurns, DurationMs: l.DurationMs, CostUsd: l.Cost,
			}},
		})
		if l.IsError && l.Result != "" {
			emit(notice(itemID("resulterr", l.UUID, line), v1.Notice_LEVEL_ERROR, l.Result))
		}
	}
	return out
}

func (b *Builder) streamEvent(l rawLine, out *Output, emit func(*v1.TimelineItem)) {
	var ev streamEvent
	if json.Unmarshal(l.Event, &ev) != nil {
		return
	}
	key := l.ParentToolUseID
	switch ev.Type {
	case "message_start":
		b.curMsg[key] = ev.Message.ID
	case "content_block_start":
		msg := b.curMsg[key]
		if msg == "" {
			return
		}
		id := blockID(msg, ev.Index)
		switch ev.ContentBlock.Type {
		case "text", "thinking":
			b.partials[id] = &strings.Builder{}
		case "tool_use":
			if b.find(ev.ContentBlock.ID) == nil {
				card := &v1.ToolCard{ToolUseId: ev.ContentBlock.ID, Name: ev.ContentBlock.Name, Status: v1.ToolCard_STATUS_PENDING, Title: ev.ContentBlock.Name}
				emit(&v1.TimelineItem{ItemId: ev.ContentBlock.ID, Kind: &v1.TimelineItem_Tool{Tool: card}})
			}
		}
	case "content_block_delta":
		msg := b.curMsg[key]
		id := blockID(msg, ev.Index)
		p, ok := b.partials[id]
		if !ok {
			return
		}
		switch ev.Delta.Type {
		case "text_delta":
			p.WriteString(ev.Delta.Text)
			emit(&v1.TimelineItem{ItemId: id, Kind: &v1.TimelineItem_Markdown{Markdown: &v1.Markdown{Blocks: Markdown(p.String()), Streaming: true}}})
			out.Delta = true
		case "thinking_delta":
			p.WriteString(ev.Delta.Thinking)
			if strings.TrimSpace(p.String()) == "" {
				return
			}
			emit(&v1.TimelineItem{ItemId: id, Kind: &v1.TimelineItem_Thinking{Thinking: &v1.Thinking{Text: p.String(), Streaming: true}}})
			out.Delta = true
		}
	}
}

func (b *Builder) assistantBlock(msgID string, idx int, cb contentBlock, out *Output, emit func(*v1.TimelineItem)) {
	id := blockID(msgID, idx)
	switch cb.Type {
	case "text":
		delete(b.partials, id)
		if strings.TrimSpace(cb.Text) == "" {
			return
		}
		emit(&v1.TimelineItem{ItemId: id, Kind: &v1.TimelineItem_Markdown{Markdown: &v1.Markdown{Blocks: Markdown(cb.Text)}}})
	case "thinking":
		text := cb.Thinking
		if p, ok := b.partials[id]; ok && text == "" {
			text = p.String()
		}
		delete(b.partials, id)
		if strings.TrimSpace(text) == "" {
			return
		}
		emit(&v1.TimelineItem{ItemId: id, Kind: &v1.TimelineItem_Thinking{Thinking: &v1.Thinking{Text: text}}})
	case "tool_use":
		card := ToolCard(cb.ID, cb.Name, cb.Input)
		// Transcript replays can arrive after the live result; keep the outcome.
		if prev := b.find(cb.ID); prev != nil {
			if pc := prev.GetTool(); pc != nil && pc.Output != nil {
				card.Output, card.Status = pc.Output, pc.Status
			}
		}
		if t := card.GetTodos(); t != nil {
			out.Patch.Todos, out.Patch.TodosSet = t.Todos, true
		}
		emit(&v1.TimelineItem{ItemId: cb.ID, Kind: &v1.TimelineItem_Tool{Tool: card}})
	}
}

var (
	commandName = regexp.MustCompile(`<command-name>(.*?)</command-name>`)
	commandArgs = regexp.MustCompile(`(?s)<command-args>(.*?)</command-args>`)
	localStdout = regexp.MustCompile(`(?s)<local-command-stdout>(.*?)</local-command-stdout>`)
)

func (b *Builder) userMessage(l rawLine, m message, out *Output, emit func(*v1.TimelineItem)) {
	var texts []string
	var s string
	if json.Unmarshal(m.Content, &s) == nil {
		texts = append(texts, s)
	} else {
		var blocks []contentBlock
		_ = json.Unmarshal(m.Content, &blocks)
		for _, cb := range blocks {
			switch cb.Type {
			case "tool_result":
				item := b.find(cb.ToolUseID)
				var card *v1.ToolCard
				if item != nil && item.GetTool() != nil {
					card = proto.Clone(item.GetTool()).(*v1.ToolCard)
				} else {
					card = &v1.ToolCard{ToolUseId: cb.ToolUseID, Name: "Tool", Title: "Tool"}
				}
				ApplyResult(card, cb.Content, cb.IsError)
				emit(&v1.TimelineItem{ItemId: cb.ToolUseID, Kind: &v1.TimelineItem_Tool{Tool: card}})
			case "text":
				texts = append(texts, cb.Text)
			case "image":
				texts = append(texts, "[image]")
			}
		}
	}
	text := strings.TrimSpace(strings.Join(texts, "\n"))
	if text == "" {
		return
	}
	id := itemID("user", l.UUID, []byte(text))
	switch {
	case strings.Contains(text, "<local-command-caveat>"), strings.HasPrefix(text, "<system-reminder>"):
	case commandName.MatchString(text):
		cmd := commandName.FindStringSubmatch(text)[1]
		if a := commandArgs.FindStringSubmatch(text); a != nil && strings.TrimSpace(a[1]) != "" {
			cmd += " " + strings.TrimSpace(a[1])
		}
		emit(notice(id, v1.Notice_LEVEL_INFO, cmd))
	case localStdout.MatchString(text):
		if body := strings.TrimSpace(localStdout.FindStringSubmatch(text)[1]); body != "" {
			emit(notice(id, v1.Notice_LEVEL_INFO, body))
		}
	case strings.HasPrefix(text, "[Request interrupted by user"):
		emit(notice(id, v1.Notice_LEVEL_WARNING, "Interrupted"))
	default:
		emit(&v1.TimelineItem{ItemId: id, Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: text}}})
	}
}

func (b *Builder) find(id string) *v1.TimelineItem {
	if it, ok := b.items[id]; ok {
		return it
	}
	if b.Lookup != nil {
		if it := b.Lookup(id); it != nil {
			b.items[id] = it
			return it
		}
	}
	return nil
}

func notice(id string, level v1.Notice_Level, text string) *v1.TimelineItem {
	return &v1.TimelineItem{ItemId: id, Kind: &v1.TimelineItem_Notice{Notice: &v1.Notice{Level: level, Text: text}}}
}

func blockID(msgID string, idx int) string { return fmt.Sprintf("%s:%d", msgID, idx) }

func itemID(prefix, uuid string, fallback []byte) string {
	if uuid != "" {
		return prefix + ":" + uuid
	}
	h := sha1.Sum(fallback)
	return prefix + ":" + hex.EncodeToString(h[:8])
}
