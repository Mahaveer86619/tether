package render

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/aymanbagabas/go-udiff"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

const (
	outputHeadLines = 200
	outputTailLines = 100
	outputMaxBytes  = 128 << 10
	writePreview    = 40
)

type toolInput struct {
	Command      string `json:"command"`
	Description  string `json:"description"`
	FilePath     string `json:"file_path"`
	NotebookPath string `json:"notebook_path"`
	OldString    string `json:"old_string"`
	NewString    string `json:"new_string"`
	Edits        []struct {
		OldString string `json:"old_string"`
		NewString string `json:"new_string"`
	} `json:"edits"`
	Content      string `json:"content"`
	Offset       int32  `json:"offset"`
	Limit        int32  `json:"limit"`
	Pattern      string `json:"pattern"`
	Path         string `json:"path"`
	Glob         string `json:"glob"`
	URL          string `json:"url"`
	Query        string `json:"query"`
	Prompt       string `json:"prompt"`
	SubagentType string `json:"subagent_type"`
	Todos        []struct {
		Content    string `json:"content"`
		Status     string `json:"status"`
		ActiveForm string `json:"activeForm"`
	} `json:"todos"`
}

// ToolCard builds the card for a tool call from its raw input.
func ToolCard(id, name string, input json.RawMessage) *v1.ToolCard {
	card := &v1.ToolCard{ToolUseId: id, Name: name, Status: v1.ToolCard_STATUS_RUNNING, Title: name}
	var in toolInput
	_ = json.Unmarshal(input, &in)

	switch name {
	case "Bash", "PowerShell":
		shell := "bash"
		if name == "PowerShell" {
			shell = "powershell"
		}
		card.Detail = &v1.ToolCard_Shell{Shell: &v1.ShellCard{Shell: shell, Command: in.Command, Description: in.Description}}
		card.Title = firstNonEmpty(in.Description, firstLine(in.Command))
	case "Edit", "MultiEdit":
		e := &v1.EditCard{Path: in.FilePath}
		if name == "Edit" {
			e.UnifiedDiff = diff(in.FilePath, in.OldString, in.NewString)
		} else {
			var parts []string
			for _, ed := range in.Edits {
				parts = append(parts, diff(in.FilePath, ed.OldString, ed.NewString))
			}
			e.UnifiedDiff = strings.Join(parts, "")
		}
		e.Added, e.Removed = countDiff(e.UnifiedDiff)
		card.Detail = &v1.ToolCard_Edit{Edit: e}
		card.Title = in.FilePath
	case "Write":
		ls := strings.Split(in.Content, "\n")
		preview := ls
		if len(preview) > writePreview {
			preview = preview[:writePreview]
		}
		card.Detail = &v1.ToolCard_Write{Write: &v1.WriteCard{Path: in.FilePath, Preview: strings.Join(preview, "\n"), Lines: int32(len(ls))}}
		card.Title = in.FilePath
	case "Read", "NotebookRead":
		p := firstNonEmpty(in.FilePath, in.NotebookPath)
		card.Detail = &v1.ToolCard_Read{Read: &v1.ReadCard{Path: p, Offset: in.Offset, Limit: in.Limit}}
		card.Title = p
	case "Grep", "Glob":
		card.Detail = &v1.ToolCard_Search{Search: &v1.SearchCard{Pattern: in.Pattern, Path: in.Path, Glob: in.Glob}}
		card.Title = in.Pattern
	case "TodoWrite":
		card.Detail = &v1.ToolCard_Todos{Todos: &v1.TodoCard{Todos: todos(in)}}
		card.Title = "Update to-do list"
	case "Task", "Agent":
		card.Detail = &v1.ToolCard_Agent{Agent: &v1.AgentCard{Description: in.Description, SubagentType: in.SubagentType, Prompt: in.Prompt}}
		card.Title = firstNonEmpty(in.Description, name)
	case "WebFetch", "WebSearch":
		card.Detail = &v1.ToolCard_Web{Web: &v1.WebCard{Url: in.URL, Query: in.Query}}
		card.Title = firstNonEmpty(in.URL, in.Query)
	default:
		card.Detail = &v1.ToolCard_Generic{Generic: &v1.GenericCard{InputJson: pretty(input)}}
	}
	return card
}

// ApplyResult fills a card's output from a tool_result content value.
func ApplyResult(card *v1.ToolCard, content json.RawMessage, isError bool) {
	out, omitted := truncate(resultText(content))
	card.Output = &v1.ToolOutput{Text: out, IsError: isError, OmittedLines: int32(omitted)}
	if isError {
		card.Status = v1.ToolCard_STATUS_FAILED
	} else {
		card.Status = v1.ToolCard_STATUS_SUCCEEDED
	}
}

func todos(in toolInput) []*v1.Todo {
	var out []*v1.Todo
	for _, t := range in.Todos {
		st := v1.Todo_STATUS_PENDING
		switch t.Status {
		case "in_progress":
			st = v1.Todo_STATUS_IN_PROGRESS
		case "completed":
			st = v1.Todo_STATUS_COMPLETED
		}
		out = append(out, &v1.Todo{Content: t.Content, Status: st, ActiveForm: t.ActiveForm})
	}
	return out
}

func resultText(content json.RawMessage) string {
	if len(content) == 0 {
		return ""
	}
	var s string
	if json.Unmarshal(content, &s) == nil {
		return s
	}
	var parts []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	}
	if json.Unmarshal(content, &parts) == nil {
		var b []string
		for _, p := range parts {
			switch p.Type {
			case "text":
				b = append(b, p.Text)
			case "image":
				b = append(b, "[image]")
			}
		}
		return strings.Join(b, "\n")
	}
	return string(content)
}

func truncate(s string) (string, int) {
	ls := strings.Split(s, "\n")
	omitted := 0
	if len(ls) > outputHeadLines+outputTailLines {
		omitted = len(ls) - outputHeadLines - outputTailLines
		head := strings.Join(ls[:outputHeadLines], "\n")
		tail := strings.Join(ls[len(ls)-outputTailLines:], "\n")
		s = fmt.Sprintf("%s\n… %d lines omitted …\n%s", head, omitted, tail)
	}
	if len(s) > outputMaxBytes {
		s = s[:outputMaxBytes] + "\n… output truncated …"
	}
	return s, omitted
}

func diff(path, oldS, newS string) string {
	return udiff.Unified("a/"+path, "b/"+path, oldS, newS)
}

func countDiff(d string) (added, removed int32) {
	for _, l := range strings.Split(d, "\n") {
		switch {
		case strings.HasPrefix(l, "+++"), strings.HasPrefix(l, "---"):
		case strings.HasPrefix(l, "+"):
			added++
		case strings.HasPrefix(l, "-"):
			removed++
		}
	}
	return added, removed
}

func pretty(raw json.RawMessage) string {
	var buf bytes.Buffer
	if json.Indent(&buf, raw, "", "  ") != nil {
		return string(raw)
	}
	return buf.String()
}

func firstLine(s string) string {
	s, _, _ = strings.Cut(strings.TrimSpace(s), "\n")
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
