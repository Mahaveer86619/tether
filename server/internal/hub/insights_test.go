package hub

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

const day = int64(24 * 3600 * 1000)

// seedInsights fills the store with a small history whose numbers are known:
// two chats in the window (one of them moved to a second session), a chat
// from before it, usage on two models plus one with no price, tool calls with
// failures, and lineage inside and outside the window.
func seedInsights(t *testing.T, h *Hub) {
	t.Helper()
	now := time.Now().UnixMilli()
	old := now - 40*day
	at := func(i int) int64 { return now - day + int64(i)*1000 }
	must := func(err error) {
		t.Helper()
		if err != nil {
			t.Fatal(err)
		}
	}
	msg := func(session, id, role, text string, ts int64) *v1.ChatMessage {
		return &v1.ChatMessage{Session: session, ItemId: id, Role: role, Text: text, TsMs: ts}
	}

	must(h.store.PutChat(&v1.Chat{Id: "A", Title: "login", UpdatedMs: now}))
	must(h.store.LinkSession("A", &v1.ChatLink{Session: "a1", Role: "main", LinkedMs: old}))
	must(h.store.LinkSession("A", &v1.ChatLink{Session: "a2", Role: "moved", LinkedMs: now}))
	must(h.store.PutChatMessages("A", []*v1.ChatMessage{
		msg("a1", "0", "user", "an old question from before the window", old),
		msg("a1", "1", "user", "please fix the login bug in the app", at(1)),
		msg("a1", "2", "assistant", "Fixed.", at(2)),
		msg("a1", "3", "user", "don't commit or push anything yet", at(3)),
		msg("a1", "4", "assistant", "Understood.", at(4)),
		// A copy the move made of what came before it: counted once.
		msg("a2", "3c", "user", "don't commit or push anything yet", at(3)),
		msg("a2", "5", "user", "please fix the login bug in the app now", at(5)),
		msg("a2", "6", "user", "please fix the login bug in the app", at(6)),
	}))
	must(h.store.PutChat(&v1.Chat{Id: "B", Title: "long", UpdatedMs: now}))
	must(h.store.LinkSession("B", &v1.ChatLink{Session: "b1", Role: "main", LinkedMs: now}))
	must(h.store.PutChatMessages("B", []*v1.ChatMessage{
		msg("b1", "1", "user", "My message is long, so it is in the attached file notes.md. Read it and respond.", at(10)),
		msg("b1", "2", "assistant", "Done, mail me at someone@example.com", at(11)),
		msg("b1", "3", "user", "yes", at(12)),
	}))
	must(h.store.PutChat(&v1.Chat{Id: "C", Title: "stale", UpdatedMs: old}))
	must(h.store.PutChatMessages("C", []*v1.ChatMessage{msg("c1", "1", "user", "something long ago", old)}))

	for _, e := range []*v1.LineageEvent{
		{Session: "a2", Parent: "a1", Kind: "move", AtMs: at(5)},
		{Session: "f1", Parent: "a1", Kind: "fork", AtMs: at(7)},
		{Session: "f0", Parent: "a1", Kind: "fork", AtMs: old},
	} {
		must(h.store.AddLineageEvent(e))
	}

	must(h.store.PutUsage("laptop", []*v1.UsageEntry{
		{Session: "a1", MessageId: "m1", Model: "claude-opus-5-5", TsMs: at(2), Input: 1_000_000, Output: 100_000, CacheRead: 2_000_000},
		{Session: "a2", MessageId: "m2", Model: "claude-sonnet-4-6", TsMs: at(6), Input: 1_000_000, CacheWrite: 1_000_000},
		{Session: "a2", MessageId: "m3", Model: "<synthetic>", TsMs: at(6), Input: 10},
		{Session: "a1", MessageId: "m0", Model: "claude-opus-5-5", TsMs: old, Input: 999},
	}))

	h.mu.Lock()
	h.putSession(&v1.SessionInfo{Id: "a1", Node: "laptop", Title: "Fix the login", UpdatedMs: now})
	h.mu.Unlock()
	tool := func(id, name string, status v1.ToolCard_Status, isErr bool, ts int64) *v1.TimelineItem {
		return &v1.TimelineItem{ItemId: id, TsMs: ts, Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{
			ToolUseId: id, Name: name, Status: status, Output: &v1.ToolOutput{IsError: isErr},
		}}}
	}
	_, _, err := h.store.PutItems("a1", []*v1.TimelineItem{
		tool("t1", "Bash", v1.ToolCard_STATUS_SUCCEEDED, false, at(2)),
		tool("t2", "Bash", v1.ToolCard_STATUS_FAILED, false, at(2)),
		tool("t3", "Read", v1.ToolCard_STATUS_SUCCEEDED, true, at(2)),
		tool("t4", "Edit", v1.ToolCard_STATUS_PENDING, false, at(2)),
		tool("t0", "Bash", v1.ToolCard_STATUS_SUCCEEDED, false, old),
	})
	must(err)

	h.mu.Lock()
	h.auditApproval("app:phone", &v1.ApprovalRequest{ToolName: "Bash", Session: "a1"}, v1.Decision_DECISION_ALLOW)
	h.auditApproval("app:phone", &v1.ApprovalRequest{ToolName: "Bash", Session: "a1"}, v1.Decision_DECISION_DENY)
	h.auditApproval("app:desk", &v1.ApprovalRequest{ToolName: "Write", Session: "a1"}, v1.Decision_DECISION_ALLOW)
	h.mu.Unlock()
}

func TestInsightStatsFromAKnownHistory(t *testing.T) {
	h, srv := newTestHubWith(t)
	seedInsights(t, h)
	code, body := call(t, srv, "GET", "/api/v1/insights/stats?days=30", "secret", "")
	if code != 200 {
		t.Fatalf("stats: %d %s", code, body)
	}
	var st insightStats
	if err := json.Unmarshal([]byte(body), &st); err != nil {
		t.Fatal(err)
	}
	check := func(name string, got, want any) {
		t.Helper()
		g, _ := json.Marshal(got)
		w, _ := json.Marshal(want)
		if string(g) != string(w) {
			t.Errorf("%s: got %s, want %s", name, g, w)
		}
	}
	check("chats", st.Chats, 2)
	check("messages", st.Messages, 9)
	check("prompts", st.Prompts, 6)
	check("messages per chat", st.MessagesPerChat, dist{Count: 2, Median: 3, P90: 6, Max: 6, Total: 9})
	check("prompts per chat", st.PromptsPerChat, dist{Count: 2, Median: 2, P90: 4, Max: 4, Total: 6})
	check("prompt lengths", st.PromptLengths, []labelled{{"under 100", 6}, {"100 to 499", 0}, {"500 to 1,999", 0}, {"2,000 and more", 0}})
	check("long as a file", st.LongAsFile, 1)
	check("chats with more than one session", st.MultiSessionChats, 1)
	check("lineage", st.Lineage, []labelled{{"fork", 1}, {"move", 1}})
	check("repeated prompts", st.RepeatedPrompts, 1)
	check("restarts", st.Restarts, 2)
	check("restarts back", st.RestartsBack, []restartsBack{{1, 1}, {2, 1}})
	check("phrase", st.Phrases[0], phraseCount{Label: "Don't commit or push", Rule: instructionPhrases[0].rule, Prompts: 1, Chats: 1})

	tk := st.Tokens
	check("tokens", []int64{int64(tk.Sessions), tk.Input, tk.Output, tk.CacheWrite, tk.CacheRead}, []int64{2, 2_000_010, 100_000, 1_000_000, 2_000_000})
	check("cache read share", tk.CacheReadShare, 0.4)
	check("per session", tk.PerSession, dist{Count: 2, Median: 2_000_010, P90: 3_100_000, Max: 3_100_000, Total: 5_100_010})
	check("top session", []any{tk.Top[0].Session, tk.Top[0].Title, tk.Top[0].Total}, []any{"a1", "Fix the login", 3_100_000})
	// Opus 5.5: 1M in at $4, 100k out at $20, 2M cache reads at $0.20 = 6.40;
	// Sonnet 4.6: 1M in at $3, 1M cache writes at $3.75 = 6.75.
	check("cost", []any{st.Cost.Estimate, st.Cost.USD, st.Cost.Unpriced}, []any{true, 13.15, 1})
	check("cost by model", st.Cost.ByModel, []modelCost{{"claude-sonnet-4-6", 1, 6.75}, {"claude-opus-5-5", 1, 6.4}})
	check("models", len(st.Models), 3)

	check("tool calls", []int{st.ToolCalls, st.ToolErrors}, []int{4, 2})
	check("tools", st.Tools, []toolCount{{"Bash", 2, 1}, {"Edit", 1, 0}, {"Read", 1, 1}})
	check("approvals", []int{st.Approvals.Allowed, st.Approvals.Denied}, []int{2, 1})
	check("approvals by tool", st.Approvals.ByTool, []approvalTool{{"Bash", 1, 1}, {"Write", 1, 0}})
	check("sample", st.Sample, sampleSize{Chats: 2, Messages: 9})

	_, all := call(t, srv, "GET", "/api/v1/insights/stats?days=0", "secret", "")
	var everything insightStats
	_ = json.Unmarshal([]byte(all), &everything)
	if everything.Chats != 3 || everything.Messages != 11 || len(everything.Lineage) != 2 || everything.Lineage[0] != (labelled{"fork", 2}) {
		t.Errorf("all of history: %d chats, %d messages, lineage %v", everything.Chats, everything.Messages, everything.Lineage)
	}
}

func TestAnApprovalDecisionIsRecorded(t *testing.T) {
	h, srv := newTestHubWith(t)
	dialAgent(t, h, srv.URL)
	h.mu.Lock()
	h.approvals["ap1"] = &v1.ApprovalRequest{ApprovalId: "ap1", Session: "s1", Node: "laptop", ToolName: "Bash"}
	h.mu.Unlock()
	if code, out := call(t, srv, "POST", "/api/v1/approvals/ap1", "secret", `{"decision":"DECISION_DENY"}`); code != 200 {
		t.Fatalf("decide: %d %s", code, out)
	}
	_, out := call(t, srv, "GET", "/api/v1/audit?kind=approval", "secret", "")
	if !strings.Contains(out, `"subject":"deny"`) || !strings.Contains(out, "tool=Bash session=s1") {
		t.Fatalf("audit: %s", out)
	}
}

func TestMaskingKeepsPrivateDetailsFromTheModel(t *testing.T) {
	in := `ssh me@box.tail1234.ts.net, open C:\Users\someone\src\x.go and /home/someone/.env on minipc ` +
		`at 192.168.1.20 with token=abcdef1234567890 sk-ant-api03-abcdefghijklmnopqrstuvwxyz https://intranet.example.com/x`
	got := maskForModel(in, []string{"minipc"})
	for _, leak := range []string{"someone", "tail1234", "minipc", "192.168", "abcdef1234567890", "sk-ant", "intranet", "me@"} {
		if strings.Contains(got, leak) {
			t.Errorf("%q survived: %s", leak, got)
		}
	}
	for _, kept := range []string{"<path>", "<device>", "<url>", "<email>"} {
		if !strings.Contains(got, kept) {
			t.Errorf("no %s in %s", kept, got)
		}
	}
}

func TestAnalyzeStartsASessionWithTheStatsAndAMaskedSampleAndSavesItsReport(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	seedInsights(t, h)
	code, out := call(t, srv, "POST", "/api/v1/insights/analyze", "secret", `{"days":30}`)
	if code != 200 {
		t.Fatalf("analyze: %d %s", code, out)
	}
	var rep insightReport
	_ = json.Unmarshal([]byte(out), &rep)
	if rep.Status != "running" || rep.Session == "" || rep.Sample != (sampleSize{2, 9}) {
		t.Fatalf("report: %+v", rep)
	}
	start := nextCommand(t, agent, ctx, isStart).GetStart()
	brief := start.Prompt
	if len(start.Attachments) == 1 {
		b, err := os.ReadFile(h.blobPath(start.Attachments[0].Sha256))
		if err != nil {
			t.Fatal(err)
		}
		brief = string(b)
	}
	if !strings.HasPrefix(brief, "Before anything else, read Tether's guide: call the tether tool tether_guide with topic \"data\"") {
		t.Fatalf("the brief should start with the guide: %.200s", brief)
	}
	for _, want := range []string{rep.ID, "save_insight", `"chats": 2`, "9 messages from 2 chats", "please fix the login bug", "<email>"} {
		if !strings.Contains(brief, want) {
			t.Errorf("the brief lacks %q", want)
		}
	}
	if strings.Contains(brief, "someone@example.com") || strings.Contains(brief, "before the window") {
		t.Error("the sample holds what it should not")
	}

	if _, err := h.mcpSaveInsight(rootID, map[string]any{"report_id": rep.ID, "summary": "x", "recommendations": []any{map[string]any{"kind": "nope", "title": "t", "text": "x"}}}); err == nil {
		t.Fatal("a bad kind is refused")
	}
	msg, err := h.mcpSaveInsight(rootID, map[string]any{
		"report_id": rep.ID, "title": "Long chats", "summary": "Chats run long.",
		"recommendations": `[{"kind":"rule","title":"No pushing","why":"said in 1 chat","text":"Do not push."},{"kind":"skill","title":"Fix login","text":"Fixes the login."}]`,
	})
	if err != nil || !strings.Contains(msg, "2 recommendations") {
		t.Fatalf("save: %v %s", err, msg)
	}
	_, list := call(t, srv, "GET", "/api/v1/insights", "secret", "")
	var got struct{ Reports []insightReport }
	_ = json.Unmarshal([]byte(list), &got)
	if len(got.Reports) != 1 || got.Reports[0].Status != "saved" || got.Reports[0].Title != "Long chats" || len(got.Reports[0].Recommendations) != 2 || got.Reports[0].Session != rep.Session {
		t.Fatalf("reports: %s", list)
	}
}

func TestASkillCanBeDraftedFromARecommendation(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	code, out := call(t, srv, "POST", "/api/v1/skills/draft", "secret", `{"example":"Check prod import","idea":"Runs the import check against production and reports failures."}`)
	if code != 200 || !strings.Contains(out, `"session"`) {
		t.Fatalf("draft: %d %s", code, out)
	}
	if p := nextCommand(t, agent, ctx, isStart).GetStart().Prompt; !strings.Contains(p, "Runs the import check") || !strings.Contains(p, "propose_skill") {
		t.Fatalf("prompt: %s", p)
	}
}
