package hub

import (
	"net/http"
	"sort"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Agent profiles are owned by core. They tell an agent which installed CLI to
// launch and give the token router the metadata it needs to rank that CLI for
// a task. Clients only name a profile; they never supply a command.

const (
	mainProfileID         = "claude-main"
	opencodeMainProfileID = "opencode-main"
	antigravityProfileID  = "antigravity-worker"
	opencodeProfileID     = "opencode-worker"
	profilesKey           = "core.profiles"
)

var defaultProfiles = []*v1.AgentProfile{
	{
		Id: mainProfileID, Kind: "main", Command: "claude", StatusProtocol: "claude_stream",
		Capabilities: []string{"reasoning", "edit", "test", "review"}, BudgetPolicy: "main", Provider: "claude-code",
		ContextWindow: 200_000, UserRank: 100, Description: "Claude Code, the reasoning brain for a chat",
	},
	{
		Id: opencodeMainProfileID, Kind: "main", Command: "opencode", Args: []string{"run"}, StatusProtocol: "line",
		Capabilities: []string{"reasoning", "long_context", "read", "edit", "test", "review", "vision"},
		BudgetPolicy: "free", Provider: opencodeProvider, ContextWindow: 1_000_000,
		FreeTier: true, UserRank: 60, Description: "OpenCode CLI as a lead agent; core picks a free model such as Big Pickle",
	},
	{
		Id: antigravityProfileID, Kind: "subagent", Command: "agy", StatusProtocol: "line",
		Capabilities: []string{"long_context", "read", "edit", "review"}, BudgetPolicy: "free", Provider: "antigravity",
		ContextWindow: 1_000_000, FreeTier: true, UserRank: 80, Description: "Antigravity CLI, for large reads and bounded work",
	},
	{
		Id: opencodeProfileID, Kind: "subagent", Command: "opencode", Args: []string{"run"}, StatusProtocol: "line",
		Capabilities: []string{"long_context", "read", "edit", "test"}, BudgetPolicy: "free", Provider: "opencode",
		ContextWindow: 1_000_000, FreeTier: true, UserRank: 90, Description: "OpenCode CLI, for large reads and bounded work; free models are picked by core",
	},
}

func (h *Hub) loadProfiles() error {
	h.profiles = map[string]*v1.AgentProfile{}
	for _, p := range defaultProfiles {
		h.profiles[p.Id] = proto.Clone(p).(*v1.AgentProfile)
	}
	b, err := h.store.Get(profilesKey)
	if err != nil || b == nil {
		return err
	}
	list := &v1.AgentProfileList{}
	if err := proto.Unmarshal(b, list); err != nil {
		return err
	}
	for _, p := range list.Profiles {
		if p.Id == "" || p.Command == "" {
			continue
		}
		if p.StatusProtocol == "" {
			p.StatusProtocol = "line"
		}
		if p.Kind == "" {
			p.Kind = "subagent"
		}
		h.profiles[p.Id] = p
	}
	return nil
}

// profileCatalog is a stable list for REST and MCP. Caller holds h.mu.
func (h *Hub) profileCatalog() *v1.AgentProfileList {
	out := &v1.AgentProfileList{}
	for _, p := range h.profiles {
		out.Profiles = append(out.Profiles, proto.Clone(p).(*v1.AgentProfile))
	}
	sort.Slice(out.Profiles, func(i, j int) bool { return out.Profiles[i].Id < out.Profiles[j].Id })
	return out
}

// resolveProfile picks the named profile, or the default for the chat mode,
// and checks that its kind fits the work being created. Caller holds h.mu.
func (h *Hub) resolveProfile(id, mode string) (*v1.AgentProfile, *opError) {
	if mode == "" {
		mode = "main"
	}
	if mode != "main" && mode != "subagent" {
		return nil, invalid("mode must be main or subagent")
	}
	if id == "" {
		id = mainProfileID
	}
	p := h.profiles[id]
	if p == nil {
		return nil, &opError{"unknown_profile", "unknown agent profile " + id, http.StatusBadRequest}
	}
	if p.Kind != mode {
		return nil, &opError{"profile_kind", "profile " + id + " is for " + p.Kind + " work", http.StatusBadRequest}
	}
	if p.Command == "" {
		return nil, &opError{"profile_command", "profile " + id + " has no command", http.StatusBadRequest}
	}
	return proto.Clone(p).(*v1.AgentProfile), nil
}

// bestProfile picks the highest-ranked profile for a role and optional
// capability. Token headroom is applied by the router before it is used.
// Caller holds h.mu.
func (h *Hub) bestProfile(kind, capability string) *v1.AgentProfile {
	var best *v1.AgentProfile
	for _, p := range h.profiles {
		if p.Kind != kind {
			continue
		}
		if capability != "" {
			found := false
			for _, c := range p.Capabilities {
				if c == capability {
					found = true
					break
				}
			}
			if !found {
				continue
			}
		}
		if best == nil || p.UserRank > best.UserRank {
			best = p
		}
	}
	if best == nil && kind == "subagent" && capability != "" {
		return h.bestProfile(kind, "")
	}
	return best
}

// setProfiles replaces the catalog the hub offers to clients and agents.
// Caller holds h.mu.
func (h *Hub) setProfiles(list *v1.AgentProfileList) *opError {
	next := map[string]*v1.AgentProfile{}
	main := false
	for _, p := range list.Profiles {
		if p.Id == "" || p.Command == "" {
			return invalid("a profile needs an id and a command")
		}
		if p.Kind != "main" && p.Kind != "subagent" {
			return invalid("profile " + p.Id + " has an unknown kind")
		}
		if p.StatusProtocol == "" {
			p.StatusProtocol = "line"
		}
		if next[p.Id] != nil {
			return invalid("duplicate profile " + p.Id)
		}
		if p.Kind == "main" {
			main = true
		}
		next[p.Id] = proto.Clone(p).(*v1.AgentProfile)
	}
	if !main {
		return invalid("at least one main profile is required")
	}
	b, err := proto.Marshal(list)
	if err != nil {
		return internalError(err)
	}
	if err := h.store.Put(profilesKey, b); err != nil {
		return internalError(err)
	}
	h.profiles = next
	return nil
}
