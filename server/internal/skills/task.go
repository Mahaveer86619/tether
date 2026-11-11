// Package skills turns finished sessions into task records: what the user
// asked for and the steps Claude took. It is the first part of learning
// skills from repeated work; see docs/plans/skills.md.
package skills

import (
	"cmp"
	"slices"
	"strings"
	"unicode/utf8"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Step is one tool call, reduced to what stays the same when a routine is
// run again.
type Step struct {
	Tool string
	// Key is the masked, normalised form used to compare routines, such as
	// "Bash:tmux capture-pane" or "Edit:.go".
	Key string
	// Detail is the masked command line or path, for writing a skill from it.
	Detail   string
	Mutating bool
	Failed   bool
}

// Task is one request from the user and what Claude did about it.
type Task struct {
	Session, Node, Cwd string
	Request            string
	Steps              []Step
	StartMs            int64
}

// Standalone reports whether the request says what is wanted. Follow-ups such
// as "yes start" or "check again", pasted wrappers and image notes only make
// sense inside their conversation, so they are never a routine.
func (t Task) Standalone() bool {
	r := strings.TrimSpace(t.Request)
	for _, p := range notRequests {
		if strings.HasPrefix(r, p) {
			return false
		}
	}
	if strings.Contains(r, "is in the attached file") || utf8.RuneCountInString(r) > maxRequest {
		return false
	}
	for _, w := range tokens(r) {
		if !followUpWords[w] {
			return true
		}
	}
	return false
}

// maxRequest is the longest message that can be a routine ask. A routine is
// asked in a line; a long message is a brief, a pasted report or a summary.
const maxRequest = 300

// notRequests start messages Claude Code or Tether wrote, not the user.
var notRequests = []string{"<", "[Image", "This session is being continued", continued}

// followUpWords are what is left of a message that only answers or nudges.
var followUpWords = map[string]bool{
	"yes": true, "ok": true, "okay": true, "sure": true, "go": true, "start": true, "continue": true, "proceed": true,
	"thanks": true, "thank": true, "no": true, "done": true, "check": true, "retry": true, "next": true, "run": true,
	"fine": true, "good": true, "great": true, "yep": true, "nope": true, "ahead": true, "do": true, "it": true,
}

// Routine reports whether Claude used any tools: a task answered in words
// alone has nothing to repeat.
func (t Task) Routine() bool { return len(t.Steps) > 0 }

// Meta says where a session's items come from.
type Meta struct{ Session, Node, Cwd string }

// continued marks the first message of a chat that moved to a new session:
// it carries the earlier conversation, not a request of its own.
const continued = "This continues an earlier conversation"

// Tasks splits a session's timeline into tasks, one per user message. Queued
// placeholders, sub-agent items and the tool calls that only keep a to-do list
// are left out.
func Tasks(m Meta, items []*v1.TimelineItem) []Task {
	// The store hands items back in the order they changed, not the order they
	// happened, and a removed item stays as an empty tombstone.
	items = slices.SortedStableFunc(slices.Values(items), func(a, b *v1.TimelineItem) int { return cmp.Compare(a.GetOrd(), b.GetOrd()) })
	var out []Task
	var cur *Task
	flush := func() {
		if cur != nil && cur.Request != "" {
			out = append(out, *cur)
		}
		cur = nil
	}
	for _, it := range items {
		if it.GetKind() == nil || it.GetParentToolUseId() != "" {
			continue
		}
		if u := it.GetUser(); u != nil {
			if u.Queued {
				continue
			}
			flush()
			text := requestText(u.Text)
			if text == "" || strings.HasPrefix(text, continued) {
				continue
			}
			cur = &Task{Session: m.Session, Node: m.Node, Cwd: m.Cwd, Request: text, StartMs: it.GetTsMs()}
			continue
		}
		if tc := it.GetTool(); tc != nil && cur != nil {
			if s, ok := stepOf(tc); ok {
				cur.Steps = append(cur.Steps, s)
			}
		}
	}
	flush()
	return out
}

// requestText is what the user typed: the list of attached files that the
// agent adds after it is not theirs.
func requestText(s string) string {
	if i := strings.Index(s, "Attached files (in this folder)"); i >= 0 {
		s = s[:i]
	}
	return strings.TrimSpace(s)
}

func stepOf(tc *v1.ToolCard) (Step, bool) {
	if tc.GetName() == "TodoWrite" || tc.GetTodos() != nil {
		return Step{}, false
	}
	s := Step{Tool: tc.GetName(), Failed: tc.GetStatus() == v1.ToolCard_STATUS_FAILED || tc.GetOutput().GetIsError()}
	switch {
	case tc.GetShell() != nil:
		raw := tc.GetShell().GetCommand()
		cmd := Mask(raw)
		// Whether it changes anything is judged on the real command, before masking adds <>.
		s.Detail, s.Key, s.Mutating = cmd, "Bash:"+commandKey(cmd), mutatingCommand(raw)
	case tc.GetEdit() != nil:
		s.Detail, s.Key, s.Mutating = Mask(tc.GetEdit().GetPath()), s.Tool+":"+ext(tc.GetEdit().GetPath()), true
	case tc.GetWrite() != nil:
		s.Detail, s.Key, s.Mutating = Mask(tc.GetWrite().GetPath()), s.Tool+":"+ext(tc.GetWrite().GetPath()), true
	case tc.GetRead() != nil:
		s.Detail, s.Key = Mask(tc.GetRead().GetPath()), s.Tool+":"+ext(tc.GetRead().GetPath())
	case tc.GetSearch() != nil:
		s.Detail, s.Key = Mask(tc.GetSearch().GetPattern()), s.Tool
	case tc.GetWeb() != nil:
		s.Detail, s.Key = Mask(firstNonEmpty(tc.GetWeb().GetUrl(), tc.GetWeb().GetQuery())), s.Tool
	case tc.GetAgent() != nil:
		s.Detail, s.Key, s.Mutating = Mask(tc.GetAgent().GetDescription()), s.Tool, true
	default:
		s.Detail, s.Key, s.Mutating = Mask(tc.GetTitle()), s.Tool, !readOnlyTools[s.Tool]
	}
	return s, true
}

// readOnlyTools are the tools that never change anything.
var readOnlyTools = map[string]bool{"Read": true, "Grep": true, "Glob": true, "WebFetch": true, "WebSearch": true, "LS": true}

func firstNonEmpty(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

func ext(path string) string {
	path = strings.ReplaceAll(path, `\`, "/")
	base := path[strings.LastIndex(path, "/")+1:]
	if i := strings.LastIndex(base, "."); i > 0 {
		return strings.ToLower(base[i:])
	}
	return ""
}
