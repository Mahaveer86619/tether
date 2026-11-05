package hub

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/Mahaveer86619/tether/server/internal/store"
)

func TestTheAuditLogRecordsToolCallsWithoutTheirContent(t *testing.T) {
	_, srv := newTestHubWith(t)
	body := `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"save_artifact","arguments":{"name":"notes.md","content":"password hunter2","session":"s1"}}}`
	if status, out := call(t, srv, "POST", "/mcp", "secret", body); status != 200 || strings.Contains(out, `"isError":true`) {
		t.Fatalf("mcp: %d %s", status, out)
	}
	bad := `{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"read_session","arguments":{"session":"nope"}}}`
	call(t, srv, "POST", "/mcp", "secret", bad)

	status, out := call(t, srv, "GET", "/api/v1/audit?kind=mcp", "secret", "")
	var list []store.AuditEntry
	if status != 200 || json.Unmarshal([]byte(out), &list) != nil || len(list) != 2 {
		t.Fatalf("audit: %d %s", status, out)
	}
	if list[0].Subject != "read_session" || list[0].OK || list[1].Subject != "save_artifact" || !list[1].OK {
		t.Errorf("entries: %+v", list)
	}
	if strings.Contains(out, "hunter2") || !strings.Contains(list[1].Detail, "name=notes.md") || !strings.Contains(list[1].Detail, "session=s1") {
		t.Errorf("detail: %q", list[1].Detail)
	}
	if status, out := call(t, srv, "GET", "/api/v1/audit?before="+jsonNum(list[0].ID), "secret", ""); status != 200 || !strings.Contains(out, "save_artifact") || strings.Contains(out, "read_session") {
		t.Errorf("paging: %d %s", status, out)
	}
	if status, _ := call(t, srv, "GET", "/api/v1/audit", "", ""); status != 401 {
		t.Errorf("without a token: %d", status)
	}
}

func jsonNum(n int64) string { b, _ := json.Marshal(n); return string(b) }
