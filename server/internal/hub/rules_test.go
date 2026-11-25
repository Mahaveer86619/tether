package hub

import (
	"strings"
	"testing"
)

func TestRulesAreKeptAndCoverOnlyTheSessionsTheyShould(t *testing.T) {
	h, srv := newTestHubWith(t)
	add := func(body string) string {
		t.Helper()
		code, out := call(t, srv, "POST", "/api/v1/rules", "secret", body)
		if code != 200 {
			t.Fatalf("add: %d %s", code, out)
		}
		return out
	}
	add(`{"text":"Never write comments in code.","on":true}`)
	add(`{"text":"Keep docs/ current.","scope":"project","node":"laptop","cwd":"/src/tether","on":true}`)
	add(`{"text":"Use tabs.","scope":"device","node":"minipc","on":true}`)
	add(`{"text":"Switched off.","on":false}`)

	h.mu.Lock()
	defer h.mu.Unlock()
	list := h.rulesList()
	if len(list) != 4 || list[0].Name != "Never write comments in code." {
		t.Fatalf("saved: %+v", list)
	}
	p := h.rulesPrompt("laptop", "/src/tether")
	if !strings.Contains(p, "Never write comments") || !strings.Contains(p, "Keep docs/ current") || strings.Contains(p, "tabs") || strings.Contains(p, "Switched off") {
		t.Fatalf("laptop in the project: %q", p)
	}
	if strings.Index(p, "Never write") > strings.Index(p, "Keep docs") {
		t.Fatalf("the general rule should come before the specific one: %q", p)
	}
	p = h.rulesPrompt("laptop", "/src/other")
	if !strings.Contains(p, "Never write comments") || strings.Contains(p, "Keep docs") {
		t.Fatalf("another folder: %q", p)
	}
	if p := h.rulesPrompt("minipc", "/x"); !strings.Contains(p, "Use tabs") {
		t.Fatalf("a rule for the device: %q", p)
	}
}

func TestARuleCanBeChangedAndRemovedAndBadOnesAreRefused(t *testing.T) {
	_, srv := newTestHubWith(t)
	_, out := call(t, srv, "POST", "/api/v1/rules", "secret", `{"text":"One.","on":true}`)
	id := between(out, `"id":"`, `"`)
	if code, _ := call(t, srv, "PUT", "/api/v1/rules/"+id, "secret", `{"text":"Two.","on":false}`); code != 200 {
		t.Fatalf("change: %d", code)
	}
	if _, list := call(t, srv, "GET", "/api/v1/rules", "secret", ""); !strings.Contains(list, "Two.") || strings.Contains(list, "One.") {
		t.Fatalf("list: %s", list)
	}
	for _, bad := range []string{`{"text":""}`, `{"text":"x","scope":"device"}`, `{"text":"x","scope":"project","node":"laptop"}`, `{"text":"x","scope":"nope"}`} {
		if code, _ := call(t, srv, "POST", "/api/v1/rules", "secret", bad); code != 400 {
			t.Fatalf("%s should be refused: %d", bad, code)
		}
	}
	if code, _ := call(t, srv, "DELETE", "/api/v1/rules/"+id, "secret", ""); code != 200 {
		t.Fatal("delete")
	}
	if code, _ := call(t, srv, "DELETE", "/api/v1/rules/"+id, "secret", ""); code != 404 {
		t.Fatal("deleting twice")
	}
}

func TestAChatsSessionsGetTheRulesInTheirPrompt(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	call(t, srv, "POST", "/api/v1/rules", "secret", `{"text":"Keep docs/ current.","on":true}`)
	postChat(t, srv, "/api/v1/chats", `{"prompt":"do it","target":{"node":"laptop","cwd":"/src/tether"}}`)
	start := nextCommand(t, agent, ctx, isStart).GetStart()
	if !strings.Contains(start.SystemPrompt, "Standing rules") || !strings.Contains(start.SystemPrompt, "Keep docs/ current.") {
		t.Fatalf("prompt: %q", start.SystemPrompt)
	}
}

func TestTheGuideIsServedAndExplainsWhereDataLives(t *testing.T) {
	h := &Hub{}
	for _, topic := range guideTopics() {
		if out, err := h.mcpGuide(map[string]any{"topic": topic}); err != nil || len(out) < 200 {
			t.Fatalf("%s: %v (%d bytes)", topic, err, len(out))
		}
	}
	out, _ := h.mcpGuide(map[string]any{"topic": "data"})
	for _, table := range []string{"chat_messages", "items", "usage", "audit", "kv"} {
		if !strings.Contains(out, "`"+table+"`") {
			t.Fatalf("the data guide does not name %s", table)
		}
	}
	if _, err := h.mcpGuide(map[string]any{"topic": "nope"}); err == nil || !strings.Contains(err.Error(), "overview") {
		t.Fatalf("an unknown topic should list the topics: %v", err)
	}
}

func between(s, a, b string) string {
	i := strings.Index(s, a)
	if i < 0 {
		return ""
	}
	s = s[i+len(a):]
	return s[:strings.Index(s, b)]
}
