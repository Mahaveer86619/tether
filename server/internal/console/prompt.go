package console

import (
	"regexp"
	"strings"
	"unicode/utf8"
)

const (
	// Lines from the bottom a dialog can start in; older lines are history.
	DialogWindow = 24
)

// Dialog is a choice read off the screen.
type Dialog struct {
	Title    string
	Options  []string
	Keys     []string // inline surveys: the key that picks each option
	Selected int      // the cursor's option, or -1
}

// Signature returns a string uniquely identifying the dialog options and title.
func (d *Dialog) Signature() string {
	return d.Title + "\x00" + strings.Join(d.Options, "\x00")
}

var (
	boxChars    = "│┃|╭╮╰╯─━┌┐└┘├┤"
	menuLine    = regexp.MustCompile(`^(\s*)([❯›>]?)\s*(?:(\d{1,2})[.)]\s+)?(\S.*?)\s*$`)
	inlineEntry = regexp.MustCompile(`(\d):\s*([^\s\d][^:]*?)(?:\s{2,}|$)`)
	hintLine    = regexp.MustCompile(`(?i)(esc|enter|↑|↓|tab) to `)
	// Option lines may carry marks like ✔ (the current value) after the text.
	marks = regexp.MustCompile(`\s+[✔✓]\s*$`)
)

// CleanLine strips a dialog box's borders.
func CleanLine(l string) string {
	l = strings.TrimRight(l, " ")
	trimmed := strings.Trim(l, " ")
	if trimmed != "" && strings.Trim(trimmed, boxChars+" ") == "" {
		return ""
	}
	for _, c := range []string{"│", "┃"} {
		if strings.HasPrefix(strings.TrimLeft(l, " "), c) {
			l = strings.TrimLeft(l, " ")
			l = strings.TrimPrefix(l, c)
		}
		l = strings.TrimSuffix(strings.TrimRight(l, " "), c)
	}
	return strings.TrimRight(l, " ")
}

// ParseDialog finds the dialog at the bottom of a screen, if there is one:
// a vertical menu with a cursor (❯) on one option, or a one-line survey
// like "1: Bad  2: Fine  3: Good  0: Dismiss".
func ParseDialog(screen string) *Dialog {
	raw := strings.Split(strings.ReplaceAll(screen, "\r", ""), "\n")
	lines := make([]string, len(raw))
	for i, l := range raw {
		lines[i] = CleanLine(l)
	}
	last := len(lines) - 1
	for last >= 0 && strings.TrimSpace(lines[last]) == "" {
		last--
	}
	start := max(0, last-DialogWindow+1)
	if d := parseMenu(lines, start, last); d != nil {
		return d
	}
	return parseInline(lines, start, last)
}

func parseMenu(lines []string, start, last int) *Dialog {
	// Find the cursor, then the run of sibling options around it.
	cursor := -1
	for i := last; i >= start; i-- {
		if m := menuLine.FindStringSubmatch(lines[i]); m != nil && m[2] == "❯" {
			cursor = i
			break
		}
	}
	if cursor < 0 {
		return nil
	}
	cm := menuLine.FindStringSubmatch(lines[cursor])
	numbered := cm[3] != ""
	indent := utf8.RuneCountInString(cm[1])
	isOption := func(i int) (string, bool) {
		m := menuLine.FindStringSubmatch(lines[i])
		if m == nil || hintLine.MatchString(lines[i]) {
			return "", false
		}
		if numbered {
			return m[4], m[3] != ""
		}
		// Unnumbered: same column as the cursor line's text.
		col := utf8.RuneCountInString(m[1])
		if m[2] == "" {
			col -= 2
		}
		return m[4], m[2] == "❯" || (col >= indent-1 && col <= indent+1)
	}
	first, end := cursor, cursor
	for i := cursor - 1; i >= start; i-- {
		if strings.TrimSpace(lines[i]) == "" {
			break
		}
		if _, ok := isOption(i); ok {
			first = i
		} else if !numbered {
			break
		}
	}
	for i := cursor + 1; i <= last; i++ {
		if strings.TrimSpace(lines[i]) == "" || hintLine.MatchString(lines[i]) {
			break
		}
		if _, ok := isOption(i); ok {
			end = i
		} else if !numbered {
			break
		}
	}
	d := &Dialog{Selected: -1}
	for i := first; i <= end; i++ {
		if text, ok := isOption(i); ok {
			if i == cursor {
				d.Selected = len(d.Options)
			}
			d.Options = append(d.Options, marks.ReplaceAllString(text, ""))
		}
	}
	if len(d.Options) < 2 {
		return nil
	}
	d.Title = titleAbove(lines, first, start)
	return d
}

func parseInline(lines []string, start, last int) *Dialog {
	for i := last; i >= start; i-- {
		ms := inlineEntry.FindAllStringSubmatch(lines[i], -1)
		if len(ms) < 2 {
			continue
		}
		d := &Dialog{Selected: -1}
		for _, m := range ms {
			d.Keys = append(d.Keys, m[1])
			d.Options = append(d.Options, strings.TrimSpace(m[2]))
		}
		d.Title = titleAbove(lines, i, start)
		return d
	}
	return nil
}

// titleAbove is the nearest text above a dialog's options: its question.
func titleAbove(lines []string, first, start int) string {
	for i := first - 1; i >= start; i-- {
		t := strings.TrimSpace(lines[i])
		if t == "" {
			continue
		}
		return strings.TrimLeft(t, "●⏺✻* ")
	}
	return "Claude Code is asking"
}

// LastLines returns the last n lines of a string.
func LastLines(s string, n int) string {
	lines := strings.Split(strings.TrimRight(s, "\n "), "\n")
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	return strings.Join(lines, "\n")
}
