package hub

import (
	"os"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func TestAnAppComingToTheForegroundStartsABackup(t *testing.T) {
	h, srv := newTestHubWith(t)
	agent, ctx := dialAgent(t, h, srv.URL)
	h.mu.Lock()
	h.sessions["s1"].BackedUpBytes = 1234
	h.lastBackup = time.Now().Add(-time.Hour)
	h.mu.Unlock()

	app, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	defer app.Close(nil)
	_ = app.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_ClientHello{ClientHello: &v1.ClientHello{Token: "secret", ClientName: "phone"}}})
	if _, err := app.Read(ctx); err != nil {
		t.Fatal(err)
	}
	_ = app.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_ClientPresence{ClientPresence: &v1.ClientPresence{Active: true}}})

	var b *v1.AgentCommand_BackupSessions
	for b == nil {
		f, err := agent.Read(ctx)
		if err != nil {
			t.Fatal("the node should be asked for a backup: ", err)
		}
		b = f.GetAgentCommand().GetBackup()
	}
	if b.Stored["s1"] != 1234 {
		t.Fatalf("the node should be told what the hub has: %v", b.Stored)
	}

	// In the background, the loop leaves things alone.
	_ = app.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_ClientPresence{ClientPresence: &v1.ClientPresence{Active: false}}})
	for i := 0; i < 50; i++ {
		h.mu.Lock()
		active := h.appActive()
		h.mu.Unlock()
		if !active {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("an app in the background should count as inactive")
}

func TestBackupsKeepOneQuietCopyPerFile(t *testing.T) {
	h, srv := newTestHubWith(t)
	backup := func(path, body string) *v1.Artifact {
		return upload(t, srv.URL, "f.jsonl", body, map[string]string{"X-Session": "s1", "X-Origin": "backup", "X-Path": path})
	}
	first := backup("transcript", "line one\n")
	again := backup("transcript", "line one\n")
	if again.Id != first.Id {
		t.Fatal("unchanged content must not add a row")
	}
	changed := backup("transcript", "line one\nline two\n")
	if changed.Id == first.Id {
		t.Fatal("changed content replaces the copy")
	}
	if _, err := os.Stat(h.blobPath(first.Sha256)); !os.IsNotExist(err) {
		t.Fatal("the replaced copy's content should be gone")
	}
	backup("subagents/agent-1.jsonl", "sub\n")

	h.mu.Lock()
	s := h.sessions["s1"]
	latest := h.latestCopy("s1")
	h.mu.Unlock()
	if s.BackedUpBytes != changed.Size || s.BackedUpMs == 0 {
		t.Fatalf("session backup state: %d bytes at %d", s.BackedUpBytes, s.BackedUpMs)
	}
	if latest == nil || latest.Id != changed.Id {
		t.Fatalf("continuing on the hub should find the backup: %v", latest)
	}

	_, body := call(t, srv, "GET", "/api/v1/artifacts?session=s1", "secret", "")
	list := &v1.ArtifactList{}
	_ = protojson.Unmarshal([]byte(body), list)
	if len(list.Artifacts) != 0 {
		t.Fatalf("backups are hidden from the files list: %s", body)
	}
	_, body = call(t, srv, "GET", "/api/v1/artifacts?session=s1&origin=backup", "secret", "")
	_ = protojson.Unmarshal([]byte(body), list)
	if len(list.Artifacts) != 2 {
		t.Fatalf("asked for, they're listed: %s", body)
	}
}
