package render

import (
	"bytes"
	"strings"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/extension"
	extast "github.com/yuin/goldmark/extension/ast"
	"github.com/yuin/goldmark/text"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

var md = goldmark.New(goldmark.WithExtensions(extension.GFM))

// Markdown parses GitHub-flavoured Markdown into contract blocks.
func Markdown(src string) []*v1.Block {
	b := []byte(src)
	doc := md.Parser().Parse(text.NewReader(b))
	return blocks(doc, b)
}

func blocks(parent ast.Node, src []byte) []*v1.Block {
	var out []*v1.Block
	for n := parent.FirstChild(); n != nil; n = n.NextSibling() {
		out = append(out, block(n, src)...)
	}
	return out
}

func block(n ast.Node, src []byte) []*v1.Block {
	switch x := n.(type) {
	case *ast.Heading:
		return one(&v1.Block{Kind: &v1.Block_Heading{Heading: &v1.Heading{Level: int32(x.Level), Spans: inlines(x, src)}}})
	case *ast.Paragraph, *ast.TextBlock:
		if img, ok := n.FirstChild().(*ast.Image); ok && n.FirstChild() == n.LastChild() {
			return one(&v1.Block{Kind: &v1.Block_Image{Image: &v1.Image{Url: string(img.Destination), Alt: plain(inlines(img, src))}}})
		}
		spans := inlines(n, src)
		if len(spans) == 0 {
			return nil
		}
		return one(&v1.Block{Kind: &v1.Block_Paragraph{Paragraph: &v1.Paragraph{Spans: spans}}})
	case *ast.List:
		l := &v1.ListBlock{Ordered: x.IsOrdered(), Start: int32(x.Start)}
		for it := x.FirstChild(); it != nil; it = it.NextSibling() {
			li := &v1.ListItem{Blocks: blocks(it, src)}
			if first := it.FirstChild(); first != nil {
				if cb, ok := first.FirstChild().(*extast.TaskCheckBox); ok {
					li.Checked = proto.Bool(cb.IsChecked)
				}
			}
			l.Items = append(l.Items, li)
		}
		return one(&v1.Block{Kind: &v1.Block_List{List: l}})
	case *ast.FencedCodeBlock:
		return one(code(string(x.Language(src)), lines(x, src)))
	case *ast.CodeBlock:
		return one(code("", lines(x, src)))
	case *ast.HTMLBlock:
		return one(code("html", lines(x, src)))
	case *ast.Blockquote:
		return one(&v1.Block{Kind: &v1.Block_Quote{Quote: &v1.Quote{Blocks: blocks(x, src)}}})
	case *ast.ThematicBreak:
		return one(&v1.Block{Kind: &v1.Block_Divider{Divider: &v1.Divider{}}})
	case *extast.Table:
		return one(&v1.Block{Kind: &v1.Block_Table{Table: table(x, src)}})
	default:
		return blocks(n, src)
	}
}

func one(b *v1.Block) []*v1.Block { return []*v1.Block{b} }

func code(lang, body string) *v1.Block {
	return &v1.Block{Kind: &v1.Block_Code{Code: &v1.CodeBlock{Lang: lang, Text: strings.TrimRight(body, "\n")}}}
}

func lines(n ast.Node, src []byte) string {
	var buf bytes.Buffer
	ls := n.Lines()
	for i := 0; i < ls.Len(); i++ {
		seg := ls.At(i)
		buf.Write(seg.Value(src))
	}
	return buf.String()
}

func table(t *extast.Table, src []byte) *v1.Table {
	out := &v1.Table{}
	for _, a := range t.Alignments {
		switch a {
		case extast.AlignLeft:
			out.Align = append(out.Align, v1.Table_ALIGN_LEFT)
		case extast.AlignCenter:
			out.Align = append(out.Align, v1.Table_ALIGN_CENTER)
		case extast.AlignRight:
			out.Align = append(out.Align, v1.Table_ALIGN_RIGHT)
		default:
			out.Align = append(out.Align, v1.Table_ALIGN_UNSPECIFIED)
		}
	}
	for r := t.FirstChild(); r != nil; r = r.NextSibling() {
		var cells []*v1.TableCell
		for c := r.FirstChild(); c != nil; c = c.NextSibling() {
			cells = append(cells, &v1.TableCell{Spans: inlines(c, src)})
		}
		if _, ok := r.(*extast.TableHeader); ok {
			out.Header = cells
		} else {
			out.Rows = append(out.Rows, &v1.TableRow{Cells: cells})
		}
	}
	return out
}

type style struct {
	bold, italic, code, strike bool
	link                       string
}

type inliner struct {
	src   []byte
	spans []*v1.Span
}

func inlines(n ast.Node, src []byte) []*v1.Span {
	w := &inliner{src: src}
	w.walk(n, style{})
	if len(w.spans) > 0 {
		last := w.spans[len(w.spans)-1]
		last.Text = strings.TrimRight(last.Text, " \n")
		if last.Text == "" {
			w.spans = w.spans[:len(w.spans)-1]
		}
	}
	return w.spans
}

func (w *inliner) walk(n ast.Node, st style) {
	for c := n.FirstChild(); c != nil; c = c.NextSibling() {
		switch x := c.(type) {
		case *ast.Text:
			w.add(string(x.Segment.Value(w.src)), st)
			if x.HardLineBreak() {
				w.add("\n", st)
			} else if x.SoftLineBreak() {
				w.add(" ", st)
			}
		case *ast.String:
			w.add(string(x.Value), st)
		case *ast.CodeSpan:
			s := st
			s.code = true
			w.walk(x, s)
		case *ast.Emphasis:
			s := st
			if x.Level >= 2 {
				s.bold = true
			} else {
				s.italic = true
			}
			w.walk(x, s)
		case *extast.Strikethrough:
			s := st
			s.strike = true
			w.walk(x, s)
		case *ast.Link:
			s := st
			s.link = string(x.Destination)
			w.walk(x, s)
		case *ast.AutoLink:
			s := st
			s.link = string(x.URL(w.src))
			w.add(string(x.Label(w.src)), s)
		case *ast.Image:
			s := st
			s.link = string(x.Destination)
			w.walk(x, s)
		case *ast.RawHTML:
			for i := 0; i < x.Segments.Len(); i++ {
				seg := x.Segments.At(i)
				w.add(string(seg.Value(w.src)), st)
			}
		case *extast.TaskCheckBox:
		default:
			w.walk(c, st)
		}
	}
}

func (w *inliner) add(s string, st style) {
	if s == "" {
		return
	}
	if n := len(w.spans); n > 0 {
		last := w.spans[n-1]
		if last.Bold == st.bold && last.Italic == st.italic && last.Code == st.code && last.Strike == st.strike && last.Link == st.link {
			last.Text += s
			return
		}
	} else {
		s = strings.TrimLeft(s, " ")
		if s == "" {
			return
		}
	}
	w.spans = append(w.spans, &v1.Span{Text: s, Bold: st.bold, Italic: st.italic, Code: st.code, Strike: st.strike, Link: st.link})
}

func plain(spans []*v1.Span) string {
	var b strings.Builder
	for _, s := range spans {
		b.WriteString(s.Text)
	}
	return b.String()
}
