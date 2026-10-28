package hub

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func upload(t *testing.T, url, name, body string, headers map[string]string) *v1.Artifact {
	t.Helper()
	req, _ := http.NewRequest("POST", url+"/api/v1/artifacts", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer secret")
	req.Header.Set("X-Name", name)
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	a := &v1.Artifact{}
	if res.StatusCode != 200 || protojson.Unmarshal(b, a) != nil {
		t.Fatalf("upload: %d %s", res.StatusCode, b)
	}
	return a
}

func get(t *testing.T, url, token string) (int, string) {
	t.Helper()
	req, _ := http.NewRequest("GET", url, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return res.StatusCode, string(b)
}

func TestArtifactStore(t *testing.T) {
	h, srv := newTestHubWith(t)
	a := upload(t, srv.URL, "shot.png", "PNGDATA", map[string]string{"X-Session": "s1", "X-Origin": "read", "X-Tool-Use-Id": "toolu_1"})
	if a.Mime != "image/png" || a.Size != 7 || a.ToolUseId != "toolu_1" || a.Session != "s1" {
		t.Fatalf("artifact: %v", a)
	}
	// The same content again is a second artifact sharing one stored file.
	b := upload(t, srv.URL, "copy.png", "PNGDATA", nil)
	if b.Sha256 != a.Sha256 || b.Id == a.Id {
		t.Fatalf("dedupe: %v %v", a, b)
	}

	_, body := call(t, srv, "GET", "/api/v1/artifacts?session=s1", "secret", "")
	list := &v1.ArtifactList{}
	if err := protojson.Unmarshal([]byte(body), list); err != nil || len(list.Artifacts) != 1 {
		t.Fatalf("list: %s", body)
	}

	content := srv.URL + "/api/v1/artifacts/" + a.Id + "/content"
	if status, got := get(t, content, "secret"); status != 200 || got != "PNGDATA" {
		t.Fatalf("content: %d %q", status, got)
	}
	if status, _ := get(t, content, ""); status != 401 {
		t.Fatalf("without a token or a link: %d", status)
	}
	_, body = call(t, srv, "POST", "/api/v1/artifacts/"+a.Id+"/link?ttl=60", "secret", "")
	link := &v1.ArtifactLink{}
	if err := protojson.Unmarshal([]byte(body), link); err != nil || link.Url == "" {
		t.Fatalf("link: %s", body)
	}
	if status, got := get(t, srv.URL+link.Url, ""); status != 200 || got != "PNGDATA" {
		t.Fatalf("signed link: %d %q", status, got)
	}
	if status, _ := get(t, srv.URL+strings.Replace(link.Url, "sig=", "sig=0", 1), ""); status != 403 {
		t.Fatalf("a forged link must fail, got %d", status)
	}

	call(t, srv, "DELETE", "/api/v1/artifacts/"+a.Id, "secret", "")
	if _, err := os.Stat(h.blobPath(a.Sha256)); err != nil {
		t.Fatal("content still used by the copy was deleted")
	}
	call(t, srv, "DELETE", "/api/v1/artifacts/"+b.Id, "secret", "")
	if _, err := os.Stat(h.blobPath(a.Sha256)); !os.IsNotExist(err) {
		t.Fatal("unused content should be deleted")
	}
}

func TestLongMessagesTravelAsAFile(t *testing.T) {
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

	long := "START " + strings.Repeat("a long pasted paragraph. ", 100) + "END"
	body, _ := json.Marshal(map[string]string{"text": long})
	if status, out := call(t, srv, "POST", "/api/v1/sessions/s1/messages", "secret", string(body)); status != 200 {
		t.Fatalf("send: %d %s", status, out)
	}
	var send *v1.AgentCommand_SendInput
	for send == nil {
		f, err := agent.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		send = f.GetAgentCommand().GetSend()
	}
	if len(send.Text) > 200 || len(send.Attachments) != 1 || !strings.HasPrefix(send.Attachments[0].Name, "message-") {
		t.Fatalf("the agent should get a short note and one file, got %q with %v", send.Text, send.Attachments)
	}
	if status, got := get(t, srv.URL+"/api/v1/artifacts/"+send.Attachments[0].Id+"/content", "secret"); status != 200 || got != long {
		t.Fatalf("the file should hold the whole message: %d, %d chars", status, len(got))
	}
}
