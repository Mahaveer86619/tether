package hub

import (
	"encoding/json"
	"strings"
	"testing"
)

func projectsOf(t *testing.T, out string) []project {
	t.Helper()
	var got struct{ Projects []project }
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("%v: %s", err, out)
	}
	return got.Projects
}

func TestAProjectIsMadeFromAFolderAndBringsItsChats(t *testing.T) {
	h, srv := newTestHubWith(t)
	dialAgent(t, h, srv.URL)
	inFolder := postChat(t, srv, "/api/v1/chats", `{"prompt":"fix it","target":{"node":"laptop","cwd":"/src/tether"}}`)
	elsewhere := postChat(t, srv, "/api/v1/chats", `{"prompt":"other","target":{"node":"laptop","cwd":"/src/other"}}`)

	code, out := call(t, srv, "POST", "/api/v1/projects", "secret", `{"folders":[{"node":"laptop","cwd":"/src/tether/"},{"node":"laptop","cwd":"/src/tether"}]}`)
	if code != 200 {
		t.Fatalf("create: %d %s", code, out)
	}
	var p project
	_ = json.Unmarshal([]byte(out), &p)
	if p.ID == "" || p.Name != "tether" || len(p.Folders) != 1 || p.CreatedMs == 0 {
		t.Fatalf("project: %+v", p)
	}
	if len(p.Chats) != 1 || p.Chats[0] != inFolder.Id {
		t.Fatalf("the chat in its folder should join it: %+v", p.Chats)
	}

	_, out = call(t, srv, "GET", "/api/v1/chat-projects", "secret", "")
	if !strings.Contains(out, `"`+inFolder.Id+`":"`+p.ID+`"`) || strings.Contains(out, elsewhere.Id) {
		t.Fatalf("chat-projects: %s", out)
	}

	if code, out := call(t, srv, "POST", "/api/v1/projects/"+p.ID+"/folders", "secret", `{"node":"minipc","cwd":"/home/me/tether"}`); code != 200 || !strings.Contains(out, "minipc") {
		t.Fatalf("add folder: %d %s", code, out)
	}
	if code, out := call(t, srv, "PUT", "/api/v1/projects/"+p.ID, "secret", `{"name":"Tether"}`); code != 200 || !strings.Contains(out, `"name":"Tether"`) || !strings.Contains(out, "minipc") {
		t.Fatalf("rename keeps the folders: %d %s", code, out)
	}
}

func TestAChatJoinsAProjectWhenMadeInItOrMovedLater(t *testing.T) {
	h, srv := newTestHubWith(t)
	dialAgent(t, h, srv.URL)
	_, out := call(t, srv, "POST", "/api/v1/projects", "secret", `{"name":"warehouse-sync"}`)
	var p project
	_ = json.Unmarshal([]byte(out), &p)

	made := postChat(t, srv, "/api/v1/chats?project="+p.ID, `{"prompt":"fix the upload","target":{"node":"laptop","cwd":"/src/wh"}}`)
	oneOff := postChat(t, srv, "/api/v1/chats", `{"prompt":"what is a monad","target":{"node":"laptop","cwd":"/src/x"}}`)
	if code, _ := call(t, srv, "POST", "/api/v1/chats?project=nope", "secret", `{"prompt":"x","target":{"node":"laptop","cwd":"/src/x"}}`); code != 404 {
		t.Fatalf("an unknown project should be refused before a chat is made: %d", code)
	}

	_, out = call(t, srv, "GET", "/api/v1/projects", "secret", "")
	if got := projectsOf(t, out); len(got) != 1 || len(got[0].Chats) != 1 || got[0].Chats[0] != made.Id {
		t.Fatalf("projects: %s", out)
	}

	if code, out := call(t, srv, "PUT", "/api/v1/chats/"+oneOff.Id+"/project", "secret", `{"project":"`+p.ID+`"}`); code != 200 {
		t.Fatalf("attach: %d %s", code, out)
	}
	if code, _ := call(t, srv, "PUT", "/api/v1/chats/"+made.Id+"/project", "secret", `{"project":""}`); code != 200 {
		t.Fatal("detach")
	}
	if code, _ := call(t, srv, "PUT", "/api/v1/chats/"+made.Id+"/project", "secret", `{"project":"nope"}`); code != 404 {
		t.Fatal("an unknown project")
	}
	_, out = call(t, srv, "GET", "/api/v1/projects", "secret", "")
	if got := projectsOf(t, out); len(got[0].Chats) != 1 || got[0].Chats[0] != oneOff.Id {
		t.Fatalf("after moving: %s", out)
	}

	if code, _ := call(t, srv, "DELETE", "/api/v1/chats/"+oneOff.Id, "secret", ""); code != 200 {
		t.Fatal("delete chat")
	}
	h.mu.Lock()
	left := len(h.chatProjects())
	h.mu.Unlock()
	if left != 0 {
		t.Fatalf("a deleted chat keeps no project: %d", left)
	}

	postChat(t, srv, "/api/v1/chats?project="+p.ID, `{"prompt":"again","target":{"node":"laptop","cwd":"/src/wh"}}`)
	if code, _ := call(t, srv, "DELETE", "/api/v1/projects/"+p.ID, "secret", ""); code != 200 {
		t.Fatal("delete project")
	}
	_, out = call(t, srv, "GET", "/api/v1/chat-projects", "secret", "")
	if out != "{\"chats\":{}}\n" {
		t.Fatalf("a deleted project's chats become one-offs: %s", out)
	}
	if code, _ := call(t, srv, "DELETE", "/api/v1/projects/"+p.ID, "secret", ""); code != 404 {
		t.Fatal("deleting twice")
	}
}

func TestBadProjectsAreRefused(t *testing.T) {
	_, srv := newTestHubWith(t)
	for _, bad := range []string{`{}`, `{"name":"  "}`, `{"name":"x","folders":[{"node":"laptop"}]}`, `nope`} {
		if code, _ := call(t, srv, "POST", "/api/v1/projects", "secret", bad); code != 400 {
			t.Fatalf("%s should be refused: %d", bad, code)
		}
	}
	if code, _ := call(t, srv, "GET", "/api/v1/projects", "", ""); code != 401 {
		t.Fatalf("no token: %d", code)
	}
	if _, out := call(t, srv, "GET", "/api/v1/projects", "secret", ""); out != "{\"projects\":[]}\n" {
		t.Fatalf("empty list: %q", out)
	}
}
