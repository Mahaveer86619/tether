package hub

import (
	"encoding/json"
	"net/http"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/skills"
)

const prodSkillMD = `---
name: check-prod-import
description: Use when asked whether last night's import reached the production database.
needs_env: [DB_URL]
runs_on: laptop
effect: read
scripts: [.tether/skills/check-prod-import/check.py]
---
# Steps
1. Read-only: run python .tether/skills/check-prod-import/check.py with DB_URL from the project's .env.
2. Read-only: compare the row count with yesterday's and report both numbers.
`

const prodScript = "import os, psycopg\nprint(psycopg.connect(os.environ['DB_URL']).execute('select count(*) from imports').fetchone())\n"

const prodScriptPath = ".tether/skills/check-prod-import/check.py"

func approvedSkills(t *testing.T, h *Hub) {
	t.Helper()
	if _, err := h.lib().Propose(syncSkillMD, false, "progress?", "test", 1); err != nil {
		t.Fatal(err)
	}
	if _, err := h.lib().ProposeWith(prodSkillMD, map[string]string{prodScriptPath: prodScript}, false, "did the import land?", "test", 2); err != nil {
		t.Fatal(err)
	}
	for _, n := range []string{"v2-sync-progress", "check-prod-import"} {
		if _, err := h.lib().Approve(n, 3); err != nil {
			t.Fatal(err)
		}
	}
}

func TestSkillSearchRanksTheLibraryWithAReason(t *testing.T) {
	h, srv := newTestHubWith(t)
	approvedSkills(t, h)
	if _, err := h.lib().Propose(strings.Replace(syncSkillMD, "v2-sync-progress", "v3-sync-progress", 1), false, "x", "test", 4); err != nil {
		t.Fatal(err)
	}
	res, body := request(t, "GET", srv.URL+"/api/v1/skills/search?q="+url.QueryEscape("prod import"), nil, nil)
	var out struct {
		Results []struct {
			Name, Description, Reason, Effect string
			Score                             float64
			Version                           int
		}
	}
	if res.StatusCode != http.StatusOK || json.Unmarshal(body, &out) != nil || len(out.Results) == 0 {
		t.Fatalf("%d %s", res.StatusCode, body)
	}
	r := out.Results[0]
	if r.Name != "check-prod-import" || r.Score <= 0 || !strings.Contains(r.Reason, "import") || r.Effect != "read" || r.Version != 1 {
		t.Fatalf("first: %s", body)
	}
	_, body = request(t, "GET", srv.URL+"/api/v1/skills/search?q=syn", nil, nil)
	if !strings.Contains(string(body), `"v2-sync-progress"`) || strings.Contains(string(body), "v3-sync") {
		t.Fatalf("a word being typed matches, proposals don't: %s", body)
	}
	if _, body = request(t, "GET", srv.URL+"/api/v1/skills/search?q=", nil, nil); !strings.Contains(string(body), `"results":[]`) {
		t.Fatalf("empty query: %s", body)
	}
}

func TestAskingBySkillPinsItsTextInTheSystemPrompt(t *testing.T) {
	h, srv := newTestHubWith(t)
	approvedSkills(t, h)
	agent, ctx := dialAgent(t, h, srv.URL)

	if status, body := call(t, srv, "POST", "/api/v1/chats", "secret", `{"prompt":"go","skill":"no-such-skill","target":{"mode":"claude"}}`); status != http.StatusBadRequest || !strings.Contains(body, "no approved skill") {
		t.Fatalf("unknown skill: %d %s", status, body)
	}

	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"check last night","skill":"check-prod-import","target":{"node":"laptop","cwd":"/srv/wh"}}`)
	start := nextCommand(t, agent, ctx, isStart).GetStart()
	for _, want := range []string{
		`Use the skill "check-prod-import" (version 1) exactly to do: check last night`,
		"2. Read-only: compare the row count", prodScriptPath, "check_skill_scripts", "DB_URL", "effect: read", "its target",
	} {
		if !strings.Contains(start.SystemPrompt, want) {
			t.Errorf("the first system prompt lacks %q", want)
		}
	}
	if start.Prompt != "check last night" {
		t.Fatalf("the user's message is sent as typed: %q", start.Prompt)
	}

	// Corrected to version 2: a later ask pins the new text.
	fixed := strings.Replace(syncSkillMD, "tail the newest log", "tail -n 60 the newest log", 1)
	if _, err := h.lib().Update("v2-sync-progress", fixed, "more lines", "test", 5); err != nil {
		t.Fatal(err)
	}
	status, body := call(t, srv, "POST", "/api/v1/chats/"+c.Id+"/messages", "secret", `{"text":"and the sync?","skill":"v2-sync-progress"}`)
	if status != 200 {
		t.Fatalf("send: %d %s", status, body)
	}
	send := nextCommand(t, agent, ctx, isSend).GetSend()
	if send.Text != "and the sync?" || !strings.Contains(send.SystemPrompt, `Use the skill "v2-sync-progress" (version 2) exactly to do: and the sync?`) ||
		!strings.Contains(send.SystemPrompt, "tail -n 60") || !strings.Contains(send.SystemPrompt, c.Id) {
		t.Fatalf("send: %q / %q", send.Text, send.SystemPrompt)
	}
	// The skill is for that turn only.
	call(t, srv, "POST", "/api/v1/chats/"+c.Id+"/messages", "secret", `{"text":"thanks"}`)
	if p := nextCommand(t, agent, ctx, isSend).GetSend().SystemPrompt; strings.Contains(p, "Use the skill") {
		t.Fatalf("the next turn has no pinned skill: %q", p)
	}
}

func TestScriptSkillsAreCheckedAndFlagged(t *testing.T) {
	h, srv := newTestHubWith(t)
	approvedSkills(t, h)

	msg, isErr := mcpCall(t, srv, "read_skill", map[string]any{"name": "check-prod-import"})
	if isErr || !strings.Contains(msg, "scripts live in the project") || !strings.Contains(msg, "Never print their values") || !strings.Contains(msg, "show the user the command and its target") {
		t.Fatalf("read_skill says how to run it: %q", msg)
	}
	if msg, _ := mcpCall(t, srv, "check_skill_scripts", map[string]any{"name": "check-prod-import", "hashes": map[string]any{prodScriptPath: skills.Hash(prodScript)}}); !strings.Contains(msg, "match") {
		t.Fatalf("unchanged: %q", msg)
	}
	msg, _ = mcpCall(t, srv, "check_skill_scripts", map[string]any{"name": "check-prod-import", "hashes": map[string]any{prodScriptPath: skills.Hash(prodScript + "# edited\n")}})
	if !strings.Contains(msg, "Changed since the user approved") {
		t.Fatalf("changed: %q", msg)
	}
	_, body := request(t, "GET", srv.URL+"/api/v1/skills", nil, nil)
	if !strings.Contains(string(body), `"review":true`) || !strings.Contains(string(body), `"scripts":1`) {
		t.Fatalf("the list shows the flag: %s", body)
	}
	_, body = request(t, "GET", srv.URL+"/api/v1/skills/check-prod-import", nil, nil)
	if !strings.Contains(string(body), `"needsEnv":["DB_URL"]`) || !strings.Contains(string(body), `"changed"`) || !strings.Contains(string(body), `"runsOn":"laptop"`) {
		t.Fatalf("the detail shows the declarations: %s", body)
	}
	if msg, _ := mcpCall(t, srv, "read_skill", map[string]any{"name": "check-prod-import"}); !strings.Contains(msg, "waits for their review") {
		t.Fatalf("a flagged skill says so: %q", msg)
	}
	// The owner looks and approves again: the new script is accepted.
	if res, _ := request(t, "POST", srv.URL+"/api/v1/skills/check-prod-import/approve", nil, nil); res.StatusCode != 200 {
		t.Fatal("approve")
	}
	if _, body = request(t, "GET", srv.URL+"/api/v1/skills", nil, nil); strings.Contains(string(body), `"review":true`) {
		t.Fatalf("cleared: %s", body)
	}

	withSecret := map[string]any{"skill_md": strings.Replace(prodSkillMD, "check-prod-import", "check-prod-export", 1),
		"mutating": false, "scripts": map[string]any{prodScriptPath: prodScript + "DB_PASSWORD='hunter2hunter2'\n"}}
	if msg, isErr := mcpCall(t, srv, "propose_skill", withSecret); !isErr || !strings.Contains(msg, "secret") {
		t.Fatalf("a script with a secret is refused: %q", msg)
	}
}

func TestSaveAsSkillDraftsFromAStretchOfAChat(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	now := time.Now().UnixMilli()
	h.putSession(&v1.SessionInfo{Id: "wh", Node: "laptop", Cwd: "/srv/wh", UpdatedMs: now})
	if _, _, err := h.store.PutItems("wh", []*v1.TimelineItem{
		{ItemId: "u1", Ord: 1, Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "did the import land in prod?"}}},
		shell("t1", `psql "$DB_URL" -c 'select count(*) from imports'`),
		{ItemId: "u2", Ord: 3, Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "thanks"}}},
	}); err != nil {
		t.Fatal(err)
	}
	// shell() leaves Ord unset; place the tool call between the two asks.
	items, _, _ := h.store.ItemsAfter("wh", 0)
	for _, it := range items {
		if it.ItemId == "t1" {
			it.Ord = 2
		}
	}
	if _, _, err := h.store.PutItems("wh", items); err != nil {
		t.Fatal(err)
	}
	if res, _ := request(t, "POST", srv.URL+"/api/v1/skills/draft", strings.NewReader(`{"session":"wh","item":"nope"}`), nil); res.StatusCode != http.StatusNotFound {
		t.Fatalf("unknown item: %d", res.StatusCode)
	}
	res, body := request(t, "POST", srv.URL+"/api/v1/skills/draft", strings.NewReader(`{"session":"wh","item":"t1"}`), nil)
	if res.StatusCode != 200 {
		t.Fatalf("draft: %d %s", res.StatusCode, body)
	}
	start := nextCommand(t, agent, ctx, isStart).GetStart()
	if start.Cwd != "/srv/wh" {
		t.Fatalf("a script routine is drafted in its project: %v", start)
	}
	text := start.Prompt
	if len(start.Attachments) == 1 {
		b, err := os.ReadFile(h.blobPath(start.Attachments[0].Sha256))
		if err != nil {
			t.Fatal(err)
		}
		text = string(b)
	}
	for _, want := range []string{"did the import land in prod?", "psql", "needs_env", "never contains a password", "propose_skill"} {
		if !strings.Contains(text, want) {
			t.Errorf("the brief lacks %q:\n%s", want, text)
		}
	}
}
