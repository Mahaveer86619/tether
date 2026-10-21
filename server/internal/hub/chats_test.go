package hub

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func nextCommand(t *testing.T, agent *wire.Conn, ctx context.Context, want func(*v1.AgentCommand) bool) *v1.AgentCommand {
	t.Helper()
	for {
		f, err := agent.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		if c := f.GetAgentCommand(); c != nil && want(c) {
			return c
		}
	}
}

func isStart(c *v1.AgentCommand) bool { return c.GetStart() != nil }
func isSend(c *v1.AgentCommand) bool  { return c.GetSend() != nil }

func postChat(t *testing.T, srv *httptest.Server, path, body string) *v1.Chat {
	t.Helper()
	status, out := call(t, srv, "POST", path, "secret", body)
	c := &v1.Chat{}
	if status != 200 || protojson.Unmarshal([]byte(out), c) != nil {
		t.Fatalf("%s: %d %s", path, status, out)
	}
	return c
}

func TestAChatStartsItsSessionAndFollowsIt(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)

	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"Please fix the flaky login test.\nIt fails on CI.","target":{"node":"laptop","cwd":"/src/tether"}}`)
	if c.Title != "Fix the flaky login test" || c.TitleByUser {
		t.Fatalf("title %q", c.Title)
	}
	if c.Target.Mode != targetManual || c.Target.State != targetResolved || c.Target.Cwd != "/src/tether" {
		t.Fatalf("target %v", c.Target)
	}
	if len(c.Sessions) != 1 || c.Sessions[0].Role != linkMain || c.Sessions[0].Session != c.ActiveSession {
		t.Fatalf("links %v", c.Sessions)
	}
	start := nextCommand(t, agent, ctx, isStart).GetStart()
	if start.Session != c.ActiveSession || start.Cwd != "/src/tether" || !strings.Contains(start.SystemPrompt, c.Id) {
		t.Fatalf("start %v", start)
	}

	// Messages go to the active session, with the chat's system prompt for a resume.
	status, body := call(t, srv, "POST", "/api/v1/chats/"+c.Id+"/messages", "secret", `{"text":"and the signup one"}`)
	if status != 200 {
		t.Fatalf("send: %d %s", status, body)
	}
	send := nextCommand(t, agent, ctx, isSend).GetSend()
	if send.Session != c.ActiveSession || send.Text != "and the signup one" || !strings.Contains(send.SystemPrompt, c.Id) {
		t.Fatalf("send %v", send)
	}

	// What's said is kept with the chat, even once the session is gone.
	h.mu.Lock()
	h.commit(c.ActiveSession, []*v1.TimelineItem{
		{ItemId: "u1", TsMs: 1, Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "Please fix the flaky login test."}}},
		{ItemId: "m1", TsMs: 2, Kind: &v1.TimelineItem_Markdown{Markdown: &v1.Markdown{Blocks: []*v1.Block{{Kind: &v1.Block_Paragraph{Paragraph: &v1.Paragraph{Spans: []*v1.Span{{Text: "Fixed: a race in setup."}}}}}}}}},
		{ItemId: "t1", TsMs: 3, Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{Name: "Bash"}}},
	})
	h.mu.Unlock()
	if err := h.store.DeleteSession(c.ActiveSession); err != nil {
		t.Fatal(err)
	}
	_, body = call(t, srv, "GET", "/api/v1/chats/"+c.Id+"/context", "secret", "")
	cx := &v1.ChatContext{}
	if err := protojson.Unmarshal([]byte(body), cx); err != nil {
		t.Fatal(err)
	}
	if len(cx.Messages) != 2 || cx.Messages[0].Role != "user" || cx.Messages[1].Text != "Fixed: a race in setup." {
		t.Fatalf("messages %v", cx.Messages)
	}
	if len(cx.Notes) != 1 || cx.Notes[0].Kind != "title" || cx.Notes[0].Value != "Fix the flaky login test" {
		t.Fatalf("notes %v", cx.Notes)
	}
}

func TestRenamingAChatSticksUntilCleared(t *testing.T) {
	h, srv := newTestHubWith(t)
	dialAgent(t, h, srv.URL)
	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"add dark mode","target":{"node":"laptop"}}`)

	status, body := call(t, srv, "PATCH", "/api/v1/chats/"+c.Id, "secret", `{"title":"Theme work"}`)
	if status != 200 || !strings.Contains(body, "Theme work") {
		t.Fatalf("rename: %d %s", status, body)
	}
	h.mu.Lock()
	h.noteTurnEnded(c.ActiveSession)
	title := h.chats[c.Id].Title
	h.mu.Unlock()
	if title != "Theme work" {
		t.Fatalf("the title job overrode the user's title: %q", title)
	}

	call(t, srv, "PATCH", "/api/v1/chats/"+c.Id, "secret", `{"title":""}`)
	h.mu.Lock()
	title, byUser := h.chats[c.Id].Title, h.chats[c.Id].TitleByUser
	h.mu.Unlock()
	if title != "Add dark mode" || byUser {
		t.Fatalf("cleared title: %q %v", title, byUser)
	}

	call(t, srv, "PATCH", "/api/v1/chats/"+c.Id, "secret", `{"archived":true}`)
	_, body = call(t, srv, "GET", "/api/v1/state", "secret", "")
	w := &v1.Welcome{}
	if err := protojson.Unmarshal([]byte(body), w); err != nil || len(w.Chats) != 1 || !w.Chats[0].Archived {
		t.Fatalf("welcome chats: %s", body)
	}
}

func TestForkingTheActiveSessionMovesTheChatAlong(t *testing.T) {
	h, srv := newTestHubWith(t)
	dialAgent(t, h, srv.URL)
	c := postChat(t, srv, "/api/v1/chats", `{"session":"s1"}`)
	if c.ActiveSession != "s1" || c.Title != "existing" || c.Target.Node != "laptop" {
		t.Fatalf("adopted %v", c)
	}
	// Adopting again returns the same chat.
	if again := postChat(t, srv, "/api/v1/chats", `{"session":"s1"}`); again.Id != c.Id {
		t.Fatalf("a second chat for s1: %s", again.Id)
	}

	_, body := call(t, srv, "POST", "/api/v1/sessions/s1/messages", "secret", `{"text":"other way","fork":true}`)
	ack := &v1.Ack{}
	_ = protojson.Unmarshal([]byte(body), ack)
	h.mu.Lock()
	got := h.chats[c.Id]
	h.mu.Unlock()
	if got.ActiveSession != ack.Session || len(got.Sessions) != 2 || got.Sessions[1].Role != linkFork {
		t.Fatalf("after fork %v", got)
	}

	status, _ := call(t, srv, "POST", "/api/v1/chats/"+c.Id+"/links", "secret", `{"session":"`+ack.Session+`","unlink":true}`)
	h.mu.Lock()
	got = h.chats[c.Id]
	h.mu.Unlock()
	if status != 200 || got.ActiveSession != "s1" || len(got.Sessions) != 1 {
		t.Fatalf("unlink: %d %v", status, got)
	}
}

func TestAutoTargetMatchesThePromptOrHandsOverToClaude(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	h.mu.Lock()
	h.putSession(&v1.SessionInfo{Id: "p1", Node: "laptop", Cwd: `C:\Users\me\projects\personal\tether`, UpdatedMs: 100})
	h.putSession(&v1.SessionInfo{Id: "p2", Node: "laptop", Cwd: `C:\Users\me\work\GitLab\fk-cn`, UpdatedMs: 200})
	h.putSession(&v1.SessionInfo{Id: "p3", Node: "laptop", Cwd: `/tmp/scratch/x`, Scratch: true, UpdatedMs: 300})
	h.mu.Unlock()

	_, body := call(t, srv, "GET", "/api/v1/targets?prompt=the+Tether+app+crashes+on+start", "secret", "")
	sug := &v1.TargetSuggestions{}
	if err := protojson.Unmarshal([]byte(body), sug); err != nil {
		t.Fatal(err)
	}
	if sug.Pick == nil || sug.Pick.Label != "tether" || sug.Candidates[0].Label != "tether" {
		t.Fatalf("suggestions %s", body)
	}
	for _, c := range sug.Candidates {
		if c.Label == "x" {
			t.Fatal("scratch folders aren't suggested")
		}
	}

	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"the fkcn deploy is broken"}`)
	if c.Target.Mode != targetAuto || !strings.HasSuffix(c.Target.Cwd, "fk-cn") || !strings.Contains(c.Target.Reason, "fk-cn") {
		t.Fatalf("auto target %v", c.Target)
	}
	nextCommand(t, agent, ctx, isStart)

	c = postChat(t, srv, "/api/v1/chats", `{"prompt":"what's a good name for a cat?"}`)
	if c.Target.Mode != targetClaude || c.Target.State != targetDetecting || !c.Target.Scratch {
		t.Fatalf("fallback target %v", c.Target)
	}
	start := nextCommand(t, agent, ctx, isStart).GetStart()
	if !start.Scratch || !strings.Contains(start.SystemPrompt, "set_chat_target") {
		t.Fatalf("detecting start %v", start)
	}

	// Claude reports where it belongs; the chat moves there with its history.
	h.mu.Lock()
	h.commit(c.ActiveSession, []*v1.TimelineItem{{ItemId: "u", TsMs: 1, Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "what's a good name for a cat?"}}}})
	h.mu.Unlock()
	_, m := rpc(t, srv, "secret", `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"set_chat_target","arguments":{"chat":"`+c.Id+`","node":"laptop","cwd":"C:\\pets","reason":"pets live there"}}}`)
	if text := toolText(t, m); !strings.Contains(text, "continues in session") {
		t.Fatalf("set_chat_target: %s", text)
	}
	moved := nextCommand(t, agent, ctx, isStart).GetStart()
	if moved.Cwd != `C:\pets` || moved.Scratch || !strings.Contains(moved.Prompt, "User: what's a good name for a cat?") {
		t.Fatalf("moved start %v", moved)
	}
	if strings.Contains(moved.SystemPrompt, "set_chat_target") {
		t.Fatal("the moved session was asked to detect its target again")
	}
	h.mu.Lock()
	got := h.chats[c.Id]
	h.mu.Unlock()
	if got.ActiveSession != moved.Session || got.Target.State != targetResolved || got.Target.Reason != "pets live there" || got.Sessions[1].Role != linkMoved {
		t.Fatalf("after move %v", got)
	}

	// A session Claude starts for the chat is linked to it.
	_, m = rpc(t, srv, "secret", `{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"start_session","arguments":{"prompt":"check the logs","node":"laptop","chat":"`+c.Id+`"}}}`)
	toolText(t, m)
	h.mu.Lock()
	got = h.chats[c.Id]
	h.mu.Unlock()
	if len(got.Sessions) != 3 || got.Sessions[2].Role != linkStarted || got.ActiveSession != moved.Session {
		t.Fatalf("started link %v", got.Sessions)
	}
}

func TestOldAgentsGetDetectionInstructionsInline(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	h.mu.Lock()
	h.nodes["laptop"].AgentVersion = "0.15.0"
	h.mu.Unlock()
	postChat(t, srv, "/api/v1/chats", `{"prompt":"hello there","target":{"mode":"claude"}}`)
	start := nextCommand(t, agent, ctx, isStart).GetStart()
	if start.SystemPrompt != "" || !strings.Contains(start.Prompt, "set_chat_target") || !strings.HasSuffix(start.Prompt, "hello there") {
		t.Fatalf("start %v", start)
	}
}

func TestAutoTitle(t *testing.T) {
	cases := map[string]string{
		"hey can you add a dark mode toggle to settings?":   "Add a dark mode toggle to settings",
		"## Bug\n\n`flutter build` fails on Windows":         "Bug",
		"  fix it":                                           "Fix it",
		"My message is long, so it is in the attached file": "Long message",
		"Refactor the session navigator so that projects and devices share one tree widget and keep state": "Refactor the session navigator so that projects and devices…",
		"": "",
	}
	for in, want := range cases {
		if got := autoTitle(in); got != want {
			t.Errorf("autoTitle(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestTargetMatching(t *testing.T) {
	words := wordsOf("the SessionNavigator in tether-app is slow")
	text := " " + strings.Join(wordList("the SessionNavigator in tether-app is slow"), " ") + " "
	if s, _ := matchScore("/src/tether-app", words, text); s != scoreName {
		t.Errorf("tether-app: %v", s)
	}
	if s, _ := matchScore("/src/tether", words, text); s != scoreName {
		t.Errorf("tether: %v", s)
	}
	if s, _ := matchScore("/src/app", words, text); s != 0 {
		t.Errorf("a generic name matched: %v", s)
	}
	if s, _ := matchScore("/src/session-store", words, text); s != scoreWord {
		t.Errorf("one word: %v", s)
	}
	if got := wordList("fkCNDeploy_v2"); strings.Join(got, ",") != "fk,cn,deploy,v2" {
		t.Errorf("wordList: %v", got)
	}
	if !versionAtLeast("0.16.0", "0.16.0") || versionAtLeast("0.15.9", "0.16.0") || !versionAtLeast("dev", "0.16.0") || !versionAtLeast("1.0.0", "0.16.0") {
		t.Error("versionAtLeast")
	}
}
