package hub

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

type polled struct {
	Items []store.Notification `json:"items"`
	Last  int64                `json:"last"`
}

func poll(t *testing.T, base, token, query string) (int, polled) {
	t.Helper()
	req, _ := http.NewRequest("GET", base+"/n/poll"+query, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	var p polled
	_ = json.Unmarshal(b, &p)
	return res.StatusCode, p
}

func notifyToken(t *testing.T, srv *httptest.Server) string {
	t.Helper()
	status, body := call(t, srv, "POST", "/api/v1/notify-token", "secret", "")
	var got struct{ Token, Tunnel string }
	if status != 200 || json.Unmarshal([]byte(body), &got) != nil || len(got.Token) < 32 {
		t.Fatalf("token: %d %s", status, body)
	}
	return got.Token
}

func TestAFinishedTurnReachesAPollerHoldingTheNotificationToken(t *testing.T) {
	h, srv := newTestHubWith(t)
	token := notifyToken(t, srv)

	// A first poll only says where the log stands.
	if status, p := poll(t, srv.URL, token, ""); status != 200 || len(p.Items) != 0 || p.Last != 0 {
		t.Fatalf("first poll: %d %+v", status, p)
	}

	h.mu.Lock()
	h.sessions["s1"] = &v1.SessionInfo{Id: "s1", Title: "Fix the retries", LastPrompt: "fix them"}
	h.notifyTurnEnded("s1")
	h.mu.Unlock()

	status, p := poll(t, srv.URL, token, "?since=0&wait=1")
	if status != 200 || len(p.Items) != 1 {
		t.Fatalf("poll: %d %+v", status, p)
	}
	n := p.Items[0]
	if n.Kind != "finished" || n.Title != "Fix the retries" || n.Body != "fix them" || n.Session != "s1" {
		t.Errorf("notification: %+v", n)
	}
	if _, again := poll(t, srv.URL, token, "?since="+jsonNum(p.Last)+"&wait=0"); len(again.Items) != 0 {
		t.Errorf("seen already, got %+v", again.Items)
	}
}

func TestAPollWaitsForNewsAndWakesWhenItArrives(t *testing.T) {
	h, srv := newTestHubWith(t)
	token := notifyToken(t, srv)
	done := make(chan polled, 1)
	go func() {
		_, p := poll(t, srv.URL, token, "?since=0&wait=10")
		done <- p
	}()
	time.Sleep(200 * time.Millisecond)
	h.mu.Lock()
	h.notify("approval", "Allow Bash?", "rm -rf build in the repo", "", "s1")
	h.mu.Unlock()
	select {
	case p := <-done:
		if len(p.Items) != 1 || p.Items[0].Kind != "approval" {
			t.Errorf("woke with %+v", p)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("the poll did not wake when a notification arrived")
	}

	start := time.Now()
	_, idle := poll(t, srv.URL, token, "?since="+jsonNum(1)+"&wait=1")
	if len(idle.Items) != 0 || time.Since(start) < 900*time.Millisecond {
		t.Errorf("an idle poll waits out its time: %+v after %v", idle, time.Since(start))
	}
}

func TestOnlyANotificationTokenOpensThePollAndItOpensNothingElse(t *testing.T) {
	_, srv := newTestHubWith(t)
	token := notifyToken(t, srv)
	if status, _ := poll(t, srv.URL, "", "?since=0&wait=0"); status != 401 {
		t.Errorf("no token: %d", status)
	}
	if status, _ := poll(t, srv.URL, "secret", "?since=0&wait=0"); status != 401 {
		t.Errorf("the hub's own token is not a notification token: %d", status)
	}
	if status, _ := call(t, srv, "GET", "/api/v1/state", token, ""); status != 401 {
		t.Errorf("a notification token must not open the API: %d", status)
	}
	if status, _ := poll(t, srv.URL, token, "?since=0&wait=0"); status != 200 {
		t.Errorf("the token should work: %d", status)
	}
	// A new token replaces the old one for the same caller.
	fresh := notifyToken(t, srv)
	if status, _ := poll(t, srv.URL, token, "?since=0&wait=0"); status != 401 {
		t.Errorf("the replaced token still works: %d", status)
	}
	if status, _ := poll(t, srv.URL, fresh, "?since=0&wait=0"); status != 200 {
		t.Errorf("the new token: %d", status)
	}
}

func TestTheTunnelListenerLeavesOutTheTextAndServesNothingElse(t *testing.T) {
	h, srv := newTestHubWith(t)
	token := notifyToken(t, srv)
	h.mu.Lock()
	h.notify("finished", "Fix the retries", "the secret details", "", "s1")
	h.mu.Unlock()

	public := httptest.NewServer(h.scopedHandler(true))
	defer public.Close()
	if status, p := poll(t, public.URL, token, "?since=0&wait=0"); status != 200 || len(p.Items) != 1 || p.Items[0].Title != "Fix the retries" || p.Items[0].Body != "" {
		t.Errorf("through the tunnel: %d %+v", status, p)
	}
	for _, path := range []string{"/api/v1/state", "/ws", "/healthz", "/api/v1/hello", "/api/v1/artifacts"} {
		res, err := http.Get(public.URL + path)
		if err != nil {
			t.Fatal(err)
		}
		res.Body.Close()
		if res.StatusCode != 404 && res.StatusCode != 405 {
			t.Errorf("%s answered %d through the tunnel listener", path, res.StatusCode)
		}
	}

	h.cfg.NotifyBodiesOnTunnel = true
	if _, p := poll(t, public.URL, token, "?since=0&wait=0"); len(p.Items) != 1 || p.Items[0].Body != "the secret details" {
		t.Errorf("with bodies on: %+v", p)
	}
}

func TestATaskSessionOfAChatStaysQuiet(t *testing.T) {
	h, srv := newTestHubWith(t)
	token := notifyToken(t, srv)
	agent, ctx := dialAgent(t, h, srv.URL)
	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"lead the work","target":{"node":"laptop","cwd":"/src/tether"}}`)
	nextCommand(t, agent, ctx, isStart)

	h.mu.Lock()
	h.sessions["task1"] = &v1.SessionInfo{Id: "task1", Title: "a task", Node: "laptop"}
	h.link(h.chats[c.Id], "task1", linkStarted)
	h.notifyTurnEnded("task1")
	h.notifyTurnEnded(c.ActiveSession)
	h.mu.Unlock()

	_, p := poll(t, srv.URL, token, "?since=0&wait=0")
	if len(p.Items) != 1 || p.Items[0].Chat != c.Id {
		t.Fatalf("only the lead's turn should notify: %+v", p.Items)
	}
}

func TestAnApprovalNotifiesAndRevokingADropsItsToken(t *testing.T) {
	h, srv := newTestHubWith(t)
	token := notifyToken(t, srv)
	h.mu.Lock()
	h.sessions["s1"] = &v1.SessionInfo{Id: "s1", Title: "Deploy it"}
	h.notifyApproval(&v1.ApprovalRequest{ApprovalId: "a1", Session: "s1", ToolName: "Bash"})
	h.notifyApproval(&v1.ApprovalRequest{ApprovalId: "a2", Session: "s1", ToolName: "AskUserQuestion"})
	h.mu.Unlock()
	_, p := poll(t, srv.URL, token, "?since=0&wait=0")
	if len(p.Items) != 2 || p.Items[0].Title != "Allow Bash?" || p.Items[1].Title != "Claude has a question" || p.Items[0].Body != "Deploy it" {
		t.Errorf("approvals: %+v", p.Items)
	}

	h.mu.Lock()
	h.dropNotifyTokens("client:admin")
	h.dropNotifyTokens(strings.Repeat("x", 3))
	h.mu.Unlock()
	if status, _ := poll(t, srv.URL, token, "?since=0&wait=0"); status != 401 {
		t.Errorf("a dropped token still works: %d", status)
	}
}

func TestTheTunnelAddressIsFoundInCloudflaredsOutput(t *testing.T) {
	for line, want := range map[string]string{
		"2026-11-08T05:00:00Z INF |  https://quiet-lake-1234.trycloudflare.com                                     |": "https://quiet-lake-1234.trycloudflare.com",
		"2026-11-08T05:00:00Z INF Requesting new quick Tunnel on trycloudflare.com...":                                "",
		"https://example.com/not-a-tunnel": "",
	} {
		if got := tunnelURLIn(line); got != want {
			t.Errorf("tunnelURLIn(%q) = %q, want %q", line, got, want)
		}
	}
}
