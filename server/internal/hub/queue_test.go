package hub

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func TestARetriedMessageIsSentOnce(t *testing.T) {
	h, srv := newTestHubWith(t)
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
	body, _ := json.Marshal(map[string]string{"text": "run the tests", "clientId": "c-1"})
	for range 2 {
		if status, out := call(t, srv, "POST", "/api/v1/sessions/s1/messages", "secret", string(body)); status != 200 {
			t.Fatalf("send: %d %s", status, out)
		}
	}
	other, _ := json.Marshal(map[string]string{"text": "and then lint", "clientId": "c-2"})
	call(t, srv, "POST", "/api/v1/sessions/s1/messages", "secret", string(other))

	var texts []string
	for len(texts) < 2 {
		f, err := agent.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		if s := f.GetAgentCommand().GetSend(); s != nil {
			texts = append(texts, s.Text)
		}
	}
	if texts[0] != "run the tests" || texts[1] != "and then lint" {
		t.Fatalf("the agent should get each message once, got %q", texts)
	}
}

func TestUserItemsCarryTheClientsID(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()
	h.noteSentAs("s1", "fix the login", "Pixel (android)", "c-9")
	items := []*v1.TimelineItem{{ItemId: "u1", Kind: &v1.TimelineItem_User{User: &v1.UserText{
		Text: "fix the login\r\n\r\nAttached files (in this folder):\r\n- .tether/attachments/a.png",
	}}}}
	h.tagSources("s1", items)
	if u := items[0].GetUser(); u.ClientId != "c-9" || u.Source != "Pixel (android)" {
		t.Fatalf("stamp: %q %q", u.ClientId, u.Source)
	}
}

func TestAStaleQueuedPlaceholderGoesWhenItsMessageArrives(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()
	h.commit("s1", []*v1.TimelineItem{{ItemId: "queued-1", Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "also update the docs", Queued: true}}}})

	// The hub restarts: nothing in memory knows about the placeholder.
	h.queuedItems = map[string]map[string]string{}
	h.commit("s1", []*v1.TimelineItem{{ItemId: "user-1", Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "also update the docs\r\n"}}}})

	stored, _, _ := h.store.ItemsAfter("s1", 0)
	for _, it := range stored {
		// A removed item is kept without a kind, which clients drop.
		if it.ItemId == "queued-1" && it.Kind != nil {
			t.Fatal("the placeholder should be gone once its message is in the timeline")
		}
	}
	found := false
	for _, it := range stored {
		found = found || it.ItemId == "user-1"
	}
	if !found {
		t.Fatal("the real message is missing")
	}
}
