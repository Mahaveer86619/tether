package hub

import (
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestPlanLimitsAreKeptWhenTheyChangeAndLimitHitsAreRecorded(t *testing.T) {
	h, _ := newTestHubWith(t)
	read := func(session, week int32, at int64) *v1.PlanUsage {
		return &v1.PlanUsage{CheckedMs: at, Limits: []*v1.PlanLimit{
			{Label: "Current session", Percent: session, Resets: "3:20am"},
			{Label: "Current week (all models)", Percent: week, Resets: "Oct 18, 7:29pm"},
		}}
	}
	h.mu.Lock()
	h.setPlan("laptop", read(10, 4, 1000))
	h.setPlan("laptop", read(10, 4, 2000))
	h.setPlan("laptop", read(35, 5, 3000))
	h.setPlan("laptop", &v1.PlanUsage{Error: "claude not logged in", CheckedMs: 4000})
	now := time.Now()
	h.recordLimitHit("laptop", "s1", now.Add(2*time.Hour), now)
	h.recordLimitHit("laptop", "s2", now.Add(3*24*time.Hour), now)
	h.mu.Unlock()

	samples, err := h.store.LimitSamplesSince(0)
	if err != nil {
		t.Fatal(err)
	}
	if len(samples) != 4 {
		t.Fatalf("an unchanged reading and a failed one add nothing: %+v", samples)
	}
	if s := samples[2]; s.Span != "session5h" || s.Percent != 35 || s.AtMs != 3000 || s.Account != "laptop" {
		t.Fatalf("session sample: %+v", s)
	}
	if s := samples[3]; s.Span != "week" || s.Percent != 5 || s.Resets != "Oct 18, 7:29pm" {
		t.Fatalf("week sample: %+v", s)
	}
	events, _ := h.store.LimitEventsSince(0)
	if len(events) != 2 || events[0].Span != "session5h" || events[1].Span != "week" || events[1].Session != "s2" {
		t.Fatalf("limit hits: %+v", events)
	}
}
