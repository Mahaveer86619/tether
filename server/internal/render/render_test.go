package render

import (
	"bufio"
	"os"
	"sort"
	"testing"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func feedFile(t *testing.T, b *Builder, path string) (map[string]*v1.TimelineItem, []string, Patch) {
	t.Helper()
	f, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	items := map[string]*v1.TimelineItem{}
	var order []string
	var patch Patch
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1<<20), 16<<20)
	for sc.Scan() {
		out := b.Feed(sc.Bytes())
		if out.Patch.TodosSet {
			patch.Todos, patch.TodosSet = out.Patch.Todos, true
		}
		for _, it := range out.Items {
			if _, ok := items[it.ItemId]; !ok {
				order = append(order, it.ItemId)
			}
			items[it.ItemId] = it
		}
		if out.Patch.Cost != nil {
			patch.Cost = out.Patch.Cost
		}
		if out.Patch.Model != "" {
			patch.Model = out.Patch.Model
		}
	}
	if err := sc.Err(); err != nil {
		t.Fatal(err)
	}
	return items, order, patch
}

func TestStreamFixture(t *testing.T) {
	items, order, patch := feedFile(t, NewBuilder(), "testdata/stream.jsonl")

	cards := map[string]*v1.ToolCard{}
	var md []*v1.Markdown
	var users, results int
	for _, id := range order {
		it := items[id]
		switch k := it.Kind.(type) {
		case *v1.TimelineItem_Tool:
			cards[k.Tool.Name] = k.Tool
			if k.Tool.Status != v1.ToolCard_STATUS_SUCCEEDED {
				t.Errorf("%s card ended %v", k.Tool.Name, k.Tool.Status)
			}
		case *v1.TimelineItem_Markdown:
			if k.Markdown.Streaming {
				t.Errorf("markdown %s still streaming", id)
			}
			md = append(md, k.Markdown)
		case *v1.TimelineItem_Thinking:
			if k.Thinking.Streaming || k.Thinking.Text == "" {
				t.Errorf("thinking %s left streaming or empty", id)
			}
		case *v1.TimelineItem_User:
			users++
		case *v1.TimelineItem_Result:
			results++
		}
	}
	for _, name := range []string{"Write", "Edit", "Read"} {
		if cards[name] == nil {
			t.Errorf("missing %s card", name)
		}
	}
	if cards["Bash"] == nil && cards["PowerShell"] == nil {
		t.Error("missing shell card")
	}
	if e := cards["Edit"].GetEdit(); e == nil || e.Added == 0 || e.Removed == 0 || e.UnifiedDiff == "" {
		t.Errorf("edit card has no diff: %v", e)
	}
	if users != 1 || results != 1 {
		t.Errorf("users=%d results=%d", users, results)
	}
	if patch.Cost == nil || patch.Model == "" {
		t.Errorf("patch incomplete: %+v", patch)
	}

	kinds := map[string]bool{}
	for _, m := range md {
		for _, b := range m.Blocks {
			switch b.Kind.(type) {
			case *v1.Block_Heading:
				kinds["heading"] = true
			case *v1.Block_List:
				kinds["list"] = true
			case *v1.Block_Table:
				kinds["table"] = true
			case *v1.Block_Code:
				kinds["code"] = true
			}
		}
	}
	for _, k := range []string{"heading", "list", "table", "code"} {
		if !kinds[k] {
			t.Errorf("final answer has no %s block", k)
		}
	}
}

// The live stream and the transcript of the same session must produce the
// same assistant and tool items, so they can be mixed freely.
func TestStreamAndTranscriptAgree(t *testing.T) {
	s, _, _ := feedFile(t, NewBuilder(), "testdata/stream.jsonl")
	tr, _, _ := feedFile(t, NewBuilder(), "testdata/transcript.jsonl")

	for id, it := range tr {
		if it.GetResult() != nil {
			continue
		}
		other, ok := s[id]
		if !ok {
			t.Errorf("transcript item %s missing from stream", id)
			continue
		}
		a, b := proto.Clone(it).(*v1.TimelineItem), proto.Clone(other).(*v1.TimelineItem)
		a.TsMs, b.TsMs = 0, 0
		if !proto.Equal(a, b) {
			t.Errorf("item %s differs:\ntranscript: %v\nstream:     %v", id, a, b)
		}
	}
}

func TestTranscriptReplayKeepsToolOutcome(t *testing.T) {
	b := NewBuilder()
	first, _, _ := feedFile(t, b, "testdata/stream.jsonl")
	again, _, _ := feedFile(t, b, "testdata/transcript.jsonl")
	var ids []string
	for id := range again {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, id := range ids {
		if _, ok := first[id]; !ok && again[id].GetResult() == nil {
			t.Errorf("replay created new item %s", id)
		}
		if c := again[id].GetTool(); c != nil && c.Status != first[id].GetTool().GetStatus() {
			t.Errorf("%s status changed on replay: %v -> %v", id, first[id].GetTool().GetStatus(), c.Status)
		}
	}
}

func TestMarkdown(t *testing.T) {
	src := "# Title\n\nSome **bold** and `code` with [link](https://x.y).\n\n" +
		"- [x] done\n- [ ] todo\n\n| a | b |\n|:--|--:|\n| 1 | 2 |\n\n```go\nfmt.Println(1)\n```\n\n> quote\n\n---\n"
	bs := Markdown(src)
	want := []string{"heading", "paragraph", "list", "table", "code", "quote", "divider"}
	if len(bs) != len(want) {
		t.Fatalf("got %d blocks, want %d: %v", len(bs), len(want), bs)
	}
	p := bs[1].GetParagraph()
	if len(p.Spans) < 5 || !p.Spans[1].Bold || !p.Spans[3].Code || p.Spans[5].Link != "https://x.y" {
		t.Errorf("unexpected spans: %v", p.Spans)
	}
	l := bs[2].GetList()
	if l.Items[0].Checked == nil || !*l.Items[0].Checked || *l.Items[1].Checked {
		t.Errorf("task list not parsed: %v", l)
	}
	tb := bs[3].GetTable()
	if tb.Align[0] != v1.Table_ALIGN_LEFT || tb.Align[1] != v1.Table_ALIGN_RIGHT || len(tb.Rows) != 1 {
		t.Errorf("table not parsed: %v", tb)
	}
	if c := bs[4].GetCode(); c.Lang != "go" || c.Text != "fmt.Println(1)" {
		t.Errorf("code not parsed: %v", c)
	}
}

func TestStreamingCodeFenceStaysCode(t *testing.T) {
	bs := Markdown("Here:\n\n```python\nprint(1)\n")
	if len(bs) != 2 || bs[1].GetCode() == nil {
		t.Fatalf("unterminated fence should render as code: %v", bs)
	}
}

func TestTodoWrite(t *testing.T) {
	b := NewBuilder()
	line := `{"type":"assistant","message":{"id":"m1","content":[{"type":"tool_use","id":"tu1","name":"TodoWrite","input":{"todos":[` +
		`{"content":"Write tests","status":"completed","activeForm":"Writing tests"},` +
		`{"content":"Ship","status":"in_progress","activeForm":"Shipping"}]}}]}}`
	out := b.Feed([]byte(line))
	if !out.Patch.TodosSet || len(out.Patch.Todos) != 2 || out.Patch.Todos[1].Status != v1.Todo_STATUS_IN_PROGRESS {
		t.Fatalf("todos not extracted: %+v", out.Patch)
	}
	if c := out.Items[0].GetTool().GetTodos(); c == nil || len(c.Todos) != 2 {
		t.Fatalf("no todo card: %v", out.Items)
	}
}
