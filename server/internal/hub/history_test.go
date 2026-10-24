package hub

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

const (
	sessA = "aaaaaaaa-0000-4000-8000-000000000001"
	sessB = "bbbbbbbb-0000-4000-8000-000000000002"
)

func jsonl(lines ...string) []byte { return []byte(strings.Join(lines, "\n") + "\n") }

func userLine(uuid, ts, text string) string {
	b, _ := json.Marshal(map[string]any{"type": "user", "uuid": uuid, "timestamp": ts, "cwd": "/src/tether", "message": map[string]any{"role": "user", "content": text}})
	return string(b)
}

func assistantLine(uuid, ts, text string) string {
	b, _ := json.Marshal(map[string]any{"type": "assistant", "uuid": uuid, "timestamp": ts, "message": map[string]any{"model": "claude-opus-5-5",
		"content": []map[string]any{{"type": "text", "text": text}, {"type": "tool_use", "name": "Bash", "input": map[string]any{"command": "go test ./..."}}}}})
	return string(b)
}

func TestLinesBecomeEvents(t *testing.T) {
	cases := []struct {
		line, kind, text, tool string
	}{
		{userLine("u1", "2026-10-24T10:00:00Z", "fix the login test"), "user", "fix the login test", ""},
		{`{"type":"user","uuid":"u2","message":{"content":"<pasted_content id=\"c1\">\nfrom the app\n</pasted_content id=\"c1\">"}}`, "user", "from the app", ""},
		{`{"type":"user","isMeta":true,"message":{"content":"caveat"}}`, "", "", ""},
		{`{"type":"user","uuid":"u3","message":{"content":[{"type":"tool_result","content":"ok\tgithub.com/x"}]}}`, "tool_result", "ok\tgithub.com/x", ""},
		{assistantLine("a1", "2026-10-24T10:00:05Z", "Done: a race."), "assistant", "Done: a race.", "Bash"},
		{`{"type":"assistant","uuid":"a2","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/src/a.go"}}]}}`, "tool_use", "Read: /src/a.go", "Read"},
		{`{"type":"summary","summary":"Login test fix"}`, "summary", "Login test fix", ""},
		{`{"type":"attachment","uuid":"q1","attachment":{"type":"queued_command","prompt":"also lint"}}`, "user", "also lint", ""},
		{`{"type":"file-history-snapshot","messageId":"x"}`, "", "", ""},
		{`not json`, "", "", ""},
	}
	for _, c := range cases {
		e := lineEvent([]byte(c.line))
		if c.kind == "" {
			if e != nil {
				t.Errorf("%s: want no event, got %v", c.line, e)
			}
			continue
		}
		if e == nil || e.Kind != c.kind || e.Text != c.text || e.Tool != c.tool {
			t.Errorf("%s:\n got %v\nwant %s %q %s", c.line, e, c.kind, c.text, c.tool)
		}
	}
	if e := lineEvent([]byte(assistantLine("a1", "2026-10-24T10:00:05Z", "x"))); e.Model != "claude-opus-5-5" || e.TsMs == 0 {
		t.Errorf("model and time: %v", e)
	}
}

func TestSecretsAreRedactedAndLinesStayJSON(t *testing.T) {
	line := userLine("u1", "2026-10-24T10:00:00Z", "use key sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAA and password=hunter2hunter2 and\n-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----")
	got, changed := redactBytes([]byte(line))
	if !changed || strings.Contains(string(got), "sk-ant-api03") || strings.Contains(string(got), "hunter2") || strings.Contains(string(got), "abc\\n") {
		t.Fatalf("not redacted: %s", got)
	}
	var v map[string]any
	if err := json.Unmarshal(got, &v); err != nil {
		t.Fatalf("redaction broke the JSON: %v\n%s", err, got)
	}
	if !strings.Contains(string(got), "password=[REDACTED:secret]") {
		t.Fatalf("the label should stay: %s", got)
	}
	if s, c := redactString("nothing secret here, just sha 3f786850e387550fdab836ed7e6dc881de23001b"); c || !strings.HasSuffix(s, "1b") {
		t.Fatalf("false positive: %s", s)
	}
}

func TestChunksAreTakenInOnceAndResumeByOffset(t *testing.T) {
	h, srv := newTestHubWith(t)
	h.cfg.HistoryRedact = true
	first := jsonl(userLine("u1", "2026-10-24T10:00:00Z", "fix the login test"), assistantLine("a1", "2026-10-24T10:00:05Z", "On it."))
	second := jsonl(userLine("u2", "2026-10-24T10:01:00Z", "token=abcdefghijklmnop please"))
	h.mu.Lock()
	h.putSession(&v1.SessionInfo{Id: sessA, Node: "laptop", Title: "Login"})
	if got := h.ingestChunk("laptop", &v1.HistoryChunk{Session: sessA, Offset: 0, Data: first}); got != int64(len(first)) {
		t.Fatalf("offset %d", got)
	}
	// The same chunk again changes nothing; a gap is refused.
	if got := h.ingestChunk("laptop", &v1.HistoryChunk{Session: sessA, Offset: 0, Data: first}); got != int64(len(first)) {
		t.Fatalf("repeat offset %d", got)
	}
	if got := h.ingestChunk("laptop", &v1.HistoryChunk{Session: sessA, Offset: 9999, Data: second}); got != int64(len(first)) {
		t.Fatalf("a gap moved the position to %d", got)
	}
	// Overlapping: the part already there is skipped.
	both := append(append([]byte{}, first...), second...)
	end := h.ingestChunk("laptop", &v1.HistoryChunk{Session: sessA, Offset: 0, Data: both})
	// A line too big to send is skipped by its length.
	end = h.ingestChunk("laptop", &v1.HistoryChunk{Session: sessA, Offset: end, Skip: 40_000_000})
	pos := h.historyPositions("laptop")
	h.mu.Unlock()
	if end != int64(len(both))+40_000_000 || len(pos) != 1 || pos[0].Offset != end || pos[0].HeadLen != int64(len(both)) {
		t.Fatalf("end %d positions %v", end, pos)
	}

	_, body := call(t, srv, "GET", "/api/v1/history/sessions/"+sessA, "secret", "")
	page := &v1.HistoryPage{}
	if err := protojson.Unmarshal([]byte(body), page); err != nil {
		t.Fatal(err)
	}
	if len(page.Events) != 3 || page.Events[0].Text != "fix the login test" || page.Events[2].Text != "token=[REDACTED:secret] please" || !page.Events[2].Redacted {
		t.Fatalf("events: %s", body)
	}
	raw, _ := os.ReadFile(filepath.Join(h.historyDir(), sessA, "transcript.jsonl"))
	if strings.Count(string(raw), "\n") != 3 || strings.Contains(string(raw), "abcdefghijklmnop") {
		t.Fatalf("raw copy:\n%s", raw)
	}

	// A rewritten file starts over.
	h.mu.Lock()
	h.ingestChunk("laptop", &v1.HistoryChunk{Session: sessA, Offset: 0, Data: second, Reset_: true})
	h.mu.Unlock()
	_, body = call(t, srv, "GET", "/api/v1/history/sessions/"+sessA, "secret", "")
	page = &v1.HistoryPage{}
	_ = protojson.Unmarshal([]byte(body), page)
	if len(page.Events) != 1 {
		t.Fatalf("after a reset: %s", body)
	}
	_, body = call(t, srv, "GET", "/api/v1/history/changes?since=0", "secret", "")
	changes := &v1.HistoryChanges{}
	_ = protojson.Unmarshal([]byte(body), changes)
	if len(changes.Events) != 1 || len(changes.Resets) != 1 || changes.Resets[0].Session != sessA || changes.Cursor == 0 {
		t.Fatalf("changes: %s", body)
	}
	_, body = call(t, srv, "GET", "/api/v1/history/changes?since="+jsonNumber(changes.Cursor), "secret", "")
	if strings.Contains(body, `"events"`) {
		t.Fatalf("nothing new should follow the cursor: %s", body)
	}
}

func jsonNumber(n uint64) string { b, _ := json.Marshal(n); return string(b) }

func TestAChatsHistoryMergesItsSessionsAndPages(t *testing.T) {
	h, srv := newTestHubWith(t)
	h.mu.Lock()
	h.putSession(&v1.SessionInfo{Id: sessA, Node: "laptop"})
	h.putSession(&v1.SessionInfo{Id: sessB, Node: "minipc"})
	h.ingestChunk("laptop", &v1.HistoryChunk{Session: sessA, Data: jsonl(
		userLine("u1", "2026-10-24T10:00:00Z", "one"), userLine("u3", "2026-10-24T10:02:00Z", "three about deploys"))})
	h.ingestChunk("minipc", &v1.HistoryChunk{Session: sessB, Data: jsonl(
		userLine("u2", "2026-10-24T10:01:00Z", "two"), userLine("u4", "2026-10-24T10:03:00Z", "four"))})
	c := &v1.Chat{Id: "chat1", Title: "Both"}
	h.chats[c.Id] = c
	h.link(c, sessA, linkMain)
	h.link(c, sessB, linkStarted)
	h.mu.Unlock()

	_, body := call(t, srv, "GET", "/api/v1/chats/chat1/history?limit=2", "secret", "")
	page := &v1.HistoryPage{}
	_ = protojson.Unmarshal([]byte(body), page)
	if len(page.Events) != 2 || page.Events[0].Text != "three about deploys" || page.Events[1].Text != "four" || page.Events[1].Node != "minipc" || !page.MoreBefore {
		t.Fatalf("newest page: %s", body)
	}
	_, body = call(t, srv, "GET", "/api/v1/chats/chat1/history?limit=2&before="+page.Before, "secret", "")
	older := &v1.HistoryPage{}
	_ = protojson.Unmarshal([]byte(body), older)
	if len(older.Events) != 2 || older.Events[0].Text != "one" || older.Events[1].Text != "two" || older.MoreBefore {
		t.Fatalf("older page: %s", body)
	}

	_, body = call(t, srv, "GET", "/api/v1/history/search?q=deploys", "secret", "")
	hits := &v1.HistorySearch{}
	_ = protojson.Unmarshal([]byte(body), hits)
	if len(hits.Hits) != 1 || hits.Hits[0].Chat != "chat1" || !strings.Contains(hits.Hits[0].Snippet, "[deploys]") {
		t.Fatalf("search: %s", body)
	}
	if status, _ := call(t, srv, "GET", "/api/v1/history/search?q=%22OR%20x", "secret", ""); status != 200 {
		t.Fatalf("odd input should be searched as words, got %d", status)
	}

	_, md := call(t, srv, "GET", "/api/v1/history/export?chat=chat1&format=md", "secret", "")
	if !strings.HasPrefix(md, "# Both") || strings.Count(md, "*Session ") != 4 || strings.Index(md, "one") > strings.Index(md, "two") {
		t.Fatalf("markdown export:\n%s", md)
	}
	_, all := call(t, srv, "GET", "/api/v1/history/export?format=jsonl", "secret", "")
	if strings.Count(all, "\n") != 4 || !strings.Contains(all, `"session":"`+sessB+`"`) {
		t.Fatalf("bulk export:\n%s", all)
	}
	_, raw := call(t, srv, "GET", "/api/v1/history/export?session="+sessA+"&format=raw", "secret", "")
	if strings.Count(raw, "\n") != 2 {
		t.Fatalf("raw export:\n%s", raw)
	}
	_, body = call(t, srv, "GET", "/api/v1/history/status", "secret", "")
	if !strings.Contains(body, `"laptop"`) || !strings.Contains(body, `"minipc"`) {
		t.Fatalf("status: %s", body)
	}
}

func TestBackupsAreImportedIntoHistoryOnce(t *testing.T) {
	h, _ := newTestHubWith(t)
	data := jsonl(userLine("u1", "2026-10-24T10:00:00Z", "from a backup"))
	h.mu.Lock()
	h.putSession(&v1.SessionInfo{Id: sessA, Node: "laptop"})
	sha, n, err := h.putBlob(strings.NewReader(string(data)), "")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := h.keepBackup(&v1.Artifact{Sha256: sha, Name: "transcript.jsonl", Size: n, Session: sessA, Origin: originBackup, Path: backupTranscript}); err != nil {
		t.Fatal(err)
	}
	h.mu.Unlock()
	h.importBackups(t.Context())
	h.mu.Lock()
	pos := h.historyPositions("laptop")
	h.mu.Unlock()
	if len(pos) != 1 || pos[0].Offset != int64(len(data)) {
		t.Fatalf("positions after import: %v", pos)
	}
	// Done once: a second run imports nothing more.
	h.mu.Lock()
	_ = h.store.DeleteHistory(sessA)
	h.mu.Unlock()
	h.importBackups(t.Context())
	h.mu.Lock()
	defer h.mu.Unlock()
	if len(h.historyPositions("laptop")) != 0 {
		t.Fatal("backups imported twice")
	}
}

func TestHistoryRetentionDropsOldSessions(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()
	h.ingestChunk("laptop", &v1.HistoryChunk{Session: sessA, Data: jsonl(userLine("u1", "2026-10-24T10:00:00Z", "old"))})
	h.ingestChunk("laptop", &v1.HistoryChunk{Session: sessB, Data: jsonl(userLine("u2", "2026-10-24T10:00:00Z", "new"))})
	h.cfg.HistoryMaxMB = 1
	h.applyHistoryRetention(timeNow())
	if len(h.historyPositions("laptop")) != 2 {
		t.Fatal("under the size limit nothing goes")
	}
	h.cfg.HistoryMaxMB, h.cfg.HistoryKeepDays = 0, 1
	h.applyHistoryRetention(timeNow().AddDate(0, 0, 2))
	if len(h.historyPositions("laptop")) != 0 {
		t.Fatal("history older than the retention should go")
	}
	if _, err := os.Stat(filepath.Join(h.historyDir(), sessA)); !os.IsNotExist(err) {
		t.Fatal("its copy should go too")
	}
}

func timeNow() time.Time { return time.Now() }
