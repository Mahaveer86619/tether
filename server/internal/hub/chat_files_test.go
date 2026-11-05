package hub

import (
	"strings"
	"testing"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestChatFilesGatherEverySessionOfTheChat(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"build it","target":{"node":"laptop","cwd":"/src/tether"}}`)
	nextCommand(t, agent, ctx, isStart)

	upload(t, srv.URL, "app.apk", "APK", map[string]string{"X-Session": c.ActiveSession, "X-Origin": "result"})
	upload(t, srv.URL, "rows.csv", "a,b", map[string]string{"X-Session": c.ActiveSession, "X-Origin": "result"})
	upload(t, srv.URL, "shot.png", "PNG", map[string]string{"X-Session": c.ActiveSession, "X-Origin": "attachment"})
	upload(t, srv.URL, "other.csv", "x", map[string]string{"X-Session": "someone-elses", "X-Origin": "result"})

	names := func(query string) []string {
		t.Helper()
		status, body := call(t, srv, "GET", "/api/v1/chats/"+c.Id+"/artifacts"+query, "secret", "")
		list := &v1.ArtifactList{}
		if status != 200 || protojson.Unmarshal([]byte(body), list) != nil {
			t.Fatalf("%s: %d %s", query, status, body)
		}
		var out []string
		for _, a := range list.Artifacts {
			out = append(out, a.Name)
		}
		return out
	}
	if got := names(""); len(got) != 3 {
		t.Errorf("all: %v", got)
	}
	if got := names("?origin=made"); len(got) != 2 {
		t.Errorf("made: %v", got)
	}
	if got := names("?origin=sent"); len(got) != 1 || got[0] != "shot.png" {
		t.Errorf("sent: %v", got)
	}
	if got := names("?q=CSV"); len(got) != 1 || got[0] != "rows.csv" {
		t.Errorf("search: %v", got)
	}
	if got := names("?limit=1"); len(got) != 1 {
		t.Errorf("limit: %v", got)
	}
	if status, _ := call(t, srv, "GET", "/api/v1/chats/"+c.Id+"/artifacts?origin=nope", "secret", ""); status != 400 {
		t.Errorf("bad origin: %d", status)
	}
	if status, _ := call(t, srv, "GET", "/api/v1/chats/missing/artifacts", "secret", ""); status != 404 {
		t.Errorf("missing chat: %d", status)
	}
}

func TestTheLeadSeesWhatEachMachineCanBuild(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	h.nodes["laptop"] = &v1.NodeStatus{Node: "laptop", Os: "windows", Online: true, Capabilities: []string{"android-sdk", "flutter"}}
	h.nodes["minipc"] = &v1.NodeStatus{Node: "minipc", Os: "linux", Online: true}
	p := h.leadPrompt("c1")
	h.mu.Unlock()
	if !strings.Contains(p, "laptop (windows) with android-sdk, flutter") || !strings.Contains(p, "minipc (linux).") {
		t.Errorf("prompt: %s", p)
	}
	if !strings.Contains(p, ".tether/out/") {
		t.Errorf("the prompt should say where files go: %s", p)
	}
}
