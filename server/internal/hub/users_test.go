package hub

import (
	"context"
	"io"
	"log/slog"
	"net/http/httptest"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/store"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

// team is a hub with two users, each with an app token, an agent on their
// own machine and a chat running there.
type team struct {
	h   *Hub
	srv *httptest.Server

	ownerTok, mateTok, mateNodeTok string
	mate                           *v1.User
	laptop, desktop                *wire.Conn
	ctx                            context.Context

	ownerChat, mateChat *v1.Chat
	// What each machine's agent is sent, read in the background: a read
	// that times out would close the connection.
	toLaptop, toDesktop feed
}

type feed chan *v1.Frame

func watch(ctx context.Context, conn *wire.Conn) feed {
	ch := make(feed, 1000)
	go func() {
		defer close(ch)
		for {
			f, err := conn.Read(ctx)
			if err != nil {
				return
			}
			ch <- f
		}
	}()
	return ch
}

// nextStart waits for the next start command a machine is sent.
func nextStart(t *testing.T, ch feed) *v1.AgentCommand_StartRun {
	t.Helper()
	timeout := time.After(5 * time.Second)
	for {
		select {
		case f, ok := <-ch:
			if !ok {
				t.Fatal("connection closed")
			}
			if s := f.GetAgentCommand().GetStart(); s != nil {
				return s
			}
		case <-timeout:
			t.Fatal("no start command")
		}
	}
}

// closed waits for the hub to close a connection.
func closed(t *testing.T, ch feed) {
	t.Helper()
	timeout := time.After(5 * time.Second)
	for {
		select {
		case _, ok := <-ch:
			if !ok {
				return
			}
		case <-timeout:
			t.Fatal("the connection stayed open")
		}
	}
}

func newTeam(t *testing.T) *team {
	t.Helper()
	h, srv := newTestHubWith(t)
	tm := &team{h: h, srv: srv}
	_, res := pairWith(t, srv, newCode(t, srv, "secret"), "client", "owner-phone")
	tm.ownerTok = res.Token
	tm.mateTok, tm.mate = tm.invite(t, "Teammate")

	status, body := call(t, srv, "POST", "/api/v1/pairing-codes", tm.mateTok, "")
	code := &v1.PairingCode{}
	if status != 200 || protojson.Unmarshal([]byte(body), code) != nil {
		t.Fatalf("mate's pairing code: %d %s", status, body)
	}
	_, res = pairWith(t, srv, code.Code, "node", "desktop")
	if res.Device.GetUser() != tm.mate.Id {
		t.Fatalf("desktop belongs to %q", res.Device.GetUser())
	}
	tm.mateNodeTok = res.Token

	tm.laptop, tm.ctx = dialAgent(t, h, srv.URL)
	tm.desktop = tm.dialNode(t, "desktop", tm.mateNodeTok)

	tm.ownerChat = tm.chat(t, tm.ownerTok, "laptop", 200)
	nextCommand(t, tm.laptop, tm.ctx, isStart)
	tm.mateChat = tm.chat(t, tm.mateTok, "desktop", 200)
	nextCommand(t, tm.desktop, tm.ctx, isStart)
	tm.toLaptop, tm.toDesktop = watch(tm.ctx, tm.laptop), watch(tm.ctx, tm.desktop)
	return tm
}

func (tm *team) invite(t *testing.T, name string) (string, *v1.User) {
	t.Helper()
	status, body := call(t, tm.srv, "POST", "/api/v1/invites", "secret", "")
	code := &v1.PairingCode{}
	if status != 200 || protojson.Unmarshal([]byte(body), code) != nil {
		t.Fatalf("invite: %d %s", status, body)
	}
	status, body = call(t, tm.srv, "POST", "/api/v1/pair", "", `{"code":"`+code.Code+`","kind":"client","name":"phone","userName":"`+name+`"}`)
	res := &v1.PairResult{}
	if status != 200 || protojson.Unmarshal([]byte(body), res) != nil || res.User.GetRole() != roleMember {
		t.Fatalf("join: %d %s", status, body)
	}
	return res.Token, res.User
}

func (tm *team) dialNode(t *testing.T, node, token string) *wire.Conn {
	t.Helper()
	conn, err := wire.Dial(tm.ctx, "ws"+strings.TrimPrefix(tm.srv.URL, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close(nil) })
	_ = conn.WriteNow(tm.ctx, &v1.Frame{Body: &v1.Frame_AgentHello{AgentHello: &v1.AgentHello{Token: token, Status: &v1.NodeStatus{Node: node}}}})
	for i := 0; i < 50 && !tm.h.agentOnline(node); i++ {
		time.Sleep(10 * time.Millisecond)
	}
	return conn
}

func (tm *team) chat(t *testing.T, token, node string, want int) *v1.Chat {
	t.Helper()
	status, out := call(t, tm.srv, "POST", "/api/v1/chats", token, `{"prompt":"Run the tests","target":{"node":"`+node+`","cwd":"/src/app"}}`)
	c := &v1.Chat{}
	if status != want || status == 200 && protojson.Unmarshal([]byte(out), c) != nil {
		t.Fatalf("chat on %s: %d %s", node, status, out)
	}
	return c
}

// app connects as an app and returns its welcome, the connection and what
// comes in on it.
func (tm *team) app(t *testing.T, token string) (*v1.Welcome, *wire.Conn, feed) {
	t.Helper()
	conn, err := wire.Dial(tm.ctx, "ws"+strings.TrimPrefix(tm.srv.URL, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close(nil) })
	_ = conn.WriteNow(tm.ctx, &v1.Frame{Body: &v1.Frame_ClientHello{ClientHello: &v1.ClientHello{Token: token, ClientName: "test"}}})
	f, err := conn.Read(tm.ctx)
	if err != nil || f.GetWelcome() == nil {
		t.Fatalf("welcome: %v %v", f, err)
	}
	return f.GetWelcome(), conn, watch(tm.ctx, conn)
}

func ids(w *v1.Welcome) string {
	var b strings.Builder
	for _, s := range w.Sessions {
		b.WriteString(s.Id + " ")
	}
	for _, c := range w.Chats {
		b.WriteString(c.Id + " ")
	}
	for _, n := range w.Nodes {
		b.WriteString(n.Node + " ")
	}
	return b.String()
}

// noFrame fails if a frame about any of the given strings comes within a
// short wait, and returns the frames that came.
func noFrame(t *testing.T, ch feed, about ...string) []*v1.Frame {
	t.Helper()
	var got []*v1.Frame
	timeout := time.After(300 * time.Millisecond)
	for {
		select {
		case f, ok := <-ch:
			if !ok {
				return got
			}
			got = append(got, f)
			b, _ := protojson.Marshal(f)
			for _, s := range about {
				if strings.Contains(string(b), s) {
					t.Fatalf("got a frame about %s: %s", s, b)
				}
			}
		case <-timeout:
			return got
		}
	}
}

func TestTwoUsersSeeOnlyTheirOwn(t *testing.T) {
	tm := newTeam(t)
	h, srv := tm.h, tm.srv
	ownerSession, mateSession := tm.ownerChat.ActiveSession, tm.mateChat.ActiveSession

	// REST state and the socket's welcome.
	for _, who := range []struct {
		token, mine, theirs string
	}{{tm.ownerTok, ownerSession, mateSession}, {tm.mateTok, mateSession, ownerSession}} {
		_, body := call(t, srv, "GET", "/api/v1/state", who.token, "")
		if !strings.Contains(body, who.mine) || strings.Contains(body, who.theirs) {
			t.Fatalf("state shows the wrong sessions: %s", body)
		}
		w, _, _ := tm.app(t, who.token)
		if got := ids(w); !strings.Contains(got, who.mine) || strings.Contains(got, who.theirs) {
			t.Fatalf("welcome: %s", got)
		}
	}
	w, mateApp, fromHub := tm.app(t, tm.mateTok)
	if got := ids(w); strings.Contains(got, "laptop") || strings.Contains(got, "s1 ") || !strings.Contains(got, "desktop") {
		t.Fatalf("the teammate sees the owner's machine or sessions: %s", got)
	}
	if w.Me.GetId() != tm.mate.Id || len(w.Users) != 2 {
		t.Fatalf("me %v users %v", w.Me, w.Users)
	}
	_, body := call(t, srv, "GET", "/api/v1/chats", tm.mateTok, "")
	if strings.Contains(body, tm.ownerChat.Id) || !strings.Contains(body, tm.mateChat.Id) {
		t.Fatalf("chats: %s", body)
	}

	// An approval for the owner's session goes to the owner only.
	_ = tm.laptop.WriteNow(tm.ctx, &v1.Frame{Body: &v1.Frame_ApprovalRequested{ApprovalRequested: &v1.ApprovalRequest{ApprovalId: "ap1", Session: ownerSession, ToolName: "Bash", InputJson: `{"command":"ls"}`}}})
	if status, _ := call(t, srv, "POST", "/api/v1/approvals/ap1", tm.mateTok, `{"decision":"DECISION_ALLOW"}`); status != 403 {
		t.Fatalf("the teammate answered the owner's approval: %d", status)
	}
	_ = mateApp.WriteNow(tm.ctx, &v1.Frame{Id: "x", Body: &v1.Frame_ApprovalDecision{ApprovalDecision: &v1.ApprovalDecision{ApprovalId: "ap1", Decision: v1.Decision_DECISION_ALLOW}}})
	got := noFrame(t, fromHub, "ap1", ownerSession)
	if len(got) != 1 || got[0].GetError().GetCode() != "forbidden" {
		t.Fatalf("socket decision: %v", got)
	}
	_, body = call(t, srv, "GET", "/api/v1/state", tm.ownerTok, "")
	if !strings.Contains(body, "ap1") {
		t.Fatalf("the owner lost their approval: %s", body)
	}

	// Notifications.
	h.mu.Lock()
	h.notify("turn", "Owner's work is done", "", tm.ownerChat.Id, ownerSession)
	h.notify("turn", "Mate's work is done", "", tm.mateChat.Id, mateSession)
	h.mu.Unlock()
	_, body = call(t, srv, "GET", "/api/v1/notifications", tm.mateTok, "")
	if strings.Contains(body, "Owner's") || !strings.Contains(body, "Mate's") {
		t.Fatalf("notifications: %s", body)
	}
	status, body := call(t, srv, "POST", "/api/v1/notify-token", tm.mateTok, "")
	if status != 200 {
		t.Fatalf("notify token: %d %s", status, body)
	}
	tok := body[strings.Index(body, `"token":"`)+9:]
	tok = tok[:strings.Index(tok, `"`)]
	_, polled := poll(t, srv.URL, tok, "?since=0&wait=0")
	for _, n := range polled.Items {
		if n.Session == ownerSession {
			t.Fatalf("the teammate's phone polled the owner's notification")
		}
	}

	// Files.
	a := upload(t, srv.URL, "notes.txt", "secret plans", map[string]string{"Authorization": "Bearer " + tm.ownerTok, "X-Session": ownerSession})
	_, body = call(t, srv, "GET", "/api/v1/artifacts", tm.mateTok, "")
	if strings.Contains(body, a.Id) {
		t.Fatalf("artifacts: %s", body)
	}
	if status, body := call(t, srv, "GET", "/api/v1/artifacts/"+a.Id+"/content", tm.mateTok, ""); status != 403 || strings.Contains(body, "secret plans") {
		t.Fatalf("content: %d %s", status, body)
	}
	if status, _ := call(t, srv, "GET", "/api/v1/artifacts/"+a.Id+"/content", tm.ownerTok, ""); status != 200 {
		t.Fatalf("the owner cannot read their file: %d", status)
	}

	// MCP, as the teammate's agent.
	_, m := rpc(t, srv, tm.mateNodeTok, `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list_sessions","arguments":{}}}`)
	if text := toolText(t, m); strings.Contains(text, ownerSession) || !strings.Contains(text, mateSession) {
		t.Fatalf("list_sessions: %s", text)
	}
	_, m = rpc(t, srv, tm.mateNodeTok, `{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"read_session","arguments":{"session":"`+ownerSession+`"}}}`)
	if text := toolText(t, m); !strings.Contains(text, "unknown session") {
		t.Fatalf("read_session: %s", text)
	}
	_, m = rpc(t, srv, tm.mateNodeTok, `{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_nodes","arguments":{}}}`)
	if text := toolText(t, m); strings.Contains(text, "laptop") {
		t.Fatalf("list_nodes: %s", text)
	}
	_, m = rpc(t, srv, tm.mateNodeTok, `{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"start_session","arguments":{"prompt":"hi","node":"laptop"}}}`)
	if text := toolText(t, m); !strings.Contains(text, "access") {
		t.Fatalf("start_session on the owner's machine: %s", text)
	}

	// New sessions of the owner's are not sent to the teammate's app.
	h.mu.Lock()
	h.putSession(&v1.SessionInfo{Id: "terminal-1", Node: "laptop", State: v1.SessionState_SESSION_STATE_IDLE})
	h.mu.Unlock()
	noFrame(t, fromHub, "terminal-1")
}

func TestASharedChatShowsToThatMemberOnly(t *testing.T) {
	tm := newTeam(t)
	thirdTok, _ := tm.invite(t, "Third")
	share := func(user, access string) int {
		status, _ := call(t, tm.srv, "PUT", "/api/v1/chats/"+tm.ownerChat.Id+"/shares", tm.ownerTok, `{"user":"`+user+`","access":"`+access+`"}`)
		return status
	}
	if status, _ := call(t, tm.srv, "PUT", "/api/v1/chats/"+tm.ownerChat.Id+"/shares", tm.mateTok, `{"user":"`+tm.mate.Id+`","access":"read"}`); status != 403 {
		t.Fatalf("the teammate shared the owner's chat with themselves: %d", status)
	}
	if share(tm.mate.Id, shareRead) != 200 {
		t.Fatal("share")
	}
	_, body := call(t, tm.srv, "GET", "/api/v1/chats", tm.mateTok, "")
	if !strings.Contains(body, tm.ownerChat.Id) || !strings.Contains(body, tm.ownerChat.ActiveSession) {
		t.Fatalf("the teammate does not see the shared chat: %s", body)
	}
	if _, body := call(t, tm.srv, "GET", "/api/v1/state", tm.mateTok, ""); !strings.Contains(body, tm.ownerChat.ActiveSession) {
		t.Fatalf("the shared chat's session is missing: %s", body)
	}
	if status, _ := call(t, tm.srv, "GET", "/api/v1/sessions/"+tm.ownerChat.ActiveSession+"/timeline", tm.mateTok, ""); status != 200 {
		t.Fatalf("timeline of a shared chat: %d", status)
	}
	for _, path := range []string{"/api/v1/chats", "/api/v1/state"} {
		if _, body := call(t, tm.srv, "GET", path, thirdTok, ""); strings.Contains(body, tm.ownerChat.Id) {
			t.Fatalf("a third user sees the shared chat in %s", path)
		}
	}
	if status, _ := call(t, tm.srv, "POST", "/api/v1/chats/"+tm.ownerChat.Id+"/messages", tm.mateTok, `{"text":"hello"}`); status != 403 {
		t.Fatalf("a reader sent into the chat: %d", status)
	}
	if share(tm.mate.Id, shareCollaborate) != 200 {
		t.Fatal("collaborate")
	}
	if status, body := call(t, tm.srv, "POST", "/api/v1/chats/"+tm.ownerChat.Id+"/messages", tm.mateTok, `{"text":"hello"}`); status != 200 {
		t.Fatalf("a collaborator could not send: %d %s", status, body)
	}
	_, _, fromHub := tm.app(t, tm.mateTok)
	if share(tm.mate.Id, "") != 200 {
		t.Fatal("unshare")
	}
	closed(t, fromHub)
	if _, body := call(t, tm.srv, "GET", "/api/v1/chats", tm.mateTok, ""); strings.Contains(body, tm.ownerChat.Id) {
		t.Fatalf("still shared after unsharing: %s", body)
	}
}

func TestDeviceSharing(t *testing.T) {
	tm := newTeam(t)
	h, srv := tm.h, tm.srv
	grant := func(token, access string) int {
		status, _ := call(t, srv, "PUT", "/api/v1/nodes/laptop/grants", token, `{"user":"`+tm.mate.Id+`","access":"`+access+`"}`)
		return status
	}

	// Not shared: the owner's machine never hears of the teammate's prompt.
	tm.chat(t, tm.mateTok, "laptop", 403)
	if status, _ := call(t, srv, "POST", "/api/v1/sessions", tm.mateTok, `{"node":"laptop","prompt":"rm -rf"}`); status != 403 {
		t.Fatalf("create session: %d", status)
	}
	noFrame(t, tm.toLaptop, "rm -rf", "Run the tests")
	if grant(tm.mateTok, accessFull) != 403 {
		t.Fatal("the teammate shared the owner's device with themselves")
	}

	// Jobs only: no Claude session, but jobs.
	if grant(tm.ownerTok, accessJobs) != 200 {
		t.Fatal("jobs grant")
	}
	tm.chat(t, tm.mateTok, "laptop", 403)
	h.mu.Lock()
	mate := h.asUser(tm.mate.Id)
	jobs, claude := h.can(mate, actRunJob, objNode, "laptop"), h.can(mate, actRunClaude, objNode, "laptop")
	h.mu.Unlock()
	if !jobs || claude {
		t.Fatalf("jobs-only: jobs %v claude %v", jobs, claude)
	}

	// Full: the teammate's chat runs there, as theirs, and the owner sees it.
	if grant(tm.ownerTok, accessFull) != 200 {
		t.Fatal("full grant")
	}
	c := tm.chat(t, tm.mateTok, "laptop", 200)
	if start := nextStart(t, tm.toLaptop); start.Session != c.ActiveSession {
		t.Fatalf("start %v", start)
	}
	h.mu.Lock()
	owner := h.sessions[c.ActiveSession].Owner
	h.mu.Unlock()
	if owner != tm.mate.Id {
		t.Fatalf("the delegated session belongs to %q", owner)
	}
	if _, body := call(t, srv, "GET", "/api/v1/state", tm.ownerTok, ""); !strings.Contains(body, c.ActiveSession) {
		t.Fatal("the device's owner does not see what runs on it")
	}
	if status, _ := call(t, srv, "POST", "/api/v1/sessions/"+c.ActiveSession+"/stop", tm.ownerTok, ""); status != 200 {
		t.Fatalf("the device's owner could not stop it: %d", status)
	}
	if status, _ := call(t, srv, "POST", "/api/v1/sessions/"+c.ActiveSession+"/messages", tm.ownerTok, `{"text":"hi"}`); status != 403 {
		t.Fatalf("the device's owner sent into the teammate's session: %d", status)
	}
	_ = tm.laptop.WriteNow(tm.ctx, &v1.Frame{Body: &v1.Frame_ApprovalRequested{ApprovalRequested: &v1.ApprovalRequest{ApprovalId: "ap2", Session: c.ActiveSession, ToolName: "Bash", InputJson: `{}`}}})
	time.Sleep(100 * time.Millisecond)
	if _, body := call(t, srv, "GET", "/api/v1/state", tm.mateTok, ""); !strings.Contains(body, "ap2") {
		t.Fatal("the approval did not go to the person who delegated")
	}
	w, _, _ := tm.app(t, tm.ownerTok)
	for _, n := range w.Nodes {
		if n.Node == "laptop" && (n.Owner == "" || len(n.Grants) != 1 || n.Grants[0].Access != accessFull) {
			t.Fatalf("laptop as its owner sees it: %v", n)
		}
	}

	// Revoking closes the teammate's open connection, and the laptop is gone
	// from what they see when they come back.
	_, _, fromHub := tm.app(t, tm.mateTok)
	if status, _ := call(t, srv, "DELETE", "/api/v1/nodes/laptop/grants/"+tm.mate.Id, tm.ownerTok, ""); status != 200 {
		t.Fatal("revoke")
	}
	closed(t, fromHub)
	w, _, _ = tm.app(t, tm.mateTok)
	if strings.Contains(ids(w), "laptop") {
		t.Fatalf("the laptop is still shared: %s", ids(w))
	}
	tm.chat(t, tm.mateTok, "laptop", 403)
	entries, _ := h.store.Audit("grant", 0, 50)
	var audited []string
	for _, e := range entries {
		if e.Kind == "grant" {
			audited = append(audited, e.Detail)
		}
	}
	if len(audited) != 3 {
		t.Fatalf("audit: %v", audited)
	}
}

func TestANodeNameOfAnotherUserCannotBeTaken(t *testing.T) {
	tm := newTeam(t)
	status, body := call(t, tm.srv, "POST", "/api/v1/pairing-codes", tm.mateTok, "")
	code := &v1.PairingCode{}
	_ = protojson.Unmarshal([]byte(body), code)
	if status, _ = pairWith(t, tm.srv, code.Code, "node", "laptop"); status != 409 {
		t.Fatalf("the teammate took over the owner's laptop: %d", status)
	}
	// The mate's node token connects only as its own node.
	if helloAs(t, tm.srv, &v1.Frame{Body: &v1.Frame_AgentHello{AgentHello: &v1.AgentHello{Token: tm.mateNodeTok, Status: &v1.NodeStatus{Node: "laptop"}}}}) {
		t.Fatal("the desktop's token connected as the laptop")
	}
}

func TestMigrationGivesTheFirstUserEverything(t *testing.T) {
	dir := t.TempDir()
	st, err := store.Open(filepath.Join(dir, "hub.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	_ = st.PutSession(&v1.SessionInfo{Id: "old", Node: "laptop"})
	_ = st.PutChat(&v1.Chat{Id: "c-old", Title: "old chat"})
	_ = st.PutDevice(&v1.Device{Id: "d-old", Kind: kindClient, Name: "phone"}, hashToken("old-token"))
	_ = st.PutArtifact(&v1.Artifact{Id: "a-old", Sha256: "x", Name: "n", Mime: "text/plain"})
	_, _ = st.AddNotification(store.Notification{Kind: "turn", Title: "old"}, 100)
	h, err := New(Config{Token: "secret", Log: slog.New(slog.NewTextHandler(io.Discard, nil)), DataDir: dir}, st)
	if err != nil {
		t.Fatal(err)
	}
	owner := h.ownerID
	if u := h.users[owner]; u == nil || u.Role != roleAdmin || len(h.users) != 1 {
		t.Fatalf("users %v", h.users)
	}
	if h.sessions["old"].Owner != owner || h.chats["c-old"].Owner != owner {
		t.Fatal("sessions and chats")
	}
	devices, _ := st.Devices()
	if devices[hashToken("old-token")].User != owner {
		t.Fatal("devices")
	}
	if a, _ := st.Artifact("a-old"); a.Owner != owner {
		t.Fatal("artifacts")
	}
	if n, _ := st.NotificationsAfter(owner, 0, 10); len(n) != 1 {
		t.Fatal("notifications")
	}
	id, ok := h.identify("old-token")
	if !ok || id.userID() != owner {
		t.Fatal("an app paired before users is the owner's")
	}
	// A second start keeps the same owner.
	h2, err := New(Config{Token: "secret", Log: slog.New(slog.NewTextHandler(io.Discard, nil)), DataDir: dir}, st)
	if err != nil || h2.ownerID != owner {
		t.Fatalf("restart: %v %s", err, h2.ownerID)
	}
}

// Every route the hub registers has a policy (or is public), so a new
// route is closed until someone decides who may use it.
func TestEveryRouteHasAPolicy(t *testing.T) {
	re := regexp.MustCompile(`HandleFunc\("([^"]+)"`)
	files, _ := filepath.Glob("*.go")
	for _, f := range files {
		if strings.HasSuffix(f, "_test.go") {
			continue
		}
		b, _ := os.ReadFile(f)
		for _, m := range re.FindAllStringSubmatch(string(b), -1) {
			if routePolicy[m[1]] == nil && !publicRoutes[m[1]] {
				t.Errorf("%s: %s has no policy in guard.go", f, m[1])
			}
		}
	}
}

// With no rights to the owner's things, each route answers forbidden, or
// answers with nothing of the owner's.
func TestEveryRouteRefusesWithoutRights(t *testing.T) {
	tm := newTeam(t)
	h, srv := tm.h, tm.srv
	a := upload(t, srv.URL, "owner.txt", "owner data", map[string]string{"Authorization": "Bearer " + tm.ownerTok, "X-Session": tm.ownerChat.ActiveSession})
	status, body := call(t, srv, "POST", "/api/v1/projects", tm.ownerTok, `{"name":"warehouse","folders":[{"node":"laptop","cwd":"/src/app"}]}`)
	if status != 200 {
		t.Fatalf("project: %d %s", status, body)
	}
	project := body[strings.Index(body, `"id":"`)+6:]
	project = project[:strings.Index(project, `"`)]
	h.mu.Lock()
	h.approvals["ap-owner"] = &v1.ApprovalRequest{ApprovalId: "ap-owner", Session: tm.ownerChat.ActiveSession, Node: "laptop"}
	var ownerDevice string
	for _, d := range h.devices {
		if d.User == h.ownerID {
			ownerDevice = d.Id
		}
	}
	h.mu.Unlock()
	secrets := []string{tm.ownerChat.Id, tm.ownerChat.ActiveSession, a.Id, project, "owner data", ownerDevice, `"s1"`}
	fill := map[string]string{
		"id": "", "action": "stop", "node": "laptop", "user": h.ownerID, "repo": "r1", "name": "x", "version": "1.0.0", "sha": strings.Repeat("a", 64),
	}
	refused := 0
	for pattern := range routePolicy {
		method, path, _ := strings.Cut(pattern, " ")
		if path == "" {
			method, path = "GET", pattern
		}
		id := tm.ownerChat.ActiveSession
		switch {
		case strings.Contains(path, "/chats/{id}"):
			id = tm.ownerChat.Id
		case strings.Contains(path, "/artifacts/{id}"):
			id = a.Id
		case strings.Contains(path, "/projects/{id}"):
			id = project
		case strings.Contains(path, "/approvals/{id}"):
			id = "ap-owner"
		case strings.Contains(path, "/devices/{id}"):
			id = ownerDevice
		case strings.Contains(path, "/uploads/{id}"), strings.Contains(path, "/codebases/{id}"), strings.Contains(path, "/snapshots/{id}"), strings.Contains(path, "/rules/{id}"):
			id = "00000000-0000-0000-0000-000000000000"
		}
		fill["id"] = id
		for k, v := range fill {
			path = strings.ReplaceAll(path, "{"+k+"}", v)
		}
		if strings.HasSuffix(path, "/git/") {
			path += "r1.git/info/refs"
		}
		if strings.Contains(path, "{") {
			t.Fatalf("unfilled %s", path)
		}
		query := ""
		switch {
		case path == "/api/v1/pages":
			query = "?session=" + tm.ownerChat.ActiveSession
		case path == "/api/v1/artifacts" && method == "GET":
			query = "?session=" + tm.ownerChat.ActiveSession
		}
		reqBody := `{"node":"laptop","prompt":"x","text":"x","user":"` + tm.mate.Id + `","access":"full","decision":"DECISION_ALLOW"}`
		status, out := call(t, srv, method, path+query, tm.mateTok, reqBody)
		if status == 403 {
			refused++
			continue
		}
		for _, s := range secrets {
			if s != "" && strings.Contains(out, s) {
				t.Errorf("%s %s answered %d with the owner's %s: %.200s", method, path, status, s, out)
			}
		}
		if status == 200 && method != "GET" && !strings.HasPrefix(path, "/api/v1/projects") && path != "/api/v1/chats" &&
			path != "/api/v1/notifications/test" && path != "/api/v1/notify-token" && path != "/api/v1/pairing-codes" {
			t.Errorf("%s %s changed something: %d %.200s", method, path, status, out)
		}
	}
	if refused < 80 {
		t.Errorf("only %d of %d routes refused", refused, len(routePolicy))
	}
	// Nothing reached the owner's machine.
	noFrame(t, tm.toLaptop, `"x"`)
}
