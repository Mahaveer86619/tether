package hub

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/gitsync"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

// fakeNode is an agent that does what the real one does for a SyncProject,
// with the folders it was given, and ignores everything else.
func fakeNode(t *testing.T, h *Hub, url, name string, pullInto string) {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	conn, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(url, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close(nil) })
	_ = conn.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_AgentHello{AgentHello: &v1.AgentHello{Token: "secret", Status: &v1.NodeStatus{Node: name}}}})
	for i := 0; i < 100 && !h.agentOnline(name); i++ {
		time.Sleep(10 * time.Millisecond)
	}
	go func() {
		for {
			f, err := conn.Read(ctx)
			if err != nil {
				return
			}
			c := f.GetAgentCommand().GetSyncProject()
			if c == nil {
				continue
			}
			res := &v1.SyncResult{Id: c.Id, Chat: c.Chat, Direction: c.Direction, Cwd: c.Cwd, Ok: true}
			remote := gitsync.Remote{URL: url + "/git/" + c.Repo + ".git", Token: "secret"}
			var err2 error
			switch c.Direction {
			case "push":
				if err2 = gitsync.Exclude(c.Cwd, c.Exclude...); err2 == nil {
					_, err2 = gitsync.Snapshot(c.Cwd, c.Branch, "test")
				}
				if err2 == nil {
					err2 = gitsync.Push(c.Cwd, remote, c.Branch)
				}
			case "pull":
				if res.Cwd == "" {
					res.Cwd = pullInto
				}
				if err2 = gitsync.Exclude(res.Cwd, c.Exclude...); err2 == nil {
					err2 = gitsync.Pull(res.Cwd, remote, c.Branch)
				}
			}
			if err2 != nil {
				res.Ok, res.Error = false, err2.Error()
			}
			_ = conn.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_SyncResult{SyncResult: res}})
		}
	}()
}

func waitUntil(t *testing.T, what string, ok func() bool) {
	t.Helper()
	for i := 0; i < 300; i++ {
		if ok() {
			return
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Fatal("timed out waiting for " + what)
}

func TestMakingAChatRemoteMovesItsProjectToAnotherDeviceAndKeepsBothInStep(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git is not installed")
	}
	old := isProject
	isProject = func(string) bool { return true }
	t.Cleanup(func() { isProject = old })

	h, srv := newTestHubWith(t)
	laptopDir, miniDir := t.TempDir(), t.TempDir()
	fakeNode(t, h, srv.URL, "laptop", "")
	fakeNode(t, h, srv.URL, "minipc", miniDir)

	if err := os.WriteFile(filepath.Join(laptopDir, "main.go"), []byte("package main"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(laptopDir, ".env"), []byte("KEY=secret"), 0o644); err != nil {
		t.Fatal(err)
	}
	c := postChat(t, srv, "/api/v1/chats", `{"prompt":"work on it","target":{"node":"laptop","cwd":`+jsonString(laptopDir)+`}}`)

	if code, _ := call(t, srv, "POST", "/api/v1/chats/"+c.Id+"/remote", "secret", `{"on":true,"node":"laptop"}`); code != 400 {
		t.Fatalf("making it remote on the device it is on: %d", code)
	}
	if code, body := call(t, srv, "POST", "/api/v1/chats/"+c.Id+"/remote", "secret", `{"on":true,"node":"minipc"}`); code != 202 {
		t.Fatalf("make remote: %d %s", code, body)
	}

	waitUntil(t, "the chat to move to minipc", func() bool {
		h.mu.Lock()
		defer h.mu.Unlock()
		s := h.sessions[h.chats[c.Id].ActiveSession]
		rem, _, _ := h.store.ChatRemote(c.Id)
		return s != nil && s.Node == "minipc" && rem.State == remoteSynced
	})
	if got, _ := os.ReadFile(filepath.Join(miniDir, "main.go")); string(got) != "package main" {
		t.Fatalf("the project did not reach minipc: %q", got)
	}
	if _, err := os.Stat(filepath.Join(miniDir, ".env")); err == nil {
		t.Fatal("a secret was synced")
	}
	h.mu.Lock()
	rem, _, _ := h.store.ChatRemote(c.Id)
	h.mu.Unlock()
	if rem.SourceNode != "minipc" || rem.MirrorNode != "laptop" || rem.MirrorCwd != laptopDir {
		t.Fatalf("minipc should write and laptop mirror: %+v", rem)
	}

	// minipc works, a turn ends, and laptop follows.
	if err := os.WriteFile(filepath.Join(miniDir, "main.go"), []byte("package main // edited on minipc"), 0o644); err != nil {
		t.Fatal(err)
	}
	h.mu.Lock()
	h.noteTurnEnded(h.chats[c.Id].ActiveSession)
	h.mu.Unlock()
	waitUntil(t, "laptop to get the edit", func() bool {
		got, _ := os.ReadFile(filepath.Join(laptopDir, "main.go"))
		return string(got) == "package main // edited on minipc"
	})
	if got, _ := os.ReadFile(filepath.Join(laptopDir, ".env")); string(got) != "KEY=secret" {
		t.Fatal("laptop's own secret was touched")
	}

	if code, _ := call(t, srv, "POST", "/api/v1/chats/"+c.Id+"/remote", "secret", `{"on":false}`); code != 202 {
		t.Fatalf("turn off: %d", code)
	}
	if code, body := call(t, srv, "GET", "/api/v1/chats/"+c.Id+"/remote", "secret", ""); code != 200 || !strings.Contains(body, `"on":false`) {
		t.Fatalf("status after: %d %s", code, body)
	}
}

func jsonString(s string) string {
	b := strings.ReplaceAll(s, `\`, `\\`)
	return `"` + b + `"`
}
