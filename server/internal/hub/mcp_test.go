package hub

import (
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"
)

func rpc(t *testing.T, srv *httptest.Server, token, body string) (int, map[string]any) {
	t.Helper()
	status, out := call(t, srv, "POST", "/mcp", token, body)
	var m map[string]any
	_ = json.Unmarshal([]byte(out), &m)
	return status, m
}

func toolText(t *testing.T, m map[string]any) string {
	t.Helper()
	res, _ := m["result"].(map[string]any)
	content, _ := res["content"].([]any)
	if len(content) == 0 {
		t.Fatalf("no content: %v", m)
	}
	return content[0].(map[string]any)["text"].(string)
}

func TestMCPServer(t *testing.T) {
	_, srv := newTestHubWith(t)
	status, m := rpc(t, srv, "secret", `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}`)
	if status != 200 || m["result"].(map[string]any)["serverInfo"].(map[string]any)["name"] != "tether" {
		t.Fatalf("initialize: %d %v", status, m)
	}
	if status, _ := rpc(t, srv, "secret", `{"jsonrpc":"2.0","method":"notifications/initialized"}`); status != 202 {
		t.Fatalf("notification: %d", status)
	}
	_, m = rpc(t, srv, "secret", `{"jsonrpc":"2.0","id":2,"method":"tools/list"}`)
	if tools := m["result"].(map[string]any)["tools"].([]any); len(tools) != len(mcpTools) {
		t.Fatalf("tools: %v", tools)
	}

	_, m = rpc(t, srv, "secret", `{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"save_artifact","arguments":{"name":"notes.md","content":"remember this"}}}`)
	saved := toolText(t, m)
	id := strings.TrimSuffix(strings.TrimPrefix(saved, "Saved as artifact "), ".")
	_, m = rpc(t, srv, "secret", `{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"read_artifact","arguments":{"id":"`+id+`"}}}`)
	if got := toolText(t, m); got != "remember this" {
		t.Fatalf("read back: %q", got)
	}

	_, m = rpc(t, srv, "secret", `{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"read_session","arguments":{"session":"s1"}}}`)
	if got := toolText(t, m); !strings.Contains(got, "User: hi") {
		t.Fatalf("read_session: %q", got)
	}
	if status, _ := rpc(t, srv, "", `{"jsonrpc":"2.0","id":6,"method":"tools/list"}`); status != 401 {
		t.Fatalf("no token: %d", status)
	}
}
