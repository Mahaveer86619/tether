package hub

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/render"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func TestPreferencesAreSharedWithEveryClient(t *testing.T) {
	_, srv := newTestHubWith(t)
	if status, body := call(t, srv, "PUT", "/api/v1/preferences", "secret", `{"themeMode":"dark","palette":"ocean"}`); status != 200 {
		t.Fatalf("put: %d %s", status, body)
	}
	_, body := call(t, srv, "GET", "/api/v1/state", "secret", "")
	w := &v1.Welcome{}
	if err := protojson.Unmarshal([]byte(body), w); err != nil || w.Preferences.GetPalette() != "ocean" || w.Preferences.Accent != nil {
		t.Fatalf("welcome should carry the preferences: %s", body)
	}
}

func TestTailnetShowsWhatRunsOnEachMachine(t *testing.T) {
	h, srv := newTestHubWith(t)
	h.cfg.TailscaleStatus = func(context.Context) ([]byte, error) {
		return []byte(`{
			"Self": {"HostName": "Jasper", "DNSName": "minipc.tail.ts.net.", "OS": "linux", "TailscaleIPs": ["100.64.0.1"]},
			"Peer": {
				"a": {"HostName": "ZERO", "DNSName": "mobile.tail.ts.net.", "OS": "android", "Online": true, "TailscaleIPs": ["127.0.0.1"]},
				"b": {"HostName": "old", "DNSName": "old-laptop.tail.ts.net.", "OS": "windows", "Online": false, "TailscaleIPs": ["100.64.0.9"]}
			}
		}`), nil
	}
	// A phone app connects; in the test its address is 127.0.0.1.
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close(nil)
	_ = conn.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_ClientHello{ClientHello: &v1.ClientHello{Token: "secret", ClientName: "Pixel"}}})
	if _, err := conn.Read(ctx); err != nil {
		t.Fatal(err)
	}

	_, body := call(t, srv, "GET", "/api/v1/tailnet", "secret", "")
	tn := &v1.Tailnet{}
	if err := protojson.Unmarshal([]byte(body), tn); err != nil || len(tn.Devices) != 3 {
		t.Fatalf("tailnet: %s", body)
	}
	if d := tn.Devices[0]; !d.Self || d.Name != "minipc" {
		t.Errorf("the hub's own machine comes first: %v", d)
	}
	if d := tn.Devices[1]; d.Name != "mobile" || len(d.Clients) != 1 || d.Clients[0] != "Pixel" {
		t.Errorf("the phone should show its app: %v", d)
	}
	if d := tn.Devices[2]; d.Online || d.Name != "old-laptop" {
		t.Errorf("offline machines come last: %v", d)
	}
}

func TestMessagesRememberWhereTheyCameFrom(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()
	h.noteSent("s1", " fix the tests ", "Pixel (android)")
	items := []*v1.TimelineItem{
		{ItemId: "u1", Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "fix the tests"}}},
		{ItemId: "u2", Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "typed by hand"}}},
	}
	h.commit("s1", items)
	stored, _, _ := h.store.ItemsAfter("s1", 0)
	got := map[string]string{}
	for _, it := range stored {
		got[it.ItemId] = it.GetUser().GetSource()
	}
	if got["u1"] != "Pixel (android)" || got["u2"] != sourceTerminal {
		t.Fatalf("sources: %v", got)
	}

	// A rebuild re-renders from the transcript, which doesn't know sources.
	h.keepSources("s1")
	again := []*v1.TimelineItem{{ItemId: "u1", Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "fix the tests"}}}}
	h.tagSources("s1", again)
	if again[0].GetUser().Source != "Pixel (android)" {
		t.Fatalf("a rebuild should keep the source, got %q", again[0].GetUser().Source)
	}
}

func TestTrustedTailnetLetsOwnMachinesInWithoutAToken(t *testing.T) {
	h, srv := newTestHubWith(t)
	h.cfg.TrustTailnet = true
	owner := `{"Self": {"UserID": 1, "DNSName": "minipc.ts.net.", "TailscaleIPs": ["100.64.0.1"]},
		"Peer": {"a": {"UserID": %d, "DNSName": "laptop.ts.net.", "TailscaleIPs": ["127.0.0.1"]}}}`
	h.cfg.TailscaleStatus = func(context.Context) ([]byte, error) { return []byte(fmt.Sprintf(owner, 1)), nil }
	if status, _ := call(t, srv, "GET", "/api/v1/state", "", ""); status != 200 {
		t.Fatalf("the owner's own machine should get in without a token, got %d", status)
	}

	h.tsMu.Lock()
	h.tsStatus = nil // forget the cached status
	h.tsMu.Unlock()
	h.cfg.TailscaleStatus = func(context.Context) ([]byte, error) { return []byte(fmt.Sprintf(owner, 2)), nil }
	if status, _ := call(t, srv, "GET", "/api/v1/state", "", ""); status != 401 {
		t.Fatalf("someone else's machine needs a token, got %d", status)
	}
}

func TestUsageTotalsPerNodeAndWindow(t *testing.T) {
	h, srv := newTestHubWith(t)
	now := time.Now()
	entry := func(id string, at time.Time, out int64) *v1.UsageEntry {
		return &v1.UsageEntry{Session: "s1", MessageId: id, TsMs: at.UnixMilli(), Input: 10, Output: out}
	}
	h.onAgent("laptop", &v1.Frame{Body: &v1.Frame_UsageReport{UsageReport: &v1.UsageReport{Entries: []*v1.UsageEntry{
		entry("recent", now.Add(-time.Hour), 5),
		entry("old", now.Add(-3*24*time.Hour), 100),
	}}}})
	// Reported again with a bigger count: kept once, with the larger value.
	h.onAgent("laptop", &v1.Frame{Body: &v1.Frame_UsageReport{UsageReport: &v1.UsageReport{Entries: []*v1.UsageEntry{entry("recent", now.Add(-time.Hour), 50)}}}})

	h.onAgent("laptop", &v1.Frame{Body: &v1.Frame_PlanUsage{PlanUsage: &v1.PlanUsage{Limits: []*v1.PlanLimit{{Label: "session", Percent: 9}}}}})
	_, body := call(t, srv, "GET", "/api/v1/usage", "secret", "")
	sum := &v1.UsageSummary{}
	if err := protojson.Unmarshal([]byte(body), sum); err != nil || len(sum.Nodes) != 1 {
		t.Fatalf("summary: %s", body)
	}
	n := sum.Nodes[0]
	if n.Window.Output != 50 || n.Window.Messages != 1 || n.Week.Output != 150 || n.Plan.GetLimits()[0].GetPercent() != 9 || n.Plan.Node != "laptop" {
		t.Fatalf("laptop usage: %v", n)
	}
	if len(sum.Sessions) != 1 || sum.Sessions[0].Total.Input != 20 {
		t.Fatalf("sessions: %v", sum.Sessions)
	}
}

func TestWorkspaceRootsCanBeAddedAndRemoved(t *testing.T) {
	_, srv := newTestHubWith(t)
	if status, body := call(t, srv, "PUT", "/api/v1/workspaces", "secret", `{"node":"laptop","path":"C:\\Users\\me\\projects"}`); status != 200 {
		t.Fatalf("put: %d %s", status, body)
	}
	call(t, srv, "PUT", "/api/v1/workspaces", "secret", `{"node":"minipc","path":"/srv"}`)
	call(t, srv, "PUT", "/api/v1/workspaces", "secret", `{"node":"minipc","path":"/srv"}`)
	_, body := call(t, srv, "GET", "/api/v1/workspaces", "secret", "")
	w := &v1.Workspaces{}
	if err := protojson.Unmarshal([]byte(body), w); err != nil || len(w.Roots) != 2 {
		t.Fatalf("roots (added twice counts once): %s", body)
	}
	call(t, srv, "DELETE", "/api/v1/workspaces", "secret", `{"node":"minipc","path":"/srv"}`)
	_, body = call(t, srv, "GET", "/api/v1/workspaces", "secret", "")
	w.Reset()
	if err := protojson.Unmarshal([]byte(body), w); err != nil || len(w.Roots) != 1 || w.Roots[0].Node != "laptop" {
		t.Fatalf("after remove: %s", body)
	}
}

func TestAPastedAppMessageKeepsItsSourceAndClientID(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()
	h.noteSentAs("s1", "make sample files", "Pixel (android)", "abc123")
	b := render.NewBuilder()
	p := b.Feed([]byte(`{"type":"user","uuid":"p1","message":{"role":"user","content":"\n\n<pasted_content id=\"c669\">\nmake sample files\n</pasted_content id=\"c669\">\n"}}`))
	h.commit("s1", p.Items)
	it, _ := h.store.Item("s1", "user:p1")
	if u := it.GetUser(); u.Source != "Pixel (android)" || u.ClientId != "abc123" || u.Text != "make sample files" {
		t.Fatalf("got %v", u)
	}
}

func TestSameMessageIgnoresHowATerminalReflowedIt(t *testing.T) {
	sent := "check the csv\r\n{\"row\":5}\r\n{\"row\":3}\r\n\r\nshould i recalculate?"
	got := "check the csv\n\n{\"row\":5}\n\n{\"row\":3}\n\n\n\nshould i recalculate?"
	if !sameMessage(sent, got) || !sameMessage(sent, got+"\n\nAttached files (in this folder):\n- a.png") {
		t.Fatal("a reflowed paste should match what was sent")
	}
	if sameMessage("fix the tests", "fix the tests now") {
		t.Fatal("different text matched")
	}
}

func TestFilesSentWithAMessageAreLinkedToItsTimelineItem(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()
	shot := &v1.Artifact{Name: "screenshot.png", Mime: "image/png", Session: "s1", Origin: "attachment"}
	if oerr := h.addArtifact(shot); oerr != nil {
		t.Fatal(oerr)
	}
	h.noteSentAs("s1", "what is wrong here?", "Pixel (android)", "c1", shot)
	b := render.NewBuilder()
	p := b.Feed([]byte(`{"type":"user","uuid":"u1","message":{"role":"user","content":"what is wrong here?\n\nAttached files (in this folder):\n- screenshot.png"}}`))
	h.commit("s1", p.Items)
	got, err := h.store.Artifact(shot.Id)
	if err != nil || got == nil || got.ToolUseId != "user:u1" {
		t.Fatalf("artifact after the message: %v, %v", got, err)
	}
}
