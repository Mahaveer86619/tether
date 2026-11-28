package hub

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// The hub's MCP server (streamable HTTP, JSON responses) at /mcp. It lets a
// Claude session on any node see the other nodes and sessions, start work
// elsewhere and wait for it, and use the artifact store. Agents register it
// in Claude Code on their machine. See docs/plans/plan.md.

const (
	mcpProtocol   = "2025-06-18"
	mcpSource     = "Claude (Tether MCP)"
	mcpReadLimit  = 256 << 10
	mcpWaitMax    = 900
	mcpWaitPoll   = time.Second
	mcpItemsShown = 20
)

type rpcRequest struct {
	ID     json.RawMessage `json:"id"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type mcpTool struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	InputSchema map[string]any `json:"inputSchema"`
	call        func(h *Hub, caller identity, args map[string]any) (string, error)
}

func schema(required []string, props map[string]string) map[string]any {
	p := map[string]any{}
	for name, desc := range props {
		typ, d, _ := strings.Cut(desc, ":")
		p[name] = map[string]any{"type": typ, "description": strings.TrimSpace(d)}
	}
	if required == nil {
		required = []string{}
	}
	return map[string]any{"type": "object", "properties": p, "required": required}
}

// Tools that change what every user gets.
var mcpAdminOnly = map[string]bool{"update_skill": true, "save_insight": true, "budget_set": true}

var mcpTools = []mcpTool{
	{
		Name:        "list_skills",
		Description: "The skills Tether has learned from the user's repeated requests: name and when to use each. Read one with read_skill before doing a task it fits.",
		InputSchema: schema(nil, nil),
		call:        (*Hub).mcpListSkills,
	},
	{
		Name:        "read_skill",
		Description: "The text of a skill: what to run, in what order, and what to report. Follow it. If a step fails or is wrong, fix the skill with update_skill.",
		InputSchema: schema([]string{"name"}, map[string]string{"name": "string: the skill's name from list_skills"}),
		call:        (*Hub).mcpReadSkill,
	},
	{
		Name: "propose_skill",
		Description: "Save a new skill for the user to approve in the Tether app. skill_md is a whole SKILL.md: front matter with name and description, then the steps. " +
			"It is checked, and refused if it holds anything that looks like a secret.",
		InputSchema: schema([]string{"skill_md", "mutating"}, map[string]string{
			"skill_md": "string: the whole SKILL.md",
			"mutating": "boolean: true if any step changes something",
			"source":   "string: the request it was learned from",
		}),
		call: (*Hub).mcpProposeSkill,
	},
	{
		Name:        "update_skill",
		Description: "Correct an approved skill: a step failed, the output was not what it said, or the user told you. This makes a new version; the old one is kept and the user can go back to it.",
		InputSchema: schema([]string{"name", "skill_md", "note"}, map[string]string{
			"name":     "string: the skill's name",
			"skill_md": "string: the whole corrected SKILL.md, with the same name",
			"note":     "string: what was wrong, in a sentence",
		}),
		call: (*Hub).mcpUpdateSkill,
	},
	{
		Name:        "tether_guide",
		Description: "How Tether works: its parts, where it keeps its data (the tables and how to read them), what is built, and these tools. Topics: overview, data, features, tools. Read data before analysing what Tether saved.",
		InputSchema: schema(nil, map[string]string{"topic": "string: overview, data, features or tools (default overview)"}),
		call:        (*Hub).mcpGuide,
	},
	{
		Name:        "list_rules",
		Description: "The user's standing rules for how to work (for example no comments in code, keep docs current). They are already in your instructions; read them again with this when a long conversation may have lost them. Pass node and cwd for the folder you work in.",
		InputSchema: schema(nil, map[string]string{"node": "string: the machine you work on", "cwd": "string: the folder you work in"}),
		call:        (*Hub).mcpListRules,
	},
	{
		Name: "save_insight",
		Description: "Save an Insights report (an analysis of how the user works with Tether) for the user to read in the app: a summary and recommendations of rules, skills and context changes. " +
			"Use it only when your instructions ask for an Insights analysis; nothing is applied until the user taps it.",
		InputSchema: saveInsightSchema,
		call:        (*Hub).mcpSaveInsight,
	},
	{
		Name:        "list_nodes",
		Description: "The machines connected to Tether: name, OS, whether online, and which one is the hub's own machine (where hub sessions run).",
		InputSchema: schema(nil, nil),
		call:        (*Hub).mcpListNodes,
	},
	{
		Name:        "list_sessions",
		Description: "Claude Code sessions across machines, newest first: id, title, machine, state, folder.",
		InputSchema: schema(nil, map[string]string{
			"node":      "string: only this machine",
			"live_only": "boolean: only sessions with a running Claude Code process",
			"limit":     "integer: at most this many (default 20)",
		}),
		call: (*Hub).mcpListSessions,
	},
	{
		Name:        "start_session",
		Description: "Start a Claude Code session with a first prompt. Without node it runs on the hub's machine in a scratch folder. Returns the session id; use wait_for_session to get the result.",
		InputSchema: schema([]string{"prompt"}, map[string]string{
			"prompt":    "string: what the new session should do",
			"title":     "string: a short title for the task, 3 to 6 words, shown in the chat's task list instead of the prompt",
			"node":      "string: the machine to run on; omit for a hub session",
			"cwd":       "string: folder on that machine (default: its home folder)",
			"model":     "string: e.g. sonnet, opus, haiku",
			"chat":      "string: the Tether chat you are working in, if your instructions name one; the session then shows in that chat",
			"needs_gpu": "boolean: the task needs a GPU; without node, a machine with one is picked",
		}),
		call: (*Hub).mcpStartSession,
	},
	{
		Name:        "create_chat",
		Description: "Create a hub-owned chat from a shell or any MCP client. The hub picks or confirms the target, starts the main session and returns the chat id; reconnecting clients reattach to that chat.",
		InputSchema: schema([]string{"prompt"}, map[string]string{
			"prompt":          "string: the first message",
			"node":            "string: machine to run on; omit to let the hub pick",
			"cwd":             "string: folder on that machine",
			"scratch":         "boolean: run in a fresh scratch folder on the hub's machine",
			"profile":         "string: core profile id from list_profiles; default claude-main",
			"mode":            "string: main or subagent (default main)",
			"title":           "string: short title; the hub derives one when unset",
			"model":           "string: pin a model, e.g. opencode/big-pickle; omit to let core pick",
			"capability":      "string: long_context, reasoning, read, edit, test, review or vision",
			"permission_mode": "string: Claude Code permission mode",
		}),
		call: (*Hub).mcpCreateChat,
	},
	{
		Name:        "list_profiles",
		Description: "The core engine profiles a chat may use: id, kind, command, capabilities, context window and whether it is a free tier. Ranking and budgets are owned by core, not by the caller.",
		InputSchema: schema(nil, nil),
		call:        (*Hub).mcpListProfiles,
	},
	{
		Name:        "pick_model",
		Description: "Ask core which profile and model it would choose for a task. Use this in Herdr or any MCP client to preview the same auto-picker create_chat and delegate_task use; ranking, free-tier health and budgets are core-owned.",
		InputSchema: schema(nil, map[string]string{
			"mode":       "string: main or subagent (default subagent)",
			"profile":    "string: core profile id; omit for core to pick",
			"model":      "string: pin a model, e.g. big-pickle or opencode/deepseek-v4.1-flash-free",
			"capability": "string: long_context, reasoning, read, edit, test, review or vision",
		}),
		call: (*Hub).mcpPickModel,
	},
	{
		Name:        "token_status",
		Description: "The caller's shared token state: every provider and free model, rank, enabled flag, budget, used and remaining tokens, quota state, privacy notes and the last routing decision. The same state is in Welcome and GET /api/v1/token/status.",
		InputSchema: schema(nil, nil),
		call:        (*Hub).mcpTokenStatus,
	},
	{
		Name:        "budget_set",
		Description: "Admin only: change a provider or model's rank, budget, enabled flag or quota state. Set quota_state to exhausted to make core fall back to the next ranked model on every device.",
		InputSchema: schema([]string{"provider"}, map[string]string{
			"provider":      "string: provider id, e.g. opencode",
			"model":         "string: model id; empty changes every model of the provider",
			"budget_tokens": "integer: 0 means unlimited",
			"rank":          "integer: higher ranks are tried first",
			"enabled":       "boolean: allow or block routing to it",
			"quota_state":   "string: ok, near_limit, exhausted or unavailable",
		}),
		call: (*Hub).mcpBudgetSet,
	},
	{
		Name:        "delegate_task",
		Description: "Start a bounded sub-agent task inside an existing chat. Prefer a large-context free-tier profile for reading a codebase; the hub enforces device and token policy. Returns a task id and session id.",
		InputSchema: schema([]string{"chat", "prompt"}, map[string]string{
			"chat":       "string: the chat the main agent is working in",
			"prompt":     "string: one bounded task for the sub-agent",
			"node":       "string: machine to run on; omit for the hub's machine",
			"cwd":        "string: folder on that machine",
			"profile":    "string: sub-agent profile from list_profiles; core picks when unset",
			"model":      "string: pin a model from token_status, e.g. opencode/big-pickle",
			"capability": "string: long_context, read, edit, test, review or vision",
			"title":      "string: 3 to 6 words, shown instead of the prompt",
			"needs_gpu":  "boolean: the task needs a GPU",
		}),
		call: (*Hub).mcpDelegateTask,
	},
	{
		Name:        "wait_for_subagents",
		Description: "Wait until every sub-agent task in a chat has finished its turn. Returns each task's id, session, state and a short report.",
		InputSchema: schema([]string{"chat"}, map[string]string{
			"chat":            "string: the chat id",
			"timeout_seconds": "integer: give up after this long (default 300, at most 900)",
		}),
		call: (*Hub).mcpWaitForSubagents,
	},
	{
		Name:        "collect_results",
		Description: "Collect the latest result from every sub-agent task in a chat as compact text. Use full session text only for the one whose detail you need.",
		InputSchema: schema([]string{"chat"}, map[string]string{
			"chat": "string: the chat id",
			"last": "integer: recent timeline items per task (default 6)",
		}),
		call: (*Hub).mcpCollectResults,
	},
	{
		Name:        "cancel_task",
		Description: "Stop one delegated task without touching the chat's main session or its siblings.",
		InputSchema: schema([]string{"task"}, map[string]string{"task": "string: task id from delegate_task"}),
		call:        (*Hub).mcpCancelTask,
	},
	{
		Name: "set_chat_target",
		Description: "Record where a Tether chat should work: a machine and folder, or scratch for no project. " +
			"By default Tether then carries the conversation over to a new session there, which takes over the chat.",
		InputSchema: schema([]string{"chat"}, map[string]string{
			"chat":    "string: the chat id from your instructions",
			"node":    "string: the machine, as list_nodes names it",
			"cwd":     "string: the folder on that machine",
			"scratch": "boolean: no project; a fresh scratch folder on the hub's machine",
			"reason":  "string: one line on why this folder, shown to the user",
			"move":    "boolean: carry the conversation over now (default true)",
		}),
		call: (*Hub).mcpSetChatTarget,
	},
	{
		Name:        "send_message",
		Description: "Send a message to an existing session, as the user would.",
		InputSchema: schema([]string{"session", "text"}, map[string]string{
			"session": "string: session id",
			"text":    "string: the message",
		}),
		call: (*Hub).mcpSendMessage,
	},
	{
		Name:        "read_session",
		Description: "A session's state and its latest conversation as text: messages, and tool calls as one line each.",
		InputSchema: schema([]string{"session"}, map[string]string{
			"session": "string: session id",
			"last":    "integer: how many recent items (default 20)",
		}),
		call: (*Hub).mcpReadSession,
	},
	{
		Name:        "wait_for_session",
		Description: "Wait until a session finishes its current turn (or needs approval), then return its state and latest reply.",
		InputSchema: schema([]string{"session"}, map[string]string{
			"session":         "string: session id",
			"timeout_seconds": "integer: give up after this long (default 300, at most 900)",
		}),
		call: (*Hub).mcpWait,
	},
	{
		Name:        "list_artifacts",
		Description: "Files in Tether's central artifact store: screenshots, documents and attachments sessions read, wrote or were given.",
		InputSchema: schema(nil, map[string]string{
			"session": "string: only this session's files",
			"limit":   "integer: at most this many (default 50)",
		}),
		call: (*Hub).mcpListArtifacts,
	},
	{
		Name:        "read_artifact",
		Description: "Read a text artifact, 256 KB at a time from offset. For other files, returns its details, where an attached file sits in its session's folder, and a link that works for an hour.",
		InputSchema: schema([]string{"id"}, map[string]string{"id": "string: artifact id", "offset": "integer: byte to start reading from (default 0)"}),
		call:        (*Hub).mcpReadArtifact,
	},
	{
		Name:        "save_artifact",
		Description: "Save text to the central artifact store, e.g. a report or notes to keep or hand to another session.",
		InputSchema: schema([]string{"name", "content"}, map[string]string{
			"name":    "string: file name, e.g. report.md",
			"content": "string: the text",
			"session": "string: the session it belongs to",
		}),
		call: (*Hub).mcpSaveArtifact,
	},
}

func (h *Hub) serveMCP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", "POST")
		http.Error(w, "this MCP server answers POST requests only", http.StatusMethodNotAllowed)
		return
	}
	caller, err := h.auth(r, true)
	if err != nil {
		writeError(w, err)
		return
	}
	var req rpcRequest
	if err := json.NewDecoder(io.LimitReader(r.Body, maxBody)).Decode(&req); err != nil {
		writeRPC(w, nil, nil, &rpcError{-32700, "could not parse the request"})
		return
	}
	if len(req.ID) == 0 { // a notification
		w.WriteHeader(http.StatusAccepted)
		return
	}
	switch req.Method {
	case "initialize":
		var p struct {
			ProtocolVersion string `json:"protocolVersion"`
		}
		_ = json.Unmarshal(req.Params, &p)
		writeRPC(w, req.ID, map[string]any{
			"protocolVersion": firstNonEmpty(p.ProtocolVersion, mcpProtocol),
			"capabilities":    map[string]any{"tools": map[string]any{}},
			"serverInfo":      map[string]any{"name": "tether", "version": h.cfg.Version},
			"instructions": "Tether connects the user's machines and their Claude Code sessions. Use it to see and start sessions on other machines, and to read and save files in the shared artifact store. " +
				"To show the user something as a web page (a demo, a visual explanation, a report), write it under .tether/pages/<name>/ in the session's folder, with index.html as the entry and relative links to its other files; Tether hosts it and the user opens it from the app.",
		}, nil)
	case "ping":
		writeRPC(w, req.ID, map[string]any{}, nil)
	case "tools/list":
		writeRPC(w, req.ID, map[string]any{"tools": mcpTools}, nil)
	case "tools/call":
		var p struct {
			Name      string         `json:"name"`
			Arguments map[string]any `json:"arguments"`
		}
		_ = json.Unmarshal(req.Params, &p)
		for _, t := range mcpTools {
			if t.Name == p.Name {
				if mcpAdminOnly[t.Name] {
					h.mu.Lock()
					ok := h.can(caller, actAdmin, objHub, "")
					h.mu.Unlock()
					if !ok {
						writeRPC(w, req.ID, map[string]any{"content": []map[string]any{{"type": "text", "text": "only the hub's admin can use " + t.Name}}, "isError": true}, nil)
						return
					}
				}
				text, err := t.call(h, caller, p.Arguments)
				isErr := err != nil
				h.mu.Lock()
				h.audit(whoOf(caller), "mcp", t.Name, auditDetail(p.Arguments), !isErr)
				h.mu.Unlock()
				if isErr {
					text = err.Error()
				}
				writeRPC(w, req.ID, map[string]any{"content": []map[string]any{{"type": "text", "text": text}}, "isError": isErr}, nil)
				return
			}
		}
		writeRPC(w, req.ID, nil, &rpcError{-32602, "unknown tool " + p.Name})
	default:
		writeRPC(w, req.ID, nil, &rpcError{-32601, "unknown method " + req.Method})
	}
}

func writeRPC(w http.ResponseWriter, id json.RawMessage, result any, e *rpcError) {
	out := map[string]any{"jsonrpc": "2.0", "id": id}
	if e != nil {
		out["error"] = e
	} else {
		out["result"] = result
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(out)
}

func str(args map[string]any, k string) string {
	s, _ := args[k].(string)
	return strings.TrimSpace(s)
}

func num(args map[string]any, k string, def int) int {
	if f, ok := args[k].(float64); ok && f > 0 {
		return int(f)
	}
	return def
}

// optNum keeps zero and negative values, unlike num's "positive or default".
func optNum(args map[string]any, k string) *int64 {
	f, ok := args[k].(float64)
	if !ok {
		return nil
	}
	n := int64(f)
	return &n
}

func optBool(args map[string]any, k string) *bool {
	b, ok := args[k].(bool)
	if !ok {
		return nil
	}
	return &b
}

func jsonText(v any) (string, error) {
	b, err := json.MarshalIndent(v, "", "  ")
	return string(b), err
}

func opErr(e *opError) error {
	if e == nil {
		return nil
	}
	return fmt.Errorf("%s", e.Message)
}

func stateName(s v1.SessionState) string {
	return strings.ToLower(strings.TrimPrefix(s.String(), "SESSION_STATE_"))
}

func (h *Hub) mcpListNodes(caller identity, _ map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	hub := h.hubNode()
	var out []map[string]any
	for _, n := range h.nodes {
		if !h.can(caller, actView, objNode, n.Node) {
			continue
		}
		m := map[string]any{"name": n.Node, "os": n.Os, "online": n.Online, "hub": n.Node == hub, "running_sessions": n.RunningSessions,
			"claude": h.can(caller, actRunClaude, objNode, n.Node)}
		if hw := hardwareText(n); hw != "" {
			m["hardware"] = hw
		}
		out = append(out, m)
	}
	sort.Slice(out, func(i, j int) bool { return out[i]["name"].(string) < out[j]["name"].(string) })
	return jsonText(out)
}

func (h *Hub) mcpListSessions(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	node, liveOnly, limit := str(args, "node"), args["live_only"] == true, num(args, "limit", 20)
	var list []*v1.SessionInfo
	for _, s := range h.sessions {
		if (node == "" || s.Node == node) && (!liveOnly || live(s.State)) && h.can(caller, actView, objSession, s.Id) {
			list = append(list, s)
		}
	}
	sort.Slice(list, func(i, j int) bool { return list[i].UpdatedMs > list[j].UpdatedMs })
	var out []map[string]any
	for _, s := range list[:min(limit, len(list))] {
		out = append(out, map[string]any{
			"id": s.Id, "title": s.Title, "node": s.Node, "state": stateName(s.State), "cwd": s.Cwd,
			"updated": time.UnixMilli(s.UpdatedMs).Format(time.RFC3339),
		})
	}
	return jsonText(out)
}

func (h *Hub) mcpStartSession(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	cs := &v1.CreateSession{Prompt: str(args, "prompt"), Node: str(args, "node"), Cwd: str(args, "cwd"), Model: str(args, "model")}
	cs.Name = taskTitle(str(args, "title"), cs.Prompt)
	if args["needs_gpu"] == true {
		if cs.Node == "" {
			if cs.Node = h.gpuNode(); cs.Node == "" {
				return "", fmt.Errorf("no machine with a GPU is online")
			}
		} else if !nodeHasGPU(h.nodes[cs.Node]) {
			return "", fmt.Errorf("%s has no GPU Tether can see", cs.Node)
		}
	}
	cs.Scratch = cs.Node == ""
	chat := h.chats[str(args, "chat")]
	if str(args, "chat") != "" && (chat == nil || !h.can(caller, actUse, objChat, chat.Id)) {
		return "", fmt.Errorf("unknown chat %s", str(args, "chat"))
	}
	extra := startExtra{as: caller}
	if chat != nil {
		extra.systemPrompt = h.chatPromptFor(chat, cs.Node, true)
		if cs.Scratch {
			extra.systemPrompt = h.chatPromptFor(chat, h.hubNode(), true)
		}
	}
	id, err := h.startSession(cs, mcpSource, extra)
	if err != nil {
		return "", opErr(err)
	}
	if chat != nil {
		h.link(chat, id, linkStarted)
		h.putChat(chat)
	}
	return "Started session " + id + " on " + h.sessions[id].Node + ".", nil
}

func (h *Hub) mcpCreateChat(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	t := &v1.ChatTarget{Mode: targetManual, Node: str(args, "node"), Cwd: str(args, "cwd"), Scratch: args["scratch"] == true, Reason: "started from core"}
	if t.Node == "" && !t.Scratch {
		t.Mode = targetAuto
	}
	if t.Scratch {
		t.Node = h.hubNode()
	}
	c, err := h.createChat(caller, &v1.CreateChat{
		Prompt: str(args, "prompt"), Target: t, Title: str(args, "title"), Model: str(args, "model"),
		Capability: str(args, "capability"), PermissionMode: str(args, "permission_mode"),
		Profile: str(args, "profile"), Mode: firstNonEmpty(str(args, "mode"), "main"),
	}, mcpSource)
	if err != nil {
		return "", opErr(err)
	}
	return "Created chat " + c.Id + " with lead session " + c.ActiveSession + " on " + c.Target.Node + ". Clients reattach to this chat; they do not start a new lead.", nil
}

func (h *Hub) mcpListProfiles(_ identity, _ map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	return jsonText(h.profileCatalog().Profiles)
}

func (h *Hub) mcpPickModel(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	mode := firstNonEmpty(str(args, "mode"), "subagent")
	capability, profileID := str(args, "capability"), str(args, "profile")
	var p *v1.AgentProfile
	var perr *opError
	if profileID != "" {
		p, perr = h.resolveProfile(profileID, mode)
	} else {
		p = h.bestProfile(mode, capability)
		if p == nil && capability != "" {
			p = h.bestProfile(mode, "")
		}
		if p == nil {
			perr = invalid("no agent profile fits that mode and capability")
		}
	}
	if perr != nil {
		return "", opErr(perr)
	}
	choice, perr := h.routeModel(h.tokenUser(caller), p, str(args, "model"), mode, capability)
	if perr != nil {
		return "", opErr(perr)
	}
	return jsonText(map[string]any{
		"profile": choice.profile.Id, "provider": choice.provider,
		"model": choice.model, "cli_model": choice.cliModel(),
		"decision": choice.decision(), "reason": choice.reason,
	})
}

func (h *Hub) mcpTokenStatus(caller identity, _ map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	user := h.tokenUser(caller)
	return jsonText(map[string]any{
		"status": h.tokenStatusFor(user),
		"events": h.tokenEventsFor(user).Events,
	})
}

func (h *Hub) mcpBudgetSet(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	set := &v1.BudgetSet{
		Provider: str(args, "provider"), Model: str(args, "model"),
		QuotaState: str(args, "quota_state"), BudgetTokens: optNum(args, "budget_tokens"),
		Enabled: optBool(args, "enabled"),
	}
	if rank := optNum(args, "rank"); rank != nil {
		r := int32(*rank)
		set.Rank = &r
	}
	status, err := h.setBudgets(caller, set)
	if err != nil {
		return "", opErr(err)
	}
	return jsonText(status)
}

func (h *Hub) mcpDelegateTask(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	chat := h.chats[str(args, "chat")]
	if chat == nil || !h.can(caller, actUse, objChat, chat.Id) {
		return "", fmt.Errorf("unknown chat %s", str(args, "chat"))
	}
	profileID, capability := str(args, "profile"), str(args, "capability")
	if capability == "" {
		capability = "long_context"
	}
	if profileID == "" {
		if p := h.bestProfile("subagent", capability); p != nil {
			profileID = p.Id
		}
	}
	profile, perr := h.resolveProfile(profileID, "subagent")
	if perr != nil {
		return "", opErr(perr)
	}
	node := str(args, "node")
	if args["needs_gpu"] == true {
		if node == "" {
			if node = h.gpuNode(); node == "" {
				return "", fmt.Errorf("no machine with a GPU is online")
			}
		} else if !nodeHasGPU(h.nodes[node]) {
			return "", fmt.Errorf("%s has no GPU Tether can see", node)
		}
	}
	scratch := node == ""
	if scratch {
		node = h.hubNode()
	}
	if node == "" {
		return "", fmt.Errorf("no agent is online to run the task")
	}
	task := uuid.NewString()
	cs := &v1.CreateSession{
		Node: node, Cwd: str(args, "cwd"), Prompt: str(args, "prompt"), Scratch: scratch,
		Model: str(args, "model"), Capability: capability, Profile: profile.Id,
		TaskRole: "subagent", ParentTask: task, Name: taskTitle(str(args, "title"), str(args, "prompt")),
	}
	extra := startExtra{as: caller, systemPrompt: h.chatPromptFor(chat, node, true)}
	id, err := h.startSession(cs, mcpSource, extra)
	if err != nil {
		return "", opErr(err)
	}
	h.link(chat, id, linkSubagent+":"+task)
	h.putChat(chat)
	chosen := profile.Id
	if s := h.sessions[id]; s != nil {
		chosen = firstNonEmpty(s.Profile, chosen)
	}
	return jsonText(map[string]any{"task": task, "session": id, "profile": chosen, "model": cs.Model, "node": node})
}

// subagentLinks returns a chat's delegated tasks, oldest first. Caller holds
// h.mu.
func (h *Hub) subagentLinks(c *v1.Chat) []subagentLink {
	var out []subagentLink
	for _, l := range c.Sessions {
		if task, ok := strings.CutPrefix(l.Role, linkSubagent+":"); ok {
			out = append(out, subagentLink{task: task, session: l.Session})
		}
	}
	return out
}

type subagentLink struct{ task, session string }

func (h *Hub) subagentsFor(caller identity, chat string) (*v1.Chat, []subagentLink, error) {
	c := h.chats[chat]
	if c == nil || !h.can(caller, actUse, objChat, c.Id) {
		return nil, nil, fmt.Errorf("unknown chat %s", chat)
	}
	return c, h.subagentLinks(c), nil
}

func (h *Hub) mcpWaitForSubagents(caller identity, args map[string]any) (string, error) {
	deadline := time.Now().Add(time.Duration(min(num(args, "timeout_seconds", 300), mcpWaitMax)) * time.Second)
	time.Sleep(2 * mcpWaitPoll)
	for {
		h.mu.Lock()
		_, tasks, err := h.subagentsFor(caller, str(args, "chat"))
		if err != nil {
			h.mu.Unlock()
			return "", err
		}
		pending := 0
		for _, t := range tasks {
			if s := h.sessions[t.session]; s == nil || busy(s.State) {
				pending++
			}
		}
		done := pending == 0 || time.Now().After(deadline)
		if done {
			out, textErr := h.subagentStatus(tasks, 6)
			h.mu.Unlock()
			if textErr != nil {
				return "", textErr
			}
			if pending > 0 {
				return "Some sub-agents are still working.\n\n" + out, nil
			}
			return out, nil
		}
		h.mu.Unlock()
		time.Sleep(mcpWaitPoll)
	}
}

func (h *Hub) mcpCollectResults(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	_, tasks, err := h.subagentsFor(caller, str(args, "chat"))
	if err != nil {
		return "", err
	}
	return h.subagentStatus(tasks, num(args, "last", 6))
}

// subagentStatus summarises each task; the full transcript stays in its
// session for the main agent to read when a short report is not enough.
// Caller holds h.mu.
func (h *Hub) subagentStatus(tasks []subagentLink, last int) (string, error) {
	if len(tasks) == 0 {
		return "No sub-agent tasks in this chat.", nil
	}
	var b strings.Builder
	for _, t := range tasks {
		s := h.sessions[t.session]
		fmt.Fprintf(&b, "Task %s, session %s", t.task, t.session)
		if s != nil {
			fmt.Fprintf(&b, ", %s on %s (%s)", stateName(s.State), s.Node, firstNonEmpty(s.Profile, "claude-main"))
		} else {
			b.WriteString(", session is gone")
		}
		b.WriteString("\n")
		if s != nil {
			text, err := h.sessionText(s.Id, last)
			if err != nil {
				return "", err
			}
			b.WriteString(clip(text, 6_000))
			b.WriteString("\n\n")
		}
	}
	return b.String(), nil
}

func (h *Hub) mcpCancelTask(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	task := str(args, "task")
	for _, c := range h.chats {
		if !h.can(caller, actUse, objChat, c.Id) {
			continue
		}
		for _, t := range h.subagentLinks(c) {
			if t.task != task {
				continue
			}
			if _, err := h.interrupt(t.session); err != nil {
				return "", opErr(err)
			}
			if _, err := h.stop(t.session); err != nil {
				return "", opErr(err)
			}
			return "Stopped task " + task + " and its session " + t.session + ".", nil
		}
	}
	return "", fmt.Errorf("unknown task %s", task)
}

func (h *Hub) mcpSetChatTarget(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	move, ok := args["move"].(bool)
	if !ok {
		move = true
	}
	scratch, _ := args["scratch"].(bool)
	t := &v1.ChatTarget{Mode: targetClaude, Node: str(args, "node"), Cwd: str(args, "cwd"), Scratch: scratch,
		Reason: firstNonEmpty(str(args, "reason"), "picked by Claude")}
	if scratch {
		t.Node, t.Cwd = h.hubNode(), ""
	}
	if !h.can(caller, actManage, objChat, str(args, "chat")) {
		return "", fmt.Errorf("unknown chat %s", str(args, "chat"))
	}
	if !h.can(caller, actRunClaude, objNode, t.Node) {
		return "", fmt.Errorf("%s is not shared with you; list_nodes shows the machines you can use", t.Node)
	}
	if !scratch && h.agents[t.Node] == nil {
		return "", fmt.Errorf("%s is not online; list_nodes shows the machines that are", t.Node)
	}
	c, err := h.setChatTarget(str(args, "chat"), &v1.SetChatTarget{Target: t, Move: move && !scratch}, mcpSource)
	if err != nil {
		return "", opErr(err)
	}
	if move && !scratch {
		return "Done: the chat continues in session " + c.ActiveSession + " on " + t.Node + " in " + t.Cwd + ". Stop here; that session takes over.", nil
	}
	return "Recorded. Carry on here.", nil
}

func (h *Hub) mcpSendMessage(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.can(caller, actUse, objSession, str(args, "session")) {
		return "", fmt.Errorf("unknown session %s", str(args, "session"))
	}
	if _, err := h.sendMessage(&v1.SendMessage{Session: str(args, "session"), Text: str(args, "text")}, mcpSource); err != nil {
		return "", opErr(err)
	}
	return "Sent.", nil
}

func (h *Hub) mcpReadSession(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.can(caller, actView, objSession, str(args, "session")) {
		return "", fmt.Errorf("unknown session %s", str(args, "session"))
	}
	return h.sessionText(str(args, "session"), num(args, "last", mcpItemsShown))
}

// sessionText is a session's state and last items as plain text. Caller
// holds h.mu.
func (h *Hub) sessionText(id string, last int) (string, error) {
	s := h.sessions[id]
	if s == nil {
		return "", fmt.Errorf("unknown session %s", id)
	}
	items, _, err := h.store.ItemsAfter(id, 0)
	if err != nil {
		return "", err
	}
	sort.Slice(items, func(i, j int) bool { return items[i].Ord < items[j].Ord })
	var b strings.Builder
	fmt.Fprintf(&b, "Session %s on %s, %s. Title: %s\n\n", s.Id, s.Node, stateName(s.State), s.Title)
	for _, it := range items[max(0, len(items)-last):] {
		if t := itemText(it); t != "" {
			b.WriteString(t + "\n\n")
		}
	}
	return b.String(), nil
}

func itemText(it *v1.TimelineItem) string {
	switch k := it.Kind.(type) {
	case *v1.TimelineItem_User:
		return "User: " + k.User.Text
	case *v1.TimelineItem_Markdown:
		return "Claude: " + blocksText(k.Markdown.Blocks)
	case *v1.TimelineItem_Tool:
		return fmt.Sprintf("[%s] %s (%s)", k.Tool.Name, k.Tool.Title, strings.ToLower(strings.TrimPrefix(k.Tool.Status.String(), "STATUS_")))
	case *v1.TimelineItem_Notice:
		return "Note: " + k.Notice.Text
	case *v1.TimelineItem_TaskReport:
		return taskReportText(k.TaskReport)
	}
	return ""
}

// taskReportText is a task's report as plain text: who it was, and what it said.
func taskReportText(r *v1.TaskReport) string {
	head := "Task finished"
	if r.Failed {
		head = "Task failed"
	}
	where := strings.Trim(r.Node+", "+r.Folder, ", ")
	text := head + ": " + r.Title + " (" + where + ")"
	if r.Detail != "" {
		text += "\n" + r.Detail
	}
	if said := blocksText(r.Blocks); said != "" {
		text += "\n\n" + said
	}
	if r.Clipped {
		text += "\n\n[cut short; read the task's own session for the rest]"
	}
	return text
}

func blocksText(blocks []*v1.Block) string {
	var parts []string
	for _, bl := range blocks {
		switch k := bl.Kind.(type) {
		case *v1.Block_Heading:
			parts = append(parts, spansText(k.Heading.Spans))
		case *v1.Block_Paragraph:
			parts = append(parts, spansText(k.Paragraph.Spans))
		case *v1.Block_Code:
			parts = append(parts, "```"+k.Code.Lang+"\n"+k.Code.Text+"\n```")
		case *v1.Block_List:
			for _, li := range k.List.Items {
				parts = append(parts, "- "+blocksText(li.Blocks))
			}
		case *v1.Block_Quote:
			parts = append(parts, "> "+blocksText(k.Quote.Blocks))
		case *v1.Block_Table:
			var row []string
			for _, c := range k.Table.Header {
				row = append(row, spansText(c.Spans))
			}
			parts = append(parts, strings.Join(row, " | "))
			for _, r := range k.Table.Rows {
				row = row[:0]
				for _, c := range r.Cells {
					row = append(row, spansText(c.Spans))
				}
				parts = append(parts, strings.Join(row, " | "))
			}
		}
	}
	return strings.Join(parts, "\n")
}

func spansText(spans []*v1.Span) string {
	var b strings.Builder
	for _, s := range spans {
		b.WriteString(s.Text)
	}
	return b.String()
}

func (h *Hub) mcpWait(caller identity, args map[string]any) (string, error) {
	id := str(args, "session")
	deadline := time.Now().Add(time.Duration(min(num(args, "timeout_seconds", 300), mcpWaitMax)) * time.Second)
	// Give a just-started session a moment to report that it is working.
	time.Sleep(2 * mcpWaitPoll)
	for {
		h.mu.Lock()
		s := h.sessions[id]
		if s == nil || !h.can(caller, actView, objSession, id) {
			h.mu.Unlock()
			return "", fmt.Errorf("unknown session %s", id)
		}
		if s.State != v1.SessionState_SESSION_STATE_RUNNING || time.Now().After(deadline) {
			text, err := h.sessionText(id, 6)
			h.mu.Unlock()
			if s.State == v1.SessionState_SESSION_STATE_RUNNING {
				text = "Still working when the wait ran out.\n\n" + text
			}
			return text, err
		}
		h.mu.Unlock()
		time.Sleep(mcpWaitPoll)
	}
}

func (h *Hub) mcpListArtifacts(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	list, err := h.store.Artifacts(str(args, "session"), num(args, "limit", 50))
	if err != nil {
		return "", err
	}
	var out []map[string]any
	for _, a := range list {
		if !h.canArtifact(caller, actView, a) {
			continue
		}
		out = append(out, map[string]any{
			"id": a.Id, "name": a.Name, "mime": a.Mime, "size": a.Size, "session": a.Session, "node": a.Node, "origin": a.Origin,
			"sha256": a.Sha256, "note": a.Note, "created": time.UnixMilli(a.CreatedMs).Format(time.RFC3339),
		})
	}
	return jsonText(out)
}

func (h *Hub) mcpReadArtifact(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	a, err := h.store.Artifact(str(args, "id"))
	if err != nil || a == nil || !h.canArtifact(caller, actView, a) {
		return "", fmt.Errorf("unknown artifact %s", str(args, "id"))
	}
	text := strings.HasPrefix(a.Mime, "text/") || strings.Contains(a.Mime, "json") || strings.HasSuffix(a.Name, ".md")
	offset := int64(num(args, "offset", 0))
	if !text || offset < 0 || offset >= max(a.Size, 1) {
		link, lerr := h.artifactLink(a.Id, time.Hour)
		if lerr != nil {
			return "", opErr(lerr)
		}
		where := ""
		if a.Origin == "attachment" && a.Session != "" {
			where = fmt.Sprintf(" It was attached to session %s, whose folder has it as .tether/attachments/%s.", a.Session, a.Name)
		}
		return fmt.Sprintf("%s (%s, %d bytes, sha256 %s) isn't text Tether can show here.%s It also downloads from the hub at %s for an hour.",
			a.Name, a.Mime, a.Size, a.Sha256, where, link.Url), nil
	}
	f, err := os.Open(h.blobPath(a.Sha256))
	if err != nil {
		return "", err
	}
	defer f.Close()
	b := make([]byte, min(mcpReadLimit, a.Size-offset))
	n, err := f.ReadAt(b, offset)
	if err != nil && n < len(b) {
		return "", err
	}
	if end := offset + int64(n); offset > 0 || end < a.Size {
		return fmt.Sprintf("[bytes %d-%d of %d; pass offset %d for more]\n%s", offset, end, a.Size, end, b[:n]), nil
	}
	return string(b[:n]), nil
}

func (h *Hub) mcpSaveArtifact(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	name, content := str(args, "name"), str(args, "content")
	if name == "" {
		return "", fmt.Errorf("name is required")
	}
	if s := str(args, "session"); s != "" && !h.can(caller, actUse, objSession, s) {
		return "", fmt.Errorf("unknown session %s", s)
	}
	sha, n, err := h.putBlob(strings.NewReader(content), "")
	if err != nil {
		return "", opErr(err)
	}
	a := &v1.Artifact{Sha256: sha, Name: name, Mime: mimeOf("", name), Size: n, Session: str(args, "session"), Origin: "upload", Owner: caller.userID()}
	if err := h.addArtifact(a); err != nil {
		return "", opErr(err)
	}
	return "Saved as artifact " + a.Id + ".", nil
}
