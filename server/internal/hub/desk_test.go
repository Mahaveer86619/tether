package hub

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"testing"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func userItem(id string, ts int64, text string) *v1.TimelineItem {
	return &v1.TimelineItem{ItemId: id, TsMs: ts, Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: text}}}
}

func replyItem(id string, ts int64, text string) *v1.TimelineItem {
	return &v1.TimelineItem{ItemId: id, TsMs: ts, Kind: &v1.TimelineItem_Markdown{Markdown: &v1.Markdown{Blocks: []*v1.Block{
		{Kind: &v1.Block_Paragraph{Paragraph: &v1.Paragraph{Spans: []*v1.Span{{Text: text}}}}},
	}}}}
}

// tenPrompts gives the chat's active session ten prompts, each answered.
func tenPrompts(h *Hub, session string) {
	var items []*v1.TimelineItem
	for i := 1; i <= 10; i++ {
		items = append(items,
			userItem(fmt.Sprintf("u%d", i), int64(i*10), fmt.Sprintf("prompt %d", i)),
			replyItem(fmt.Sprintf("m%d", i), int64(i*10+1), fmt.Sprintf("reply %d", i)))
	}
	h.mu.Lock()
	h.commit(session, items)
	h.mu.Unlock()
}

func TestRewindingToTheThirdFromLastPromptStartsFromThere(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"prompt 1","target":{"node":"laptop","cwd":"/src/app"}}`)
	nextCommand(t, agent, ctx, isStart)
	old := c.ActiveSession
	tenPrompts(h, old)

	status, body := call(t, srv, "POST", "/api/v1/chats/"+c.Id+"/rewind", "secret", `{"itemId":"u8","mode":"text"}`)
	if status != 200 {
		t.Fatalf("rewind: %d %s", status, body)
	}
	var res rewindResult
	if err := json.Unmarshal([]byte(body), &res); err != nil {
		t.Fatal(err)
	}
	if res.Text != "prompt 8" || res.Prompt != 8 || res.Back != 3 || res.Mode != modeText || res.Session == "" || res.Session == old {
		t.Fatalf("result %+v", res)
	}

	start := nextCommand(t, agent, ctx, isStart).GetStart()
	if start.Session != res.Session || start.Cwd != "/src/app" {
		t.Fatalf("start %v", start)
	}
	history, _, _ := strings.Cut(start.Prompt, "\n\n---\n\n")
	if !strings.HasSuffix(history, "Claude: reply 7") || strings.Contains(start.Prompt, "User: prompt 8") || !strings.Contains(history, "User: prompt 1") {
		t.Fatalf("carried context should end at prompt 8:\n%s", start.Prompt)
	}

	h.mu.Lock()
	chat := h.chats[c.Id]
	roles := map[string]string{}
	for _, l := range chat.Sessions {
		roles[l.Session] = l.Role
	}
	active := chat.ActiveSession
	h.mu.Unlock()
	if active != res.Session || roles[old] != linkRewound || roles[res.Session] != linkMoved {
		t.Fatalf("active %s roles %v", active, roles)
	}

	// The new line of the chat no longer has what was rewound over, nor the
	// message that carried it.
	h.mu.Lock()
	h.commit(res.Session, []*v1.TimelineItem{
		userItem("n0", 200, start.Prompt), replyItem("n1", 201, "Ready."), userItem("n2", 202, "prompt 8, put better"),
	})
	h.mu.Unlock()
	_, body = call(t, srv, "GET", "/api/v1/chats/"+c.Id+"/desk", "secret", "")
	var d deskView
	if err := json.Unmarshal([]byte(body), &d); err != nil {
		t.Fatal(err)
	}
	last := d.Prompts[len(d.Prompts)-1]
	if len(d.Prompts) != 8 || last.Text != "prompt 8, put better" || last.N != 8 {
		t.Fatalf("prompts %+v", d.Prompts)
	}
	if len(d.Rewinds) != 1 || d.Rewinds[0].Old != old || d.Rewinds[0].Prompt != 8 {
		t.Fatalf("rewinds %+v", d.Rewinds)
	}

	// Asking for the fork path carries as text for now, and says so.
	_, body = call(t, srv, "POST", "/api/v1/chats/"+c.Id+"/rewind", "secret", `{"itemId":"u2","mode":"fork"}`)
	if err := json.Unmarshal([]byte(body), &res); err != nil || res.Mode != modeText || res.Note == "" || res.Text != "prompt 2" {
		t.Fatalf("fork fallback %s", body)
	}

	for _, bad := range []string{`{"itemId":"m3"}`, `{"itemId":"nope"}`, `{}`, `{"itemId":"u1","mode":"x"}`} {
		if status, _ := call(t, srv, "POST", "/api/v1/chats/"+c.Id+"/rewind", "secret", bad); status == 200 {
			t.Fatalf("%s was accepted", bad)
		}
	}
}

func TestARecapIsNotedWhenATurnEnds(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"prompt 1","target":{"node":"laptop","cwd":"/src/app"}}`)
	nextCommand(t, agent, ctx, isStart)
	tenPrompts(h, c.ActiveSession)
	h.mu.Lock()
	h.commit(c.ActiveSession, []*v1.TimelineItem{replyItem("m10", 101, "## Done\n\nThe login test passes now.\n\n```\ncode\n```\nCI is green.\nMore detail.")})
	s := h.sessions[c.ActiveSession]
	s.Todos = []*v1.Todo{{Content: "Fix signup", Status: v1.Todo_STATUS_PENDING}, {Content: "Fix login", Status: v1.Todo_STATUS_COMPLETED}}
	h.noteTurnEnded(c.ActiveSession)
	note := h.chatNote(c.Id, noteRecap)
	h.mu.Unlock()

	var r recap
	if err := json.Unmarshal([]byte(note), &r); err != nil {
		t.Fatalf("recap %q: %v", note, err)
	}
	if r.Asked != "prompt 10" || r.Done != "Done The login test passes now. CI is green." || r.Prompt != 10 || len(r.Open) != 1 || r.Open[0] != "Fix signup" {
		t.Fatalf("recap %+v", r)
	}
}

func TestAHandoffCarriesAStructuredSummaryToAFreshSession(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"Make the importer resumable","target":{"node":"laptop","cwd":"/src/app"}}`)
	nextCommand(t, agent, ctx, isStart)
	old := c.ActiveSession
	h.mu.Lock()
	h.commit(old, []*v1.TimelineItem{
		userItem("u1", 10, "Make the importer resumable"),
		replyItem("m1", 11, "We decided to keep a cursor table instead of a file."),
		{ItemId: "t1", TsMs: 12, Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{Name: "Edit", Detail: &v1.ToolCard_Edit{Edit: &v1.EditCard{Path: "/src/app/importer.go"}}}}},
		userItem("u2", 20, "Never drop the old table."),
		replyItem("m2", 21, "Understood."),
		userItem("u3", 30, "now the tests"),
		replyItem("m3", 31, "Tests added.\nNext step: run them on CI."),
	})
	h.mu.Unlock()

	_, body := call(t, srv, "GET", "/api/v1/chats/"+c.Id+"/desk", "secret", "")
	var d deskView
	if err := json.Unmarshal([]byte(body), &d); err != nil || d.Context.Prompts != 3 || d.Context.Tokens == 0 || d.Context.FromUsage || d.Context.HandoffAt != defaultHandoffTokens {
		t.Fatalf("desk %s", body)
	}
	if err := h.store.PutUsage("laptop", []*v1.UsageEntry{{Session: old, MessageId: "x", TsMs: 5, Input: 10, CacheRead: 180_000, CacheWrite: 90}}); err != nil {
		t.Fatal(err)
	}
	_, body = call(t, srv, "GET", "/api/v1/chats/"+c.Id+"/desk", "secret", "")
	if err := json.Unmarshal([]byte(body), &d); err != nil || d.Context.Tokens != 180_100 || !d.Context.FromUsage {
		t.Fatalf("desk with usage %s", body)
	}

	status, body := call(t, srv, "POST", "/api/v1/chats/"+c.Id+"/handoff", "secret", `{}`)
	if status != 200 {
		t.Fatalf("handoff: %d %s", status, body)
	}
	var res rewindResult
	if err := json.Unmarshal([]byte(body), &res); err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		carryHandoff, "## Goal\n\nMake the importer resumable", "## Decisions and instructions", "- We decided to keep a cursor table instead of a file.",
		"- Never drop the old table.", "## Open items", "- Next step: run them on CI.", "## Files touched", "- /src/app/importer.go",
		"## The last turns, as they were", "**User:** now the tests",
	} {
		if !strings.Contains(res.Text, want) {
			t.Fatalf("summary is missing %q:\n%s", want, res.Text)
		}
	}

	start := nextCommand(t, agent, ctx, isStart).GetStart()
	sent := start.Prompt
	if len(start.Attachments) == 1 {
		b, err := os.ReadFile(h.blobPath(start.Attachments[0].Sha256))
		if err != nil {
			t.Fatal(err)
		}
		sent = string(b)
	}
	if start.Session != res.Session || !strings.HasPrefix(sent, res.Text) {
		t.Fatalf("start %v", start)
	}
	h.mu.Lock()
	chat := h.chats[c.Id]
	role := ""
	for _, l := range chat.Sessions {
		if l.Session == res.Session {
			role = l.Role
		}
	}
	h.mu.Unlock()
	if chat.ActiveSession != res.Session || role != linkHandoff {
		t.Fatalf("active %s role %q", chat.ActiveSession, role)
	}

	status, body = call(t, srv, "PUT", "/api/v1/desk", "secret", `{"handoffTokens":90000}`)
	if status != 200 || !strings.Contains(body, "90000") {
		t.Fatalf("settings: %d %s", status, body)
	}
	status, body = call(t, srv, "PUT", "/api/v1/chats/"+c.Id+"/desk", "secret", `{"remind":true}`)
	if status != 200 || !strings.Contains(body, `"remind":true`) || !strings.Contains(body, `"handoffAt":90000`) {
		t.Fatalf("remind: %d %s", status, body)
	}
}
