package hub

import (
	"strings"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestTheResetTimeIsReadFromWhatClaudeSays(t *testing.T) {
	ist, _ := time.LoadLocation("Asia/Kolkata")
	now := time.Date(2026, 11, 26, 10, 0, 0, 0, ist)
	cases := []struct {
		text string
		want time.Time
		ok   bool
	}{
		{"You've hit your limit · resets 3pm (Asia/Kolkata)", time.Date(2026, 11, 26, 15, 0, 0, 0, ist), true},
		{"5-hour limit reached ∙ resets 9am", time.Date(2026, 11, 27, 9, 0, 0, 0, now.Location()), true},
		{"Current week usage limit reached · resets Nov 30, 7:29pm (Asia/Kolkata)", time.Date(2026, 11, 30, 19, 29, 0, 0, ist), true},
		{"Claude AI usage limit reached|1796000000", time.Unix(1796000000, 0), true},
		{"All done. The sync resets at 3pm each day.", time.Time{}, false},
		{"I hit the end of the file", time.Time{}, false},
	}
	for _, c := range cases {
		got, ok := parseLimitReset(c.text, now)
		if ok != c.ok || ok && !got.Equal(c.want) {
			t.Errorf("%q: got %v %v, want %v %v", c.text, got, ok, c.want, c.ok)
		}
	}
}

func TestATaskThatHitTheLimitWaitsAndCarriesOnWhenItResets(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"lead","target":{"node":"laptop","cwd":"/src/tether"}}`)
	nextCommand(t, agent, ctx, isStart)
	if _, err := h.mcpStartSession(map[string]any{"prompt": "do the sync check", "title": "Sync check", "node": "laptop", "cwd": "/src/tether", "chat": c.Id}); err != nil {
		t.Fatal(err)
	}
	task := nextCommand(t, agent, ctx, isStart).GetStart().Session

	reset := time.Now().Add(-time.Minute).Add(-limitResetSlack)
	h.mu.Lock()
	s := h.sessions[task]
	s.State, s.Error = v1.SessionState_SESSION_STATE_ERROR, "You've hit your limit · resets "+reset.Format("3:04pm")
	h.putSession(s)
	h.commit(task, []*v1.TimelineItem{{ItemId: "m1", TsMs: 1, Kind: &v1.TimelineItem_Markdown{Markdown: &v1.Markdown{}}}})
	h.reportTask(h.chats[c.Id], task)
	waits := h.limitWaits()
	it, _ := h.store.Item(h.chats[c.Id].ActiveSession, "task:"+task+":m1")
	h.mu.Unlock()
	if len(waits) != 1 || waits[0].Session != task {
		t.Fatalf("waits %+v", waits)
	}
	rep := it.GetTaskReport()
	if rep == nil || !rep.Waiting || rep.Failed || rep.ResumeMs == 0 || !strings.Contains(rep.Detail, "carries on by itself") {
		t.Fatalf("the card should say it is waiting: %+v", rep)
	}

	h.mu.Lock()
	h.limitWaits()
	waits[0].ResumeMs = time.Now().Add(-time.Second).UnixMilli()
	h.saveLimitWaits(waits)
	h.resumeLimitWaits(time.Now())
	left := h.limitWaits()
	after, _ := h.store.Item(h.chats[c.Id].ActiveSession, "task:"+task+":m1")
	h.mu.Unlock()
	send := nextCommand(t, agent, ctx, isSend).GetSend()
	if send.Session != task || !strings.Contains(send.Text, "usage limit has reset") {
		t.Fatalf("send %+v", send)
	}
	if len(left) != 0 || after.GetTaskReport().GetWaiting() {
		t.Fatalf("after: waits %+v card %+v", left, after.GetTaskReport())
	}
}
