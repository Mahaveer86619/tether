package render

import (
	"bufio"
	"encoding/base64"
	"os"
	"sort"
	"strings"
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

func TestQueuedPlaceholderUntilTakenIn(t *testing.T) {
	b := NewBuilder()
	enqueue := []byte(`{"type":"queue-operation","operation":"enqueue","timestamp":"2026-10-11T14:00:36.931Z","content":"check adb"}`)
	absorbed := []byte(`{"type":"queue-operation","operation":"remove","reason":"absorbed_mid_turn","timestamp":"2026-10-11T14:00:56.308Z","content":"check adb"}`)
	first := b.Feed(enqueue).Items
	if len(first) != 1 || !first[0].GetUser().GetQueued() || first[0].GetUser().GetText() != "check adb" {
		t.Fatalf("enqueue should show a queued placeholder, got %v", first)
	}
	gone := b.Feed(absorbed).Items
	if len(gone) != 1 || gone[0].ItemId != first[0].ItemId || gone[0].Kind != nil {
		t.Fatalf("taking it in should clear the placeholder, got %v", gone)
	}
	b.Feed(enqueue)
	popped := b.Feed([]byte(`{"type":"queue-operation","operation":"popAll","timestamp":"2026-10-11T14:01:00Z"}`)).Items
	if len(popped) != 1 || popped[0].Kind != nil {
		t.Fatalf("popAll should clear every placeholder, got %v", popped)
	}
}

func TestDequeueWithoutTextClearsOldestPlaceholder(t *testing.T) {
	b := NewBuilder()
	first := b.Feed([]byte(`{"type":"queue-operation","operation":"enqueue","timestamp":"2026-10-12T08:46:40.895Z","content":"check startup apps"}`)).Items
	gone := b.Feed([]byte(`{"type":"queue-operation","operation":"dequeue","timestamp":"2026-10-12T08:46:41.029Z"}`)).Items
	if len(gone) != 1 || gone[0].ItemId != first[0].ItemId || gone[0].Kind != nil {
		t.Fatalf("a dequeue with no content should clear the oldest placeholder, got %v", gone)
	}
}

func TestQueuedMessageMatchesStdoutReplay(t *testing.T) {
	b := NewBuilder()
	replay := b.Feed([]byte(`{"type":"user","uuid":"src1","message":{"role":"user","content":"also check adb"}}`)).Items
	attached := b.Feed([]byte(`{"type":"attachment","uuid":"att1","attachment":{"type":"queued_command","prompt":"also check adb","commandMode":"prompt","source_uuid":"src1"}}`)).Items
	if len(replay) != 1 || len(attached) != 1 || replay[0].ItemId != attached[0].ItemId {
		t.Fatalf("the transcript copy should reuse the stdout replay's id, got %v and %v", replay, attached)
	}
}

func TestTaskNotificationIsNotUserText(t *testing.T) {
	b := NewBuilder()
	line := []byte(`{"type":"user","uuid":"n1","promptSource":"system","message":{"role":"user","content":"<task-notification>\n<task-id>b1</task-id>\n<status>completed</status>\n</task-notification>"}}`)
	if items := b.Feed(line).Items; len(items) != 0 {
		t.Fatalf("a background task notification should not show as a message, got %v", items)
	}
}

func TestQueuedMessageShowsAsUserText(t *testing.T) {
	b := NewBuilder()
	queued := []byte(`{"type":"attachment","uuid":"q1","attachment":{"type":"queued_command","prompt":"also check adb","commandMode":"prompt"}}`)
	notification := []byte(`{"type":"attachment","uuid":"q2","attachment":{"type":"queued_command","prompt":"<task-notification>x</task-notification>","commandMode":"task-notification"}}`)
	var items []*v1.TimelineItem
	for _, l := range [][]byte{queued, queued, notification} {
		items = append(items, b.Feed(l).Items...)
	}
	if len(items) != 2 || items[0].ItemId != items[1].ItemId || items[0].GetUser().GetText() != "also check adb" {
		t.Fatalf("want the queued prompt once (re-emitted under one id), got %v", items)
	}
}

func TestQueuedMessageWithAPicture(t *testing.T) {
	b := NewBuilder()
	png := base64.StdEncoding.EncodeToString([]byte("PNGDATA"))
	line := []byte(`{"type":"attachment","uuid":"q9","attachment":{"type":"queued_command","commandMode":"prompt","prompt":[` +
		`{"type":"text","text":"look at this screen"},` +
		`{"type":"image","source":{"type":"base64","media_type":"image/png","data":"` + png + `"}}]}}`)
	out := b.Feed(line)
	if len(out.Items) != 1 || !strings.Contains(out.Items[0].GetUser().GetText(), "look at this screen") {
		t.Fatalf("a message with a picture should still show its text, got %v", out.Items)
	}
	if len(out.Images) != 1 || string(out.Images[0].Data) != "PNGDATA" || out.Images[0].ItemID != out.Items[0].ItemId {
		t.Fatalf("the picture should be handed over with its message's id, got %v", out.Images)
	}
}

func TestPermissionModeComesFromTheTranscript(t *testing.T) {
	b := NewBuilder()
	out := b.Feed([]byte(`{"type":"user","uuid":"u1","permissionMode":"plan","message":{"role":"user","content":"look first"}}`))
	if out.Patch.Mode != "plan" {
		t.Fatalf("mode: %q", out.Patch.Mode)
	}
	out = b.Feed([]byte(`{"type":"user","uuid":"u2","isSidechain":true,"permissionMode":"default","message":{"role":"user","content":"sub"}}`))
	if out.Patch.Mode != "" {
		t.Fatalf("a subagent's line shouldn't set the session's mode: %q", out.Patch.Mode)
	}
}
