package hub

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func newCode(t *testing.T, srv *httptest.Server, token string) string {
	t.Helper()
	status, body := call(t, srv, "POST", "/api/v1/pairing-codes", token, "")
	code := &v1.PairingCode{}
	if status != 200 || protojson.Unmarshal([]byte(body), code) != nil || len(code.Code) != codeLen+1 {
		t.Fatalf("pairing code: %d %s", status, body)
	}
	return code.Code
}

func pairWith(t *testing.T, srv *httptest.Server, code, kind, name string) (int, *v1.PairResult) {
	t.Helper()
	status, body := call(t, srv, "POST", "/api/v1/pair", "", `{"code":"`+code+`","kind":"`+kind+`","name":"`+name+`","platform":"android"}`)
	res := &v1.PairResult{}
	_ = protojson.Unmarshal([]byte(body), res)
	return status, res
}

// helloAs opens a WebSocket and reports whether the hub accepted the hello.
func helloAs(t *testing.T, srv *httptest.Server, hello *v1.Frame) bool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close(nil)
	if err := conn.WriteNow(ctx, hello); err != nil {
		t.Fatal(err)
	}
	// Clients get a welcome; agents get nothing until there's work. A
	// rejection is an error frame followed by a close.
	rctx, rcancel := context.WithTimeout(ctx, time.Second)
	defer rcancel()
	f, err := conn.Read(rctx)
	if err != nil {
		return rctx.Err() != nil
	}
	return f.GetError() == nil
}

func TestPairingGivesEachDeviceItsOwnToken(t *testing.T) {
	_, srv := newTestHubWith(t)
	code := newCode(t, srv, "secret")

	status, phone := pairWith(t, srv, strings.ToLower(code), "client", "Pixel")
	if status != 200 || phone.Token == "" || phone.Device.Kind != "client" {
		t.Fatalf("pair: %d %v", status, phone)
	}
	if status, _ := pairWith(t, srv, code, "client", "again"); status != 401 {
		t.Fatalf("a code works once, got %d", status)
	}
	if status, _ := call(t, srv, "GET", "/api/v1/state", phone.Token, ""); status != 200 {
		t.Fatalf("the phone's token should work, got %d", status)
	}

	status, node := pairWith(t, srv, newCode(t, srv, phone.Token), "node", "laptop")
	if status != 200 {
		t.Fatalf("a paired client can invite a node, got %d", status)
	}
	if status, _ := call(t, srv, "GET", "/api/v1/state", node.Token, ""); status != 401 {
		t.Fatalf("node tokens are for the agent connection only, got %d", status)
	}
	agent := func(name string) *v1.Frame {
		return &v1.Frame{Body: &v1.Frame_AgentHello{AgentHello: &v1.AgentHello{Token: node.Token, Status: &v1.NodeStatus{Node: name}}}}
	}
	if !helloAs(t, srv, agent("laptop")) {
		t.Fatal("the node token should connect as its own node")
	}
	if helloAs(t, srv, agent("minipc")) {
		t.Fatal("a node token must not connect as another node")
	}

	if status, _ := call(t, srv, "DELETE", "/api/v1/devices/"+phone.Device.Id, "secret", ""); status != 200 {
		t.Fatalf("revoke: %d", status)
	}
	if status, _ := call(t, srv, "GET", "/api/v1/state", phone.Token, ""); status != 401 {
		t.Fatalf("a revoked token must stop working, got %d", status)
	}
	_, body := call(t, srv, "GET", "/api/v1/devices", "secret", "")
	if strings.Contains(body, phone.Device.Id) || !strings.Contains(body, node.Device.Id) {
		t.Fatalf("device list after revoke: %s", body)
	}
}

func TestWrongPairingCodesAreRateLimited(t *testing.T) {
	_, srv := newTestHubWith(t)
	code := newCode(t, srv, "secret")
	for range failLimit {
		if status, _ := pairWith(t, srv, "WRONG-CODE0", "client", "x"); status != 401 {
			t.Fatalf("wrong code: %d", status)
		}
	}
	if status, _ := pairWith(t, srv, code, "client", "x"); status != 429 {
		t.Fatalf("after %d failures even a good code waits, got %d", failLimit, status)
	}
}
