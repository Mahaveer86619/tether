package hub

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func shell(id, cmd string) *v1.TimelineItem {
	return &v1.TimelineItem{ItemId: id, Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{
		Name: "Bash", Status: v1.ToolCard_STATUS_SUCCEEDED, Detail: &v1.ToolCard_Shell{Shell: &v1.ShellCard{Command: cmd}},
	}}}
}

func TestSkillCandidatesAreListedFromStoredSessions(t *testing.T) {
	h, srv := newTestHubWith(t)
	now := time.Now().UnixMilli()
	asks := []string{"check the v2 sync progress", "what is the progress of the v2 sync??", "progress of sync"}
	for i, ask := range asks {
		id := fmt.Sprintf("sync%d", i)
		h.putSession(&v1.SessionInfo{Id: id, Node: "minipc", Cwd: "/srv/wvs", UpdatedMs: now})
		if _, _, err := h.store.PutItems(id, []*v1.TimelineItem{
			{ItemId: "u", Ord: 1, TsMs: now - int64(i)*3600_000, Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: ask}}},
			shell("a", "tmux ls"),
			shell("b", fmt.Sprintf("tail -n 40 ~/logs/run-202610%02d.log", 10+i)),
		}); err != nil {
			t.Fatal(err)
		}
	}
	res, body := request(t, "GET", srv.URL+"/api/v1/skills/candidates?days=30&runs=3", nil, nil)
	if res.StatusCode != http.StatusOK {
		t.Fatalf("status %d: %s", res.StatusCode, body)
	}
	var rep struct {
		Sessions   int
		Tasks      int
		Candidates []struct {
			Example  string
			Runs     int
			Sessions int
			Mutating bool
			Steps    []struct{ Key, Detail string }
		}
	}
	if err := json.Unmarshal(body, &rep); err != nil {
		t.Fatalf("%v: %s", err, body)
	}
	if len(rep.Candidates) != 1 {
		t.Fatalf("want the one routine: %s", body)
	}
	c := rep.Candidates[0]
	if c.Runs != 3 || c.Sessions != 3 || c.Mutating || len(c.Steps) != 2 || c.Steps[1].Detail != "tail -n 40 ~/logs/run-<date>.log" {
		t.Fatalf("candidate: %s", body)
	}
	if res, _ := request(t, "GET", srv.URL+"/api/v1/skills/candidates", nil, map[string]string{"Authorization": "Bearer nope"}); res.StatusCode != http.StatusUnauthorized {
		t.Fatalf("needs a token: %d", res.StatusCode)
	}
}

const syncSkillMD = `---
name: v2-sync-progress
description: Use when asked how far the v2 sync is, or "progress?" about the WVS sync on the mini PC.
---
# Steps
1. Read-only: run tmux ls and check that wvs-v2 is listed.
2. Read-only: tail the newest log under ~/logs and note the last pass.
3. Read-only: ask the dashboard for its state and read the per-machine table.
Report rows handled out of the total, images saved, the speed, and which machines are stuck.
`

func mcpCall(t *testing.T, srv *httptest.Server, tool string, args map[string]any) (string, bool) {
	t.Helper()
	b, _ := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": map[string]any{"name": tool, "arguments": args}})
	_, m := rpc(t, srv, "secret", string(b))
	res, _ := m["result"].(map[string]any)
	isErr, _ := res["isError"].(bool)
	return toolText(t, m), isErr
}

func TestASkillIsProposedApprovedUsedCorrectedAndRolledBack(t *testing.T) {
	_, srv := newTestHubWith(t)

	if msg, isErr := mcpCall(t, srv, "propose_skill", map[string]any{"skill_md": syncSkillMD + "\npassword=hunter2hunter2\n", "mutating": false}); !isErr || !strings.Contains(msg, "secret") {
		t.Fatalf("a skill with a secret is refused: %q %v", msg, isErr)
	}
	if msg, isErr := mcpCall(t, srv, "propose_skill", map[string]any{"skill_md": syncSkillMD, "mutating": false, "source": "progress?"}); isErr || !strings.Contains(msg, "approve") {
		t.Fatalf("propose: %q %v", msg, isErr)
	}
	if msg, _ := mcpCall(t, srv, "list_skills", nil); strings.Contains(msg, "v2-sync-progress") {
		t.Fatalf("a proposal is not usable yet: %q", msg)
	}
	if _, isErr := mcpCall(t, srv, "read_skill", map[string]any{"name": "v2-sync-progress"}); !isErr {
		t.Fatal("read_skill needs an approved skill")
	}

	_, body := request(t, "GET", srv.URL+"/api/v1/skills", nil, nil)
	if !strings.Contains(string(body), `"status":"proposed"`) || !strings.Contains(string(body), `"source":"progress?"`) {
		t.Fatalf("the owner sees the proposal: %s", body)
	}
	if res, _ := request(t, "POST", srv.URL+"/api/v1/skills/v2-sync-progress/approve", nil, nil); res.StatusCode != http.StatusOK {
		t.Fatalf("approve: %d", res.StatusCode)
	}
	if msg, _ := mcpCall(t, srv, "list_skills", nil); !strings.Contains(msg, "v2-sync-progress") || !strings.Contains(msg, `"version": 1`) {
		t.Fatalf("approved skills are listed: %q", msg)
	}
	if msg, isErr := mcpCall(t, srv, "read_skill", map[string]any{"name": "v2-sync-progress"}); isErr || !strings.Contains(msg, "tmux ls") {
		t.Fatalf("read_skill: %q", msg)
	}

	fixed := strings.Replace(syncSkillMD, "tail the newest log", "tail -n 60 the newest log", 1)
	if msg, isErr := mcpCall(t, srv, "update_skill", map[string]any{"name": "v2-sync-progress", "skill_md": fixed, "note": "tail showed too little"}); isErr || !strings.Contains(msg, "version 2") {
		t.Fatalf("update: %q %v", msg, isErr)
	}
	_, body = request(t, "GET", srv.URL+"/api/v1/skills/v2-sync-progress", nil, nil)
	var s struct {
		Versions []struct {
			N    int
			Note string
			MD   string
		}
	}
	if err := json.Unmarshal(body, &s); err != nil || len(s.Versions) != 2 || s.Versions[1].Note != "tail showed too little" {
		t.Fatalf("history: %s", body)
	}
	if res, _ := request(t, "POST", srv.URL+"/api/v1/skills/v2-sync-progress/rollback", strings.NewReader(`{"version":1}`), nil); res.StatusCode != http.StatusOK {
		t.Fatalf("rollback: %d", res.StatusCode)
	}
	if msg, _ := mcpCall(t, srv, "read_skill", map[string]any{"name": "v2-sync-progress"}); strings.Contains(msg, "tail -n 60") {
		t.Fatalf("rolled back: %q", msg)
	}

	if res, _ := request(t, "POST", srv.URL+"/api/v1/skills/v2-sync-progress/dismiss", nil, nil); res.StatusCode != http.StatusOK {
		t.Fatalf("dismiss: %d", res.StatusCode)
	}
	if _, isErr := mcpCall(t, srv, "read_skill", map[string]any{"name": "v2-sync-progress"}); !isErr {
		t.Fatal("a dismissed skill can't be read")
	}
	if res, _ := request(t, "GET", srv.URL+"/api/v1/skills/v2-sync-progress", nil, nil); res.StatusCode != http.StatusNotFound {
		t.Fatalf("hidden: %d", res.StatusCode)
	}
}

func TestTheChatLeadIsToldWhichSkillsItHas(t *testing.T) {
	h, srv := newTestHubWith(t)
	if _, err := h.lib().Propose(syncSkillMD, false, "progress?", "test", 1); err != nil {
		t.Fatal(err)
	}
	agent, ctx := dialAgent(t, h, srv.URL)
	postChat(t, srv, "/api/v1/chats", `{"prompt":"hello","target":{"mode":"claude"}}`)
	if p := nextCommand(t, agent, ctx, isStart).GetStart().SystemPrompt; strings.Contains(p, "v2-sync-progress") {
		t.Fatalf("a proposal is not offered: %q", p)
	}
	if _, err := h.lib().Approve("v2-sync-progress", 2); err != nil {
		t.Fatal(err)
	}
	postChat(t, srv, "/api/v1/chats", `{"prompt":"hello again","target":{"mode":"claude"}}`)
	p := nextCommand(t, agent, ctx, isStart).GetStart().SystemPrompt
	if !strings.Contains(p, "v2-sync-progress: Use when asked how far the v2 sync is") || !strings.Contains(p, "read_skill") {
		t.Fatalf("an approved skill is offered: %q", p)
	}
}

func TestDraftingASkillStartsASessionWithTheBrief(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	now := time.Now().UnixMilli()
	for i, ask := range []string{"check the v2 sync progress", "what is the progress of the v2 sync??", "progress of sync"} {
		id := fmt.Sprintf("sync%d", i)
		h.putSession(&v1.SessionInfo{Id: id, Node: "minipc", Cwd: "/srv/wvs", UpdatedMs: now})
		if _, _, err := h.store.PutItems(id, []*v1.TimelineItem{
			{ItemId: "u", Ord: 1, TsMs: now - int64(i)*3600_000, Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: ask}}},
			shell("a", "tmux ls"),
		}); err != nil {
			t.Fatal(err)
		}
	}
	if res, _ := request(t, "POST", srv.URL+"/api/v1/skills/draft", strings.NewReader(`{"example":"no such routine"}`), nil); res.StatusCode != http.StatusNotFound {
		t.Fatalf("unknown routine: %d", res.StatusCode)
	}
	// The app drafts from the example the routines list shows.
	_, listed := request(t, "GET", srv.URL+"/api/v1/skills/candidates?days=0&runs=2", nil, nil)
	var rep struct{ Candidates []struct{ Example string } }
	if err := json.Unmarshal(listed, &rep); err != nil || len(rep.Candidates) != 1 {
		t.Fatalf("one routine to draft from: %s", listed)
	}
	payload, _ := json.Marshal(map[string]string{"example": rep.Candidates[0].Example})
	res, body := request(t, "POST", srv.URL+"/api/v1/skills/draft", strings.NewReader(string(payload)), nil)
	if res.StatusCode != http.StatusOK || !strings.Contains(string(body), `"session"`) {
		t.Fatalf("draft: %d %s", res.StatusCode, body)
	}
	start := nextCommand(t, agent, ctx, isStart).GetStart()
	// The brief is long, so it reaches the session as an attached file.
	if len(start.Attachments) != 1 {
		t.Fatalf("the brief goes as a file: %v", start)
	}
	text, err := os.ReadFile(h.blobPath(start.Attachments[0].Sha256))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"propose_skill", "asked 3 times in 3 sessions", "progress of sync", "tmux ls"} {
		if !strings.Contains(string(text), want) {
			t.Errorf("the brief lacks %q:\n%s", want, text)
		}
	}
}
