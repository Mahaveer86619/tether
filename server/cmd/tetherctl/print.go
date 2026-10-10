package main

import (
	"errors"
	"fmt"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

const (
	bold   = "\x1b[1m"
	italic = "\x1b[3m"
	dim    = "\x1b[2m"
	cyan   = "\x1b[36m"
	green  = "\x1b[32m"
	red    = "\x1b[31m"
	yellow = "\x1b[33m"
	reset  = "\x1b[0m"
)

// printer renders one session's timeline to the terminal, printing each
// item once it has settled.
type printer struct {
	c        *ctl
	session  string
	yes      bool
	replayed bool
	// Items stamped before this (unix ms) are history, not part of this turn.
	since   int64
	printed map[string]bool
	done    bool
	failed  error
	// Interactive (tmux) sessions write no result line; the turn ends when
	// the session goes from busy back to ready.
	busy     bool
	finishAt time.Time
}

func newPrinter(c *ctl, session string, yes bool) *printer {
	return &printer{c: c, session: session, yes: yes, printed: map[string]bool{}}
}

// loop handles frames until the turn finishes (untilResult) or forever.
func (p *printer) loop(untilResult bool) error {
	tick := time.NewTicker(250 * time.Millisecond)
	defer tick.Stop()
	for {
		select {
		case f := <-p.c.frames:
			p.handle(f)
		case <-tick.C:
			// Give the transcript mirror a moment to deliver the final reply.
			if !p.finishAt.IsZero() && time.Now().After(p.finishAt) {
				p.done = true
			}
		}
		if p.failed != nil {
			return p.failed
		}
		if untilResult && p.done {
			return nil
		}
	}
}

func (p *printer) handle(f *v1.Frame) {
	switch b := f.Body.(type) {
	case *v1.Frame_Timeline:
		if b.Timeline.Session != p.session {
			return
		}
		if len(b.Timeline.Items) == 0 && !p.replayed {
			p.replayed = true
			return
		}
		for _, it := range b.Timeline.Items {
			p.item(it)
		}
	case *v1.Frame_ApprovalRequested:
		if b.ApprovalRequested.Session == p.session {
			p.approve(b.ApprovalRequested)
		}
	case *v1.Frame_ApprovalResolved:
		if r := b.ApprovalResolved; r.Session == p.session && r.By == "terminal" {
			fmt.Printf("%s· approval answered in the terminal%s\n", yellow, reset)
		}
	case *v1.Frame_SessionInfo:
		s := b.SessionInfo
		if s.Id != p.session {
			return
		}
		switch s.State {
		case v1.SessionState_SESSION_STATE_ERROR:
			if p.replayed {
				p.failed = fmt.Errorf("session error: %s", s.Error)
			}
		case v1.SessionState_SESSION_STATE_RUNNING, v1.SessionState_SESSION_STATE_AWAITING_APPROVAL:
			p.busy, p.finishAt = true, time.Time{}
		case v1.SessionState_SESSION_STATE_READY, v1.SessionState_SESSION_STATE_IDLE:
			if p.busy && p.finishAt.IsZero() && s.Host != v1.SessionHost_SESSION_HOST_HEADLESS {
				p.finishAt = time.Now().Add(2 * time.Second)
				if s.AttachCommand != "" {
					fmt.Printf("%s── turn finished · %s%s\n", green, s.AttachCommand, reset)
				}
			}
		}
	case *v1.Frame_Error:
		if b.Error.Code == "disconnected" {
			p.failed = errors.New(b.Error.Message)
		} else {
			fmt.Printf("%serror%s %s: %s\n", red, reset, b.Error.Code, b.Error.Message)
		}
	}
}

func (p *printer) item(it *v1.TimelineItem) {
	if !settled(it) || p.printed[it.ItemId] {
		return
	}
	p.printed[it.ItemId] = true
	if !p.replayed || it.TsMs < p.since {
		return
	}
	pad := ""
	if it.ParentToolUseId != "" {
		pad = "    "
	}
	var out string
	switch k := it.Kind.(type) {
	case *v1.TimelineItem_User:
		out = fmt.Sprintf("%s> %s%s", bold, k.User.Text, reset)
	case *v1.TimelineItem_Markdown:
		out = renderBlocks(k.Markdown.Blocks)
	case *v1.TimelineItem_Thinking:
		out = dim + italic + clipLines(k.Thinking.Text, 6) + reset
	case *v1.TimelineItem_Tool:
		out = renderCard(k.Tool)
	case *v1.TimelineItem_Notice:
		out = fmt.Sprintf("%s· %s%s", yellow, k.Notice.Text, reset)
	case *v1.TimelineItem_Result:
		r := k.Result
		color := green
		if r.IsError {
			color = red
		}
		out = fmt.Sprintf("%s── %s · %d turns · %.1fs · $%.4f%s", color, r.Subtype, r.NumTurns, float64(r.DurationMs)/1000, r.CostUsd, reset)
		p.done = true
	}
	fmt.Println(indent(out, pad))
	fmt.Println()
}

func settled(it *v1.TimelineItem) bool {
	switch k := it.Kind.(type) {
	case *v1.TimelineItem_Markdown:
		return !k.Markdown.Streaming
	case *v1.TimelineItem_Thinking:
		return !k.Thinking.Streaming
	case *v1.TimelineItem_Tool:
		return k.Tool.Status == v1.ToolCard_STATUS_SUCCEEDED || k.Tool.Status == v1.ToolCard_STATUS_FAILED
	}
	return true
}

func (p *printer) approve(a *v1.ApprovalRequest) {
	if a.Kind == v1.ApprovalRequest_KIND_FOLDER_TRUST {
		fmt.Printf("%s? %s%s\n", yellow, a.Description, reset)
	} else {
		fmt.Printf("%s? %s wants to run:%s\n%s\n", yellow, a.ToolName, reset, indent(renderCard(a.Preview), "  "))
	}
	allow := p.yes
	if p.yes {
		fmt.Println(green + "  allowed (-yes)" + reset)
	} else {
		fmt.Print("  allow? [y/N] ")
		line, _ := p.c.stdin.ReadString('\n')
		allow = strings.HasPrefix(strings.ToLower(strings.TrimSpace(line)), "y")
	}
	d := v1.Decision_DECISION_DENY
	if allow {
		d = v1.Decision_DECISION_ALLOW
	}
	p.c.conn.Send(&v1.Frame{Body: &v1.Frame_ApprovalDecision{ApprovalDecision: &v1.ApprovalDecision{ApprovalId: a.ApprovalId, Decision: d}}})
}

func renderCard(c *v1.ToolCard) string {
	if c == nil {
		return ""
	}
	icon := cyan + "▸" + reset
	switch c.Status {
	case v1.ToolCard_STATUS_SUCCEEDED:
		icon = green + "✓" + reset
	case v1.ToolCard_STATUS_FAILED:
		icon = red + "✗" + reset
	}
	var b strings.Builder
	fmt.Fprintf(&b, "%s %s%s%s %s", icon, bold, c.Name, reset, c.Title)
	switch d := c.Detail.(type) {
	case *v1.ToolCard_Shell:
		fmt.Fprintf(&b, "\n%s$ %s%s", dim, d.Shell.Command, reset)
	case *v1.ToolCard_Edit:
		fmt.Fprintf(&b, "  %s+%d%s %s-%d%s", green, d.Edit.Added, reset, red, d.Edit.Removed, reset)
		for _, l := range strings.Split(strings.TrimRight(d.Edit.UnifiedDiff, "\n"), "\n") {
			switch {
			case strings.HasPrefix(l, "+++"), strings.HasPrefix(l, "---"):
				continue
			case strings.HasPrefix(l, "+"):
				l = green + l + reset
			case strings.HasPrefix(l, "-"):
				l = red + l + reset
			case strings.HasPrefix(l, "@@"):
				l = cyan + l + reset
			}
			b.WriteString("\n" + l)
		}
	case *v1.ToolCard_Write:
		fmt.Fprintf(&b, "  %s(%d lines)%s", dim, d.Write.Lines, reset)
	case *v1.ToolCard_Todos:
		for _, t := range d.Todos.Todos {
			mark := "[ ]"
			switch t.Status {
			case v1.Todo_STATUS_COMPLETED:
				mark = "[x]"
			case v1.Todo_STATUS_IN_PROGRESS:
				mark = "[~]"
			}
			b.WriteString("\n" + mark + " " + t.Content)
		}
	case *v1.ToolCard_Generic:
		b.WriteString("\n" + dim + clipLines(d.Generic.InputJson, 8) + reset)
	}
	if o := c.Output; o != nil && strings.TrimSpace(o.Text) != "" {
		if _, isEdit := c.Detail.(*v1.ToolCard_Edit); !isEdit {
			color := dim
			if o.IsError {
				color = red
			}
			b.WriteString("\n" + color + clipLines(o.Text, 12) + reset)
		}
	}
	return b.String()
}

func renderBlocks(bs []*v1.Block) string {
	var parts []string
	for _, b := range bs {
		parts = append(parts, renderBlock(b))
	}
	return strings.Join(parts, "\n\n")
}

func renderBlock(b *v1.Block) string {
	switch k := b.Kind.(type) {
	case *v1.Block_Heading:
		return bold + strings.Repeat("#", int(k.Heading.Level)) + " " + spans(k.Heading.Spans) + reset
	case *v1.Block_Paragraph:
		return spans(k.Paragraph.Spans)
	case *v1.Block_List:
		var lines []string
		for i, it := range k.List.Items {
			marker := "• "
			if k.List.Ordered {
				marker = fmt.Sprintf("%d. ", int(k.List.Start)+i)
			}
			if it.Checked != nil {
				if *it.Checked {
					marker += "[x] "
				} else {
					marker += "[ ] "
				}
			}
			body := indent(renderBlocks(it.Blocks), strings.Repeat(" ", len([]rune(marker))))
			lines = append(lines, marker+strings.TrimLeft(body, " "))
		}
		return strings.Join(lines, "\n")
	case *v1.Block_Code:
		return dim + "```" + k.Code.Lang + reset + "\n" + cyan + k.Code.Text + reset + "\n" + dim + "```" + reset
	case *v1.Block_Table:
		return renderTable(k.Table)
	case *v1.Block_Quote:
		return indent(renderBlocks(k.Quote.Blocks), "│ ")
	case *v1.Block_Divider:
		return dim + "────────" + reset
	case *v1.Block_Image:
		return fmt.Sprintf("[image: %s] %s", k.Image.Alt, k.Image.Url)
	}
	return ""
}

func renderTable(t *v1.Table) string {
	rows := [][]string{}
	plainRows := [][]string{}
	add := func(cells []*v1.TableCell) {
		var r, pr []string
		for _, c := range cells {
			r = append(r, spans(c.Spans))
			pr = append(pr, plainSpans(c.Spans))
		}
		rows, plainRows = append(rows, r), append(plainRows, pr)
	}
	add(t.Header)
	for _, r := range t.Rows {
		add(r.Cells)
	}
	widths := map[int]int{}
	for _, r := range plainRows {
		for i, c := range r {
			widths[i] = max(widths[i], len([]rune(c)))
		}
	}
	var b strings.Builder
	for ri, r := range rows {
		b.WriteString("│")
		for i, c := range r {
			b.WriteString(" " + c + strings.Repeat(" ", widths[i]-len([]rune(plainRows[ri][i]))) + " │")
		}
		b.WriteString("\n")
		if ri == 0 {
			b.WriteString("├")
			for i := range r {
				b.WriteString(strings.Repeat("─", widths[i]+2) + "┼")
			}
			b.WriteString("\n")
		}
	}
	return strings.TrimRight(b.String(), "\n")
}

func spans(ss []*v1.Span) string {
	var b strings.Builder
	for _, s := range ss {
		style := ""
		if s.Bold {
			style += bold
		}
		if s.Italic {
			style += italic
		}
		if s.Code {
			style += cyan
		}
		text := s.Text
		if s.Link != "" && s.Link != text {
			text += dim + " (" + s.Link + ")" + reset
		}
		if style != "" {
			text = style + text + reset
		}
		b.WriteString(text)
	}
	return b.String()
}

func plainSpans(ss []*v1.Span) string {
	var b strings.Builder
	for _, s := range ss {
		b.WriteString(s.Text)
		if s.Link != "" && s.Link != s.Text {
			b.WriteString(" (" + s.Link + ")")
		}
	}
	return b.String()
}

func indent(s, pad string) string {
	if pad == "" {
		return s
	}
	return pad + strings.ReplaceAll(s, "\n", "\n"+pad)
}

func clipLines(s string, n int) string {
	ls := strings.Split(strings.TrimRight(s, "\n"), "\n")
	if len(ls) > n {
		ls = append(ls[:n], fmt.Sprintf("… %d more lines", len(ls)-n))
	}
	return strings.Join(ls, "\n")
}
