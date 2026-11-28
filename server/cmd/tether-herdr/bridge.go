package main

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

const bridgeVersion = "dev"

var (
	chatCreated = regexp.MustCompile(`Created chat (\S+) with lead session (\S+) on (.+)\.`)
	taskLine    = regexp.MustCompile(`Task (\S+), session (\S+)`)
)

type sessionMapping struct {
	chat     string
	task     string
	profile  string
	model    string
	node     string
	terminal string
}

type bridge struct {
	hub         *hubClient
	herdr       *herdrAdapter
	opts        options
	watchRunner runner

	mu         sync.Mutex
	mappings   map[string]sessionMapping
	lastStates map[string]string
	lastTokens string
	knownTools []json.RawMessage
}

func newBridge(hub *hubClient, herdr *herdrAdapter, o options) *bridge {
	return &bridge{
		hub:         hub,
		herdr:       herdr,
		opts:        o,
		watchRunner: &execRunner{bin: o.hcBin},
		mappings:    make(map[string]sessionMapping),
		lastStates:  make(map[string]string),
	}
}

func (b *bridge) serve(in io.Reader, out io.Writer) error {
	dec := json.NewDecoder(in)
	enc := json.NewEncoder(out)
	for {
		var req rpcRequest
		if err := dec.Decode(&req); err != nil {
			if errors.Is(err, io.EOF) {
				return nil
			}
			return err
		}
		if len(req.ID) == 0 {
			continue
		}
		resp := b.handle(context.Background(), req)
		if err := enc.Encode(resp); err != nil {
			return err
		}
	}
}

func (b *bridge) handle(ctx context.Context, req rpcRequest) rpcResponse {
	switch req.Method {
	case "initialize":
		var p struct {
			ProtocolVersion string `json:"protocolVersion"`
		}
		_ = json.Unmarshal(req.Params, &p)
		return rpcResponse{
			JSONRPC: "2.0",
			ID:      req.ID,
			Result: mustJSON(map[string]any{
				"protocolVersion": firstNonEmpty(p.ProtocolVersion, "2025-06-18"),
				"capabilities":    map[string]any{"tools": map[string]any{}},
				"serverInfo":      map[string]any{"name": "tether-herdr", "version": bridgeVersion},
				"instructions":    "Tether owns chats, sessions, agents and token budgets. Use these tools to start work and read shared state; this bridge mirrors results into the Herdr pane.",
			}),
		}
	case "ping":
		return rpcResponse{JSONRPC: "2.0", ID: req.ID, Result: mustJSON(map[string]any{})}
	case "tools/list":
		resp, err := b.hub.rpc(ctx, req)
		if err != nil {
			return rpcErrorResponse(req.ID, err)
		}
		var list struct {
			Tools []json.RawMessage `json:"tools"`
		}
		if json.Unmarshal(resp.Result, &list) == nil && len(list.Tools) > 0 {
			b.mu.Lock()
			b.knownTools = list.Tools
			b.mu.Unlock()
		}
		resp.ID = req.ID
		return resp
	case "tools/call":
		var p struct {
			Name      string         `json:"name"`
			Arguments map[string]any `json:"arguments"`
		}
		_ = json.Unmarshal(req.Params, &p)
		resp, err := b.hub.rpc(ctx, req)
		if err != nil {
			return rpcErrorResponse(req.ID, err)
		}
		b.observe(ctx, p.Name, p.Arguments, resp.Result)
		resp.ID = req.ID
		return resp
	default:
		return rpcResponse{JSONRPC: "2.0", ID: req.ID, Error: &rpcError{Code: -32601, Message: "unknown method " + req.Method}}
	}
}

func (b *bridge) observe(ctx context.Context, tool string, args map[string]any, result json.RawMessage) {
	text := resultText(result)
	if text == "" {
		return
	}
	switch tool {
	case "create_chat":
		m := chatCreated.FindStringSubmatch(text)
		if len(m) != 4 {
			return
		}
		b.remember(m[2], sessionMapping{chat: m[1], profile: str(args, "profile"), model: str(args, "model"), node: m[3]})
		b.report(ctx, m[2], "working", "Tether chat "+m[1], map[string]string{
			"tether_chat": m[1], "tether_session": m[2], "tether_node": m[3],
			"tether_profile": firstNonEmpty(str(args, "profile"), "claude-main"),
			"tether_model":   str(args, "model"),
		})
		b.watch(ctx, "chat-watch", m[1], m[1])
	case "delegate_task":
		v := jsonObject(text)
		session, _ := v["session"].(string)
		if session == "" {
			return
		}
		task, _ := v["task"].(string)
		profile, _ := v["profile"].(string)
		model, _ := v["model"].(string)
		node, _ := v["node"].(string)
		b.remember(session, sessionMapping{chat: str(args, "chat"), task: task, profile: profile, model: model, node: node})
		b.report(ctx, session, "working", "Tether task "+shortID(task), map[string]string{
			"tether_chat": str(args, "chat"), "tether_session": session, "tether_task": task,
			"tether_profile": profile, "tether_model": model, "tether_node": node,
		})
		b.watch(ctx, "watch", shortID(task), session)
	case "pick_model":
		v := jsonObject(text)
		tokens := map[string]string{}
		for k, key := range map[string]string{"profile": "tether_profile", "model": "tether_model", "decision": "tether_decision", "reason": "tether_reason"} {
			if s, _ := v[k].(string); s != "" {
				tokens[key] = s
			}
		}
		if len(tokens) > 0 {
			b.metadata(ctx, "", tokens)
		}
	case "token_status":
		v := jsonObject(text)
		status, _ := v["status"].(map[string]any)
		var ts tokenStatus
		if raw, err := json.Marshal(status); err == nil {
			_ = json.Unmarshal(raw, &ts)
		}
		decision, _ := status["lastDecision"].(string)
		tokens := map[string]string{"tether_tokens": ts.quotaSummary(), "tether_decision": decision}
		b.mu.Lock()
		b.lastTokens = decision
		b.mu.Unlock()
		b.metadata(ctx, "", tokens)
	case "wait_for_subagents", "collect_results":
		ids := taskLine.FindAllStringSubmatch(text, -1)
		for _, m := range ids {
			if len(m) != 3 {
				continue
			}
			b.report(ctx, m[2], "idle", "Tether task "+shortID(m[1]), map[string]string{"tether_task": m[1], "tether_session": m[2]})
		}
	}
}

func (b *bridge) remember(session string, m sessionMapping) {
	if session == "" {
		return
	}
	b.mu.Lock()
	old := b.mappings[session]
	if m.chat == "" {
		m.chat = old.chat
	}
	if m.task == "" {
		m.task = old.task
	}
	if m.profile == "" {
		m.profile = old.profile
	}
	if m.model == "" {
		m.model = old.model
	}
	if m.node == "" {
		m.node = old.node
	}
	if m.terminal == "" {
		m.terminal = old.terminal
	}
	b.mappings[session] = m
	b.mu.Unlock()
}

func (b *bridge) report(ctx context.Context, session, state, message string, tokens map[string]string) {
	session = firstNonEmpty(session, b.opts.session)
	if err := b.herdr.reportAgent(ctx, state, message, session); err != nil {
		b.herdr.logf("report agent: %v", err)
	}
	b.metadata(ctx, "", tokens)
}

func (b *bridge) metadata(ctx context.Context, title string, tokens map[string]string) {
	if err := b.herdr.reportMetadata(ctx, title, tokens); err != nil {
		b.herdr.logf("report metadata: %v", err)
	}
}

func (b *bridge) watch(ctx context.Context, command, name, target string) {
	if !b.opts.watch || b.opts.hcBin == "" || b.opts.watchBin == "" {
		return
	}
	terminal := "tether-" + shortID(name)
	args := []string{"run", "--bg", "--name", terminal, b.opts.watchBin, command, target}
	if _, err := b.watchRunner.Run(ctx, args...); err != nil {
		b.herdr.logf("open watch terminal: %v", err)
		return
	}
	b.herdr.logf("opened herdr-core terminal %s", terminal)
	b.herdr.reportMetadata(ctx, "", map[string]string{"tether_terminal": terminal})
}

func (b *bridge) pollLoop(ctx context.Context) {
	ticker := time.NewTicker(b.opts.poll)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := b.sync(ctx); err != nil && !errors.Is(err, context.Canceled) {
				b.herdr.logf("sync hub state: %v", err)
			}
		}
	}
}

func (b *bridge) sync(ctx context.Context) error {
	state, err := b.hub.state(ctx)
	if err != nil {
		return err
	}
	b.mu.Lock()
	mappings := make(map[string]sessionMapping, len(b.mappings))
	for k, v := range b.mappings {
		mappings[k] = v
	}
	lastStates := make(map[string]string, len(b.lastStates))
	for k, v := range b.lastStates {
		lastStates[k] = v
	}
	boundSession := b.opts.session
	boundChat := b.opts.chat
	b.mu.Unlock()

	wanted := make(map[string]bool)
	for id := range mappings {
		wanted[id] = true
	}
	if boundSession != "" {
		wanted[boundSession] = true
	}
	if boundChat != "" {
		for _, id := range state.sessionIDsFor(boundChat) {
			wanted[id] = true
		}
	}

	for _, s := range state.Sessions {
		if !wanted[s.ID] {
			continue
		}
		newState := mapSessionState(s.State)
		changed := lastStates[s.ID] != newState
		lastStates[s.ID] = newState
		m := mappings[s.ID]
		tokens := map[string]string{
			"tether_session": s.ID,
			"tether_state":   s.State,
			"tether_node":    firstNonEmpty(m.node, s.Node),
			"tether_profile": firstNonEmpty(m.profile, s.Profile),
			"tether_model":   firstNonEmpty(m.model, s.Model),
			"tether_chat":    firstNonEmpty(m.chat, boundChat),
			"tether_task":    firstNonEmpty(m.task, s.ParentTask),
		}
		if changed {
			b.report(ctx, s.ID, newState, "Tether "+s.Title, tokens)
		} else {
			b.metadata(ctx, "", tokens)
		}
	}
	for id := range wanted {
		if !containsSession(state.Sessions, id) {
			lastStates[id] = "unknown"
			b.report(ctx, id, "unknown", "Tether session is gone", nil)
		}
	}

	decision := state.TokenStatus.LastDecision
	if decision != b.lastTokens {
		b.metadata(ctx, "", map[string]string{
			"tether_tokens":   state.TokenStatus.quotaSummary(),
			"tether_decision": decision,
		})
		b.mu.Lock()
		b.lastTokens = decision
		b.mu.Unlock()
	}

	b.mu.Lock()
	for id, v := range lastStates {
		b.lastStates[id] = v
	}
	b.mu.Unlock()
	return nil
}

func mapSessionState(state string) string {
	switch state {
	case "SESSION_STATE_RUNNING", "SESSION_STATE_TERMINAL_ACTIVE":
		return "working"
	case "SESSION_STATE_AWAITING_APPROVAL":
		return "blocked"
	case "SESSION_STATE_ERROR":
		return "unknown"
	default:
		return "idle"
	}
}

func containsSession(list []sessionState, id string) bool {
	for _, s := range list {
		if s.ID == id {
			return true
		}
	}
	return false
}

func resultText(raw json.RawMessage) string {
	var r struct {
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	}
	if json.Unmarshal(raw, &r) != nil {
		return ""
	}
	var b strings.Builder
	for _, c := range r.Content {
		if c.Type == "text" || c.Type == "" {
			b.WriteString(c.Text)
		}
	}
	return strings.TrimSpace(b.String())
}

func jsonObject(text string) map[string]any {
	if !json.Valid([]byte(text)) {
		return nil
	}
	var v map[string]any
	if json.Unmarshal([]byte(text), &v) != nil {
		return nil
	}
	return v
}

func rpcErrorResponse(id json.RawMessage, err error) rpcResponse {
	code := -32603
	var re *rpcError
	if errors.As(err, &re) {
		code = re.Code
	}
	return rpcResponse{JSONRPC: "2.0", ID: id, Error: &rpcError{Code: code, Message: err.Error()}}
}

func mustJSON(v any) json.RawMessage {
	b, _ := json.Marshal(v)
	return b
}

func str(args map[string]any, key string) string {
	s, _ := args[key].(string)
	return strings.TrimSpace(s)
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func shortID(s string) string {
	if len(s) > 8 {
		return s[:8]
	}
	return s
}

func itoa(n int64) string { return strconv.FormatInt(n, 10) }

func clip(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max]
}
