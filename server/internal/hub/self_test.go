package hub

import (
	"context"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func TestWelcomeTellsAClientWhichDeviceAndNodeAreItsOwn(t *testing.T) {
	h, srv := newTestHubWith(t)
	_, phone := pairWith(t, srv, newCode(t, srv, "secret"), "client", "Pixel")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	agent, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	defer agent.Close(nil)
	_ = agent.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_AgentHello{AgentHello: &v1.AgentHello{Token: "secret", Status: &v1.NodeStatus{Node: "laptop"}}}})
	for i := 0; i < 50 && !h.agentOnline("laptop"); i++ {
		time.Sleep(10 * time.Millisecond)
	}

	status, body := call(t, srv, "GET", "/api/v1/state", phone.Token, "")
	w := &v1.Welcome{}
	if status != 200 || protojson.Unmarshal([]byte(body), w) != nil {
		t.Fatalf("state: %d %s", status, body)
	}
	if w.DeviceId != phone.Device.Id || w.ClientIp == "" {
		t.Fatalf("want the caller's device id and address, got %q %q", w.DeviceId, w.ClientIp)
	}
	// The agent and the client both connect from this machine.
	var laptop *v1.NodeStatus
	for _, n := range w.Nodes {
		if n.Node == "laptop" {
			laptop = n
		}
	}
	if laptop == nil || laptop.Ip != w.ClientIp {
		t.Fatalf("the node on the client's machine should carry its address, got %v (client %q)", laptop, w.ClientIp)
	}

	// Status updates from the agent keep the address the hub saw.
	_ = agent.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_NodeStatus{NodeStatus: &v1.NodeStatus{Node: "laptop", Online: true}}})
	time.Sleep(50 * time.Millisecond)
	h.mu.Lock()
	ip := h.nodes["laptop"].Ip
	h.mu.Unlock()
	if ip != w.ClientIp {
		t.Fatalf("a status update dropped the address: %q", ip)
	}
}
