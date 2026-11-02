package agent

import "testing"

// Captured from Claude Code 2.1.296's `claude -p /usage` on a Team plan.
const usageOutput = `You are currently using your subscription to power your Claude Code usage

Current session: 3% used · resets Oct 12, 3:19am (Asia/Kolkata)
Current week (all models): 9% used · resets Oct 18, 7:29pm (Asia/Kolkata)

What's contributing to your limits usage?
Last 24h · 1191 requests · 5 sessions
  93% of your usage was at >150k context`

func TestParsePlanLimits(t *testing.T) {
	got := parsePlan(usageOutput)
	if len(got) != 2 {
		t.Fatalf("limits: %v", got)
	}
	if got[0].Label != "session" || got[0].Percent != 3 || got[0].Resets != "Oct 12, 3:19am (Asia/Kolkata)" {
		t.Errorf("session: %v", got[0])
	}
	if got[1].Label != "week (all models)" || got[1].Percent != 9 {
		t.Errorf("week: %v", got[1])
	}
	if parsePlan("Total cost: $0.0000") != nil {
		t.Error("API-key output has no plan limits")
	}
}
