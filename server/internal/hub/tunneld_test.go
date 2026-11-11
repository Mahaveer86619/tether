package hub

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

type fakeTunneld struct {
	mu      sync.Mutex
	tunnels map[string]map[string]any
	url     string
	auth    string
}

func (f *fakeTunneld) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.auth = r.Header.Get("Authorization")
	switch {
	case r.Method == "POST" && r.URL.Path == "/api/tunnels":
		var in map[string]any
		b, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(b, &in)
		id := in["name"].(string)
		if _, ok := f.tunnels[id]; ok {
			w.WriteHeader(http.StatusConflict)
			return
		}
		f.tunnels[id] = map[string]any{"target": "http://host.docker.internal:" + itoa(in["port"]), "enabled": true}
		w.WriteHeader(http.StatusCreated)
	case r.Method == "GET" && r.URL.Path == "/api/tunnels/tether-notify":
		_ = json.NewEncoder(w).Encode(f.tunnels["tether-notify"])
	case r.Method == "PATCH" && r.URL.Path == "/api/tunnels/tether-notify":
		var in map[string]any
		b, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(b, &in)
		f.tunnels["tether-notify"] = map[string]any{"target": "http://host.docker.internal:" + itoa(in["port"]), "enabled": true}
	case r.Method == "GET" && r.URL.Path == "/api/tunnels/tether-notify/url":
		if f.url == "" {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte(f.url + "\n"))
	default:
		w.WriteHeader(http.StatusNotFound)
	}
}

func itoa(v any) string { b, _ := json.Marshal(v); return string(b) }

func TestTunneldRegistersTheListenerAndPublishesItsAddress(t *testing.T) {
	f := &fakeTunneld{tunnels: map[string]map[string]any{"tether-notify": {"target": "http://host.docker.internal:1111", "enabled": false}}, url: "https://one.trycloudflare.com"}
	srv := httptest.NewServer(f)
	defer srv.Close()
	h, _ := newTestHubWith(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go h.runTunneld(ctx, TunneldConfig{URL: srv.URL, Token: "sekret", Name: "tether-notify"}, 7421)

	waitFor(t, func() bool { h.mu.Lock(); defer h.mu.Unlock(); return h.notifyURL == "https://one.trycloudflare.com" })
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.tunnels["tether-notify"]["target"] != "http://host.docker.internal:7421" || f.tunnels["tether-notify"]["enabled"] != true {
		t.Fatalf("an existing tunnel is retargeted and enabled: %v", f.tunnels["tether-notify"])
	}
	if f.auth != "Bearer sekret" {
		t.Fatalf("token not sent: %q", f.auth)
	}
}

func TestTunneldWithoutAnAddressYetPublishesNothing(t *testing.T) {
	f := &fakeTunneld{tunnels: map[string]map[string]any{}}
	srv := httptest.NewServer(f)
	defer srv.Close()
	h, _ := newTestHubWith(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go h.runTunneld(ctx, TunneldConfig{URL: srv.URL, Name: "tether-notify"}, 7421)
	waitFor(t, func() bool { f.mu.Lock(); defer f.mu.Unlock(); return len(f.tunnels) == 1 })
	f.mu.Lock()
	f.url = "https://two.trycloudflare.com"
	f.mu.Unlock()
	waitFor(t, func() bool { h.mu.Lock(); defer h.mu.Unlock(); return h.notifyURL == "https://two.trycloudflare.com" })
}

func waitFor(t *testing.T, ok func() bool) {
	t.Helper()
	for i := 0; i < 100; i++ {
		if ok() {
			return
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Fatal("timed out")
}
