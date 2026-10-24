package hub

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func sumOf(b []byte) string {
	s := sha256.Sum256(b)
	return hex.EncodeToString(s[:])
}

func writeRelease(t *testing.T, dir, version string, files map[string][]byte) {
	t.Helper()
	rel := filepath.Join(dir, version)
	if err := os.MkdirAll(rel, 0o755); err != nil {
		t.Fatal(err)
	}
	m := &v1.UpdateManifest{Version: version, Notes: "Fixes", MinSupported: "0.15.0", Platforms: map[string]*v1.UpdateAsset{}}
	for key, b := range files {
		name := "tether-" + key
		if err := os.WriteFile(filepath.Join(rel, name), b, 0o644); err != nil {
			t.Fatal(err)
		}
		m.Platforms[key] = &v1.UpdateAsset{Name: name, Url: "https://github.com/x/releases/download/v" + version + "/" + name, Sha256: sumOf(b), Size: int64(len(b))}
	}
	m.Platforms["hub-linux-amd64"] = &v1.UpdateAsset{Name: "tether-hub", Url: "https://github.com/x/hub", Sha256: "ab"}
	b, _ := protojson.MarshalOptions{UseProtoNames: true}.Marshal(m)
	if err := os.WriteFile(filepath.Join(rel, "latest.json"), b, 0o644); err != nil {
		t.Fatal(err)
	}
}

func dialAgentAs(t *testing.T, h *Hub, url string, st *v1.NodeStatus) (*wire.Conn, context.Context) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	t.Cleanup(cancel)
	agent, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(url, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { agent.Close(nil) })
	_ = agent.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_AgentHello{AgentHello: &v1.AgentHello{Token: "secret", Status: st}}})
	for i := 0; i < 50 && !h.agentOnline(st.Node); i++ {
		time.Sleep(10 * time.Millisecond)
	}
	return agent, ctx
}

func TestAReleaseInTheUpdatesFolderIsServedAndAgentsAreUpdated(t *testing.T) {
	h, srv := newTestHubWith(t)
	h.cfg.AutoUpdateAgents = true
	writeRelease(t, h.updatesDir(), "0.18.0", map[string][]byte{"agent-linux-amd64": []byte("agent bytes"), "android": []byte("apk bytes")})
	writeRelease(t, h.updatesDir(), "0.17.5", map[string][]byte{"android": []byte("older")})
	h.mu.Lock()
	h.loadLocalUpdate()
	h.mu.Unlock()

	status, body := call(t, srv, "GET", "/api/v1/updates/latest", "secret", "")
	m := &v1.UpdateManifest{}
	if status != 200 || protojson.Unmarshal([]byte(body), m) != nil || m.Version != "0.18.0" || m.MinSupported != "0.15.0" {
		t.Fatalf("latest: %d %s", status, body)
	}
	apk := m.Platforms["android"]
	if apk.Url != "/api/v1/updates/files/0.18.0/tether-android" || !strings.HasPrefix(m.Platforms["hub-linux-amd64"].Url, "https://") {
		t.Fatalf("urls: %v", m.Platforms)
	}
	if status, got := call(t, srv, "GET", apk.Url, "secret", ""); status != 200 || got != "apk bytes" {
		t.Fatalf("file: %d %q", status, got)
	}
	if status, _ := call(t, srv, "GET", apk.Url, "", ""); status != 401 {
		t.Fatalf("a file without a token: %d", status)
	}
	if status, _ := call(t, srv, "GET", "/api/v1/updates/files/0.18.0/..%2Fsecrets.key", "secret", ""); status == 200 {
		t.Fatal("served a path outside the release")
	}
	if status, _ := call(t, srv, "GET", "/api/v1/updates/files/0.18.0/..", "secret", ""); status == 200 {
		t.Fatal("served the updates folder")
	}
	_, body = call(t, srv, "GET", "/api/v1/state", "secret", "")
	if !strings.Contains(body, `"0.18.0"`) {
		t.Fatalf("welcome has no update: %s", body)
	}

	// An idle agent that can update itself is asked to; a busy one isn't.
	busy, _ := dialAgentAs(t, h, srv.URL, &v1.NodeStatus{Node: "busy", Os: "linux", AgentVersion: "0.17.0", RunningSessions: 1})
	agent, ctx := dialAgentAs(t, h, srv.URL, &v1.NodeStatus{Node: "laptop", Os: "linux", AgentVersion: "0.17.0"})
	cmd := nextCommand(t, agent, ctx, func(c *v1.AgentCommand) bool { return c.GetSelfUpdate() != nil }).GetSelfUpdate()
	if cmd.Version != "0.18.0" || cmd.Asset.Url != "/api/v1/updates/files/0.18.0/tether-agent-linux-amd64" || cmd.Asset.Sha256 != sumOf([]byte("agent bytes")) {
		t.Fatalf("self update: %v", cmd)
	}
	h.mu.Lock()
	_, askedBusy := h.agentUpdates["busy"]
	h.maybeUpdateAgent("laptop")
	attempts := h.agentUpdates["laptop"].attempts
	h.mu.Unlock()
	if askedBusy {
		t.Fatal("asked a busy agent to update")
	}
	if attempts != 1 {
		t.Fatalf("asked again straight away: %d attempts", attempts)
	}
	_ = busy
}

func TestOldAgentsAreNotAskedToUpdate(t *testing.T) {
	h, srv := newTestHubWith(t)
	h.cfg.AutoUpdateAgents = true
	writeRelease(t, h.updatesDir(), "0.18.0", map[string][]byte{"agent-windows-amd64": []byte("x")})
	h.mu.Lock()
	h.loadLocalUpdate()
	h.mu.Unlock()
	dialAgentAs(t, h, srv.URL, &v1.NodeStatus{Node: "old", Os: "windows", AgentVersion: "0.16.0"})
	dialAgentAs(t, h, srv.URL, &v1.NodeStatus{Node: "dev", Os: "windows", AgentVersion: "dev"})
	h.mu.Lock()
	defer h.mu.Unlock()
	if len(h.agentUpdates) != 0 {
		t.Fatalf("asked: %v", h.agentUpdates)
	}
}

func TestTheFeedBringsNewReleasesAndChecksTheirFiles(t *testing.T) {
	h, _ := newTestHubWith(t)
	apk := []byte("apk from github")
	var manifest []byte
	gh := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/latest.json":
			_, _ = w.Write(manifest)
		case "/tether-0.19.0.apk":
			_, _ = w.Write(apk)
		default:
			http.NotFound(w, r)
		}
	}))
	defer gh.Close()
	h.cfg.UpdateFeed = gh.URL + "/latest.json"
	bad := `{"version":"0.19.0","notes":"n","min_supported":"0.16.0","platforms":{"android":{"name":"tether-0.19.0.apk","url":"` + gh.URL + `/tether-0.19.0.apk","sha256":"` + sumOf([]byte("something else")) + `"}}}`
	manifest = []byte(bad)
	h.pollFeed(context.Background())
	h.mu.Lock()
	known := h.update
	h.mu.Unlock()
	if known != nil {
		t.Fatalf("took a release whose file didn't match: %v", known)
	}

	manifest = []byte(strings.Replace(bad, sumOf([]byte("something else")), sumOf(apk), 1))
	h.pollFeed(context.Background())
	h.mu.Lock()
	served := h.servedManifest()
	h.mu.Unlock()
	if served == nil || served.Version != "0.19.0" || served.Platforms["android"].Url != "/api/v1/updates/files/0.19.0/tether-0.19.0.apk" {
		t.Fatalf("served: %v", served)
	}
	if b, _ := os.ReadFile(filepath.Join(h.updatesDir(), "0.19.0", "latest.json")); !strings.Contains(string(b), "min_supported") {
		t.Fatalf("latest.json kept: %s", b)
	}

	// The same release with the Windows app added is taken too.
	win := []byte("windows zip")
	gh.Config.Handler = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/latest.json":
			_, _ = w.Write(manifest)
		case "/tether-0.19.0.apk":
			_, _ = w.Write(apk)
		case "/tether-windows-0.19.0.zip":
			_, _ = w.Write(win)
		}
	})
	manifest = []byte(strings.Replace(string(manifest), `}}}`, `},"windows":{"name":"tether-windows-0.19.0.zip","url":"`+gh.URL+`/tether-windows-0.19.0.zip","sha256":"`+sumOf(win)+`"}}}`, 1))
	h.pollFeed(context.Background())
	h.mu.Lock()
	served = h.servedManifest()
	h.mu.Unlock()
	if served.Platforms["windows"] == nil || served.Platforms["windows"].Url != "/api/v1/updates/files/0.19.0/tether-windows-0.19.0.zip" {
		t.Fatalf("the Windows app wasn't picked up: %v", served.Platforms)
	}

	// An older feed doesn't replace what's known.
	manifest = []byte(`{"version":"0.18.0","platforms":{}}`)
	h.pollFeed(context.Background())
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.update.Version != "0.19.0" {
		t.Fatalf("went back to %s", h.update.Version)
	}
}

func TestOldReleasesArePruned(t *testing.T) {
	h, _ := newTestHubWith(t)
	for _, v := range []string{"0.9.0", "0.10.0", "0.10.2", "0.11.0"} {
		writeRelease(t, h.updatesDir(), v, map[string][]byte{"android": []byte(v)})
	}
	h.pruneReleases("0.11.0")
	entries, _ := os.ReadDir(h.updatesDir())
	var left []string
	for _, e := range entries {
		left = append(left, e.Name())
	}
	if strings.Join(left, ",") != "0.10.2,0.11.0" {
		t.Fatalf("left %v", left)
	}
}
