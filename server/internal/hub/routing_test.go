package hub

import (
	"testing"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func budgetFor(t *testing.T, h *Hub, user, provider, model string) *v1.ProviderBudget {
	t.Helper()
	for _, b := range h.tokenStatusFor(user).Providers {
		if b.Provider == provider && b.Model == model {
			return b
		}
	}
	t.Fatalf("no budget for %s/%s", provider, model)
	return nil
}

func TestAutoPickerPrefersBigPickleForSubagents(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()

	p := h.bestProfile("subagent", "long_context")
	if p == nil || p.Id != opencodeProfileID {
		t.Fatalf("subagent profile: %v", p)
	}
	choice, err := h.routeModel(h.ownerID, p, "", "subagent", "long_context")
	if err != nil {
		t.Fatal(err)
	}
	if choice.profile.Id != opencodeProfileID || choice.model != "big-pickle" {
		t.Fatalf("auto pick: %s/%s", choice.profile.Id, choice.model)
	}
	if got := choice.cliModel(); got != "opencode/big-pickle" {
		t.Fatalf("cli model: %q", got)
	}
	if status := h.ensureTokenStatus(h.ownerID); status.LastDecision == "" || status.LastReason == "" {
		t.Fatal("routing decision was not shared in token status")
	}
}

func TestExplicitModelOverridesAutoPicker(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()

	p := h.bestProfile("subagent", "long_context")
	choice, err := h.routeModel(h.ownerID, p, "opencode/deepseek-v4.1-flash-free", "subagent", "long_context")
	if err != nil {
		t.Fatal(err)
	}
	if choice.model != "deepseek-v4.1-flash-free" {
		t.Fatalf("pinned model: %q", choice.model)
	}
	if _, err := h.routeModel(h.ownerID, p, "opencode/not-in-catalog", "subagent", ""); err == nil {
		t.Fatal("an unknown OpenCode model should be refused")
	}
}

func TestDisabledModelFallsBackToNextRanked(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()

	disabled := false
	if _, err := h.setBudgets(rootID, &v1.BudgetSet{Provider: opencodeProvider, Model: "big-pickle", Enabled: &disabled}); err != nil {
		t.Fatal(err)
	}
	p := h.profiles[opencodeProfileID]
	choice, err := h.routeModel(h.ownerID, p, "", "subagent", "long_context")
	if err != nil {
		t.Fatal(err)
	}
	if choice.model == "big-pickle" || choice.profile.Id != opencodeProfileID {
		t.Fatalf("disabled model was chosen: %s/%s", choice.profile.Id, choice.model)
	}
}

func TestBigPickleCanBeExplicitMainProfile(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()

	p, err := h.resolveProfile(opencodeMainProfileID, "main")
	if err != nil {
		t.Fatal(err)
	}
	choice, err := h.routeModel(h.ownerID, p, "opencode/big-pickle", "main", "reasoning")
	if err != nil {
		t.Fatal(err)
	}
	if choice.profile.Id != opencodeMainProfileID || choice.model != "big-pickle" {
		t.Fatalf("explicit main: %s/%s", choice.profile.Id, choice.model)
	}
}

func TestExhaustedModelsFallBackToAnotherProfile(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()

	exhausted := quotaExhausted
	if _, err := h.setBudgets(rootID, &v1.BudgetSet{Provider: opencodeProvider, QuotaState: exhausted}); err != nil {
		t.Fatal(err)
	}
	p := h.profiles[opencodeProfileID]
	choice, err := h.routeModel(h.ownerID, p, "", "subagent", "long_context")
	if err != nil {
		t.Fatal(err)
	}
	if choice.profile.Id != antigravityProfileID || choice.cliModel() != "" {
		t.Fatalf("fallback: %s/%q", choice.profile.Id, choice.cliModel())
	}
	if got := budgetFor(t, h, h.ownerID, opencodeProvider, "big-pickle").QuotaState; got != quotaExhausted {
		t.Fatalf("quota state did not stick: %q", got)
	}
}

func TestUsageEventUpdatesSharedBudget(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()

	session := &v1.SessionInfo{Id: "s-token", Profile: opencodeProfileID, Model: "opencode/big-pickle", State: v1.SessionState_SESSION_STATE_IDLE}
	h.putSession(session)
	h.recordUsageEvent(session.Id, session.Model, "usage-1", 100, 20, 5, 0, 0.01, 1234)

	got := budgetFor(t, h, h.ownerID, opencodeProvider, "big-pickle")
	if got.UsedTokens != 125 || got.RemainingTokens != got.BudgetTokens-125 {
		t.Fatalf("budget after usage: %v", got)
	}
	events := h.tokenEventsFor(h.ownerID).Events
	if len(events) != 1 || events[0].Provider != opencodeProvider || events[0].Model != "big-pickle" {
		t.Fatalf("usage events: %v", events)
	}
}

func TestTokenStatusIsVisibleInStateAndREST(t *testing.T) {
	_, srv := newTestHubWith(t)
	status, body := call(t, srv, "GET", "/api/v1/token/status", "secret", "")
	if status != 200 {
		t.Fatalf("token status: %d %s", status, body)
	}
	got := &v1.TokenStatus{}
	if err := protojson.Unmarshal([]byte(body), got); err != nil || len(got.Providers) == 0 {
		t.Fatalf("token status body: %s", body)
	}

	status, body = call(t, srv, "GET", "/api/v1/state", "secret", "")
	if status != 200 {
		t.Fatalf("state: %d %s", status, body)
	}
	welcome := &v1.Welcome{}
	if err := protojson.Unmarshal([]byte(body), welcome); err != nil {
		t.Fatal(err)
	}
	if welcome.TokenStatus == nil || len(welcome.TokenStatus.Providers) == 0 || len(welcome.Profiles.GetProfiles()) == 0 {
		t.Fatal("Welcome should carry core profiles and token status for Herdr")
	}

	status, body = call(t, srv, "PUT", "/api/v1/token/budgets", "", `{"provider":"opencode"}`)
	if status != 401 {
		t.Fatalf("budget changes need admin: %d %s", status, body)
	}
}
