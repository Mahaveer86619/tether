package hub

import (
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Core owns provider ranking and budgets so every device and user gets the
// same routing decision. Usage events only adjust the counters; clients never
// choose a raw CLI command or a secret.

const (
	tokenStatusKey = "core.token.statuses"
	tokenEventsKey = "core.token.events"
	maxTokenEvents = 500

	quotaOK          = "ok"
	quotaNearLimit   = "near_limit"
	quotaExhausted   = "exhausted"
	quotaUnavailable = "unavailable"

	mainProvider        = "claude-code"
	antigravityProvider = "antigravity"
	opencodeProvider    = "opencode"
)

type tokenRouter struct {
	statuses map[string]*v1.TokenStatus
	events   []*v1.UsageEvent
	seen     map[string]bool
}

type modelChoice struct {
	profile  *v1.AgentProfile
	provider string
	model    string
	reason   string
}

func (c *modelChoice) cliModel() string {
	if c.provider == opencodeProvider && c.model != "" && !strings.HasPrefix(c.model, opencodeProvider+"/") {
		return opencodeProvider + "/" + c.model
	}
	// These are budget catalogue names, not flags those CLIs accept.
	if c.provider == antigravityProvider && c.model == "default" ||
		c.provider == mainProvider && c.model == "subscription" {
		return ""
	}
	return c.model
}

func (c *modelChoice) decision() string {
	if c.model == "" {
		return c.profile.Id + " → " + c.provider + " CLI default"
	}
	return c.profile.Id + " → " + c.provider + "/" + c.model
}

func makeBudget(provider, model, fallback string, rank int32, free bool, tokens int64, contextWindow int32, notes string, capabilities ...string) *v1.ProviderBudget {
	return &v1.ProviderBudget{
		Provider: provider, Model: model, Rank: rank, Enabled: true, FreeTier: free,
		BudgetTokens: tokens, QuotaState: quotaOK, FallbackProvider: fallback,
		ContextWindow: contextWindow, Capabilities: capabilities, Notes: notes,
	}
}

func defaultProviderBudgets() []*v1.ProviderBudget {
	openCaps := []string{"long_context", "read", "edit", "test"}
	return []*v1.ProviderBudget{
		makeBudget(mainProvider, "subscription", "", 100, false, 0, 200_000,
			"Claude Code subscription; the CLI picks the Claude model", "reasoning", "edit", "test", "review"),
		makeBudget(antigravityProvider, "default", "", 80, true, 0, 1_000_000,
			"Antigravity CLI subscription; core does not meter its tokens", "long_context", "read", "edit", "review"),
		makeBudget(opencodeProvider, "big-pickle", "deepseek-v4.1-flash-free", 95, true, 2_000_000, 1_000_000,
			"Free for a limited time; prompts may be used to improve the model", append(openCaps, "review")...),
		makeBudget(opencodeProvider, "deepseek-v4.1-flash-free", "hy4-flash-free", 90, true, 2_000_000, 1_000_000,
			"Free for a limited time; zero retention", openCaps...),
		makeBudget(opencodeProvider, "hy4-flash-free", "mimo-v2.6-flash-free", 88, true, 2_000_000, 1_000_000,
			"Free for a limited time; zero retention", openCaps...),
		makeBudget(opencodeProvider, "mimo-v2.6-flash-free", "jev-1.13-free", 86, true, 2_000_000, 1_000_000,
			"Free for a limited time; no training exception listed", openCaps...),
		makeBudget(opencodeProvider, "jev-1.13-free", "beam-free", 84, true, 2_000_000, 1_000_000,
			"Free for a limited time; no training exception listed", openCaps...),
		makeBudget(opencodeProvider, "beam-free", "big-pickle", 82, true, 2_000_000, 1_000_000,
			"Free for a limited time; kept 30 days for safety", openCaps...),
		makeBudget(opencodeProvider, "flint-40b-free", "big-pickle", 80, true, 2_000_000, 1_000_000,
			"Free for a limited time; may be used to improve the model", openCaps...),
		makeBudget(opencodeProvider, "tidepool-alpha-free", "big-pickle", 75, true, 2_000_000, 1_000_000,
			"Free for a limited time; retained and used to improve the model", openCaps...),
		makeBudget(opencodeProvider, "seaglass-alpha-free", "big-pickle", 74, true, 2_000_000, 1_000_000,
			"Free for a limited time; retained and used to improve the model", openCaps...),
		makeBudget(opencodeProvider, "iceman-free", "big-pickle", 73, true, 2_000_000, 1_000_000,
			"Free for a limited time; retained and used to improve the model", openCaps...),
		makeBudget(opencodeProvider, "nemotron-3.5-lightning-free", "big-pickle", 70, true, 2_000_000, 1_000_000,
			"Free trial; do not send personal code, NVIDIA logs use", openCaps...),
		makeBudget(opencodeProvider, "nemotron-3.5-super-vl-free", "big-pickle", 68, true, 2_000_000, 1_000_000,
			"Free trial with vision; do not send personal code, NVIDIA logs use", append(openCaps, "vision")...),
	}
}

func (h *Hub) loadTokenRouter() error {
	h.token = &tokenRouter{statuses: map[string]*v1.TokenStatus{}, seen: map[string]bool{}}
	if b, err := h.store.Get(tokenStatusKey); err != nil {
		return err
	} else if b != nil {
		list := &v1.TokenStatusList{}
		if err := proto.Unmarshal(b, list); err != nil {
			return err
		}
		for _, s := range list.Statuses {
			for _, budget := range s.Providers {
				refreshBudget(budget)
			}
			h.token.statuses[s.User] = s
		}
	}
	for _, u := range h.users {
		h.ensureTokenStatus(u.Id)
	}
	h.ensureTokenStatus(h.ownerID)
	if b, err := h.store.Get(tokenEventsKey); err != nil {
		return err
	} else if b != nil {
		list := &v1.UsageEventList{}
		if err := proto.Unmarshal(b, list); err != nil {
			return err
		}
		for _, e := range list.Events {
			if e.Id == "" || h.token.seen[e.Id] {
				continue
			}
			h.token.seen[e.Id] = true
			h.token.events = append(h.token.events, e)
		}
	}
	return nil
}

func (h *Hub) saveTokenRouter() {
	list := &v1.TokenStatusList{}
	for _, s := range h.token.statuses {
		list.Statuses = append(list.Statuses, s)
	}
	sort.Slice(list.Statuses, func(i, j int) bool { return list.Statuses[i].User < list.Statuses[j].User })
	b, err := proto.Marshal(list)
	if err == nil {
		err = h.store.Put(tokenStatusKey, b)
	}
	if err == nil {
		events := &v1.UsageEventList{Events: h.token.events}
		b, err = proto.Marshal(events)
		if err == nil {
			err = h.store.Put(tokenEventsKey, b)
		}
	}
	if err != nil {
		h.log.Error("save token router", "err", err)
	}
}

func (h *Hub) tokenUser(id identity) string {
	if u := id.userID(); u != "" {
		return u
	}
	if h.ownerID != "" {
		return h.ownerID
	}
	return "owner"
}

func (h *Hub) ensureTokenStatus(user string) *v1.TokenStatus {
	if user == "" {
		user = "owner"
	}
	if s := h.token.statuses[user]; s != nil {
		return s
	}
	s := &v1.TokenStatus{User: user, UpdatedMs: time.Now().UnixMilli()}
	for _, b := range defaultProviderBudgets() {
		next := proto.Clone(b).(*v1.ProviderBudget)
		refreshBudget(next)
		s.Providers = append(s.Providers, next)
	}
	h.token.statuses[user] = s
	h.saveTokenRouter()
	return s
}

func (h *Hub) tokenStatusFor(user string) *v1.TokenStatus {
	return proto.Clone(h.ensureTokenStatus(user)).(*v1.TokenStatus)
}

func refreshBudget(b *v1.ProviderBudget) {
	if b.BudgetTokens <= 0 {
		b.RemainingTokens = 0
		return
	}
	remaining := b.BudgetTokens - b.UsedTokens
	if remaining < 0 {
		remaining = 0
	}
	b.RemainingTokens = remaining
	switch {
	case remaining == 0:
		b.QuotaState = quotaExhausted
	case remaining <= b.BudgetTokens/10:
		if b.QuotaState == quotaOK || b.QuotaState == "" {
			b.QuotaState = quotaNearLimit
		}
	case b.QuotaState == quotaNearLimit:
		b.QuotaState = quotaOK
	}
	// Exhausted and unavailable are set by policy, not inferred from counters:
	// an admin has to clear them with quota_state=ok after restocking.
}

func eligibleBudget(b *v1.ProviderBudget, capability string) bool {
	if b == nil || !b.Enabled || b.QuotaState == quotaExhausted || b.QuotaState == quotaUnavailable {
		return false
	}
	if b.BudgetTokens > 0 && b.RemainingTokens <= 0 {
		return false
	}
	return capability == "" || hasCapability(b.Capabilities, capability)
}

func hasCapability(caps []string, capability string) bool {
	for _, c := range caps {
		if c == capability {
			return true
		}
	}
	return false
}

func providerForProfile(p *v1.AgentProfile) string {
	if p.Provider != "" {
		return p.Provider
	}
	switch p.Command {
	case "claude":
		return mainProvider
	case "agy":
		return antigravityProvider
	case "opencode":
		return opencodeProvider
	}
	return ""
}

func findBudget(s *v1.TokenStatus, provider, model string) *v1.ProviderBudget {
	for _, b := range s.Providers {
		if b.Provider == provider && b.Model == model {
			return b
		}
	}
	return nil
}

func bestBudget(s *v1.TokenStatus, provider, capability string, except map[string]bool) *v1.ProviderBudget {
	var best *v1.ProviderBudget
	for _, b := range s.Providers {
		if b.Provider != provider || except[b.Model] || !eligibleBudget(b, capability) {
			continue
		}
		if best == nil || b.Rank > best.Rank {
			best = b
		}
	}
	return best
}

// routeModel returns both the profile and the model, so an exhausted provider
// can fall through to a different CLI without the client knowing the catalog.
// Caller holds h.mu.
func (h *Hub) routeModel(user string, p *v1.AgentProfile, requested, role, capability string) (*modelChoice, *opError) {
	return h.routeModelTrying(user, p, requested, role, capability, map[string]bool{})
}

func (h *Hub) routeModelTrying(user string, p *v1.AgentProfile, requested, role, capability string, tried map[string]bool) (*modelChoice, *opError) {
	if p == nil {
		return nil, invalid("no agent profile to route")
	}
	tried[p.Id] = true
	provider := providerForProfile(p)
	if capability == "" {
		capability = "reasoning"
		if role == "subagent" {
			capability = "long_context"
		}
	}
	status := h.ensureTokenStatus(user)
	choice := &modelChoice{profile: p, provider: provider}

	if requested != "" {
		model := requested
		if strings.HasPrefix(model, opencodeProvider+"/") {
			model = strings.TrimPrefix(model, opencodeProvider+"/")
			if provider != opencodeProvider {
				return nil, invalid("model " + requested + " needs an OpenCode profile")
			}
		}
		choice.model = model
		choice.reason = "explicitly requested"
		if provider == opencodeProvider {
			if b := findBudget(status, provider, model); b != nil {
				if !eligibleBudget(b, "") {
					fallback := bestBudget(status, provider, "", map[string]bool{model: true})
					if fallback == nil {
						return h.fallbackProfile(status, p, role, capability, tried, "requested model "+model+" is "+b.QuotaState)
					}
					choice.model = fallback.Model
					choice.reason = "requested model " + model + " is " + b.QuotaState + "; fell back to " + fallback.Model
				} else {
					choice.reason = "explicitly requested " + model + " (rank " + strconv.Itoa(int(b.Rank)) + ")"
				}
			} else {
				return nil, &opError{"unknown_model", "model " + model + " is not in core's catalog; see token_status", http.StatusBadRequest}
			}
		}
		h.noteDecision(status, choice)
		return choice, nil
	}

	switch provider {
	case mainProvider:
		choice.reason = "main work stays with Claude Code"
	case antigravityProvider:
		if b := findBudget(status, provider, "default"); eligibleBudget(b, "") {
			choice.model = b.Model
			choice.reason = "Antigravity CLI runs its own model"
		} else {
			return h.fallbackProfile(status, p, role, capability, tried, "Antigravity is unavailable")
		}
	default:
		b := bestBudget(status, provider, capability, nil)
		if b == nil {
			b = bestBudget(status, provider, "", nil)
		}
		if b == nil {
			return h.fallbackProfile(status, p, role, capability, tried, "every "+provider+" model is disabled or out of budget")
		}
		choice.model = b.Model
		choice.reason = "best ranked " + provider + " model for " + capability + " (rank " + strconv.Itoa(int(b.Rank)) + ", " + b.QuotaState + ")"
	}
	if choice.reason == "" {
		choice.reason = "core default"
	}
	h.noteDecision(status, choice)
	return choice, nil
}

func (h *Hub) fallbackProfile(status *v1.TokenStatus, p *v1.AgentProfile, role, capability string, tried map[string]bool, why string) (*modelChoice, *opError) {
	if role != "subagent" {
		return nil, &opError{"quota_exhausted", "no model is available: " + why, http.StatusServiceUnavailable}
	}
	var next *v1.AgentProfile
	for _, candidate := range h.profiles {
		if candidate.Kind != "subagent" || tried[candidate.Id] || candidate.Id == p.Id {
			continue
		}
		if !hasCapability(candidate.Capabilities, capability) && capability != "" {
			continue
		}
		if next == nil || candidate.UserRank > next.UserRank {
			next = candidate
		}
	}
	if next == nil && capability != "" {
		return h.fallbackProfile(status, p, role, "", tried, why)
	}
	if next == nil {
		return nil, &opError{"quota_exhausted", "no sub-agent model is available: " + why, http.StatusServiceUnavailable}
	}
	return h.routeModelTrying(status.User, next, "", role, capability, tried)
}

func (h *Hub) noteDecision(status *v1.TokenStatus, c *modelChoice) {
	status.LastDecision = c.decision()
	status.LastReason = c.reason
	status.UpdatedMs = time.Now().UnixMilli()
	h.saveTokenRouter()
}

func (h *Hub) setBudgets(id identity, set *v1.BudgetSet) (*v1.TokenStatus, *opError) {
	if !h.can(id, actAdmin, objHub, "") {
		return nil, errForbidden
	}
	if set.Provider == "" {
		return nil, invalid("provider is required")
	}
	if set.QuotaState != "" && set.QuotaState != quotaOK && set.QuotaState != quotaNearLimit &&
		set.QuotaState != quotaExhausted && set.QuotaState != quotaUnavailable {
		return nil, invalid("quota_state must be ok, near_limit, exhausted or unavailable")
	}
	matched := false
	for _, status := range h.token.statuses {
		for _, b := range status.Providers {
			if b.Provider != set.Provider || (set.Model != "" && b.Model != set.Model) {
				continue
			}
			matched = true
			if set.BudgetTokens != nil {
				b.BudgetTokens = *set.BudgetTokens
				if b.BudgetTokens < 0 {
					b.BudgetTokens = 0
				}
			}
			if set.Rank != nil {
				b.Rank = *set.Rank
			}
			if set.Enabled != nil {
				b.Enabled = *set.Enabled
			}
			if set.QuotaState != "" {
				b.QuotaState = set.QuotaState
			}
			refreshBudget(b)
		}
		status.UpdatedMs = time.Now().UnixMilli()
	}
	if !matched {
		return nil, invalid("no model matches that provider and model")
	}
	h.saveTokenRouter()
	h.broadcastTokenStatus()
	return h.tokenStatusFor(h.tokenUser(id)), nil
}

func (h *Hub) tokenEventsFor(user string) *v1.UsageEventList {
	out := &v1.UsageEventList{}
	for _, e := range h.token.events {
		if e.User == user {
			out.Events = append(out.Events, proto.Clone(e).(*v1.UsageEvent))
		}
	}
	sort.Slice(out.Events, func(i, j int) bool { return out.Events[i].AtMs > out.Events[j].AtMs })
	return out
}

// recordUsageEvent applies a model call to the user's budget and keeps the
// event for the audit trail. Duplicate reports from replays are ignored.
// Caller holds h.mu.
func (h *Hub) recordUsageEvent(session, model, id string, input, output, cacheWrite, cacheRead int64, cost float64, at int64) {
	s := h.sessions[session]
	if s == nil || input+output+cacheWrite+cacheRead <= 0 {
		return
	}
	if id == "" {
		id = session + "-" + strconv.FormatInt(at, 10) + "-" + strconv.FormatInt(input+output, 10)
	}
	if h.token.seen[id] {
		return
	}
	user := h.sessionOwner(s)
	status := h.ensureTokenStatus(user)
	provider, budgetModel := modelFromSession(s, h.profiles[s.Profile])
	if model != "" {
		budgetModel = model
		if provider == opencodeProvider {
			budgetModel = strings.TrimPrefix(budgetModel, opencodeProvider+"/")
		}
	}
	e := &v1.UsageEvent{
		Id: id, User: user, Chat: h.chatOf[session], Session: session, TaskRole: s.TaskRole,
		Provider: provider, Model: budgetModel, InputTokens: input, OutputTokens: output,
		CacheWriteTokens: cacheWrite, CacheReadTokens: cacheRead, CostUsd: cost, AtMs: at,
	}
	if b := findBudget(status, provider, budgetModel); b != nil {
		before := b.QuotaState
		b.UsedTokens += input + output + cacheWrite
		refreshBudget(b)
		e.QuotaState = b.QuotaState
		if before != b.QuotaState {
			h.broadcastTokenStatus()
		}
	}
	status.UpdatedMs = time.Now().UnixMilli()
	h.token.seen[id] = true
	h.token.events = append(h.token.events, e)
	if len(h.token.events) > maxTokenEvents {
		drop := len(h.token.events) - maxTokenEvents
		for _, old := range h.token.events[:drop] {
			delete(h.token.seen, old.Id)
		}
		h.token.events = append([]*v1.UsageEvent{}, h.token.events[drop:]...)
	}
	h.saveTokenRouter()
}

func modelFromSession(s *v1.SessionInfo, p *v1.AgentProfile) (string, string) {
	model := s.Model
	if strings.HasPrefix(model, opencodeProvider+"/") {
		return opencodeProvider, strings.TrimPrefix(model, opencodeProvider+"/")
	}
	provider := ""
	if p != nil {
		provider = p.Provider
	}
	if provider == "" {
		provider = providerForProfile(p)
	}
	return provider, model
}
