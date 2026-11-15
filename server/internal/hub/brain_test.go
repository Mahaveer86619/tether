package hub

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestTheBrainIsReachedThroughTheHubWithItsToken(t *testing.T) {
	var got string
	brain := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == "GET" && r.URL.Path == "/healthz":
			_, _ = w.Write([]byte("ok\n"))
		case r.Method == "POST":
			b, _ := io.ReadAll(r.Body)
			got = string(b)
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write([]byte(`{"jsonrpc":"2.0","id":1,"result":{}}`))
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
		}
	}))
	defer brain.Close()

	h, srv := newTestHubWith(t)
	if code, _ := call(t, srv, "POST", "/brain/mcp", "secret", `{}`); code != http.StatusNotFound {
		t.Fatalf("a hub with no brain: %d", code)
	}
	if code, _ := call(t, srv, "GET", "/brain/healthz", "secret", ""); code != http.StatusNotFound {
		t.Fatalf("health with no brain: %d", code)
	}

	h.cfg.BrainURL = brain.URL
	if code, _ := call(t, srv, "POST", "/brain/mcp", "", `{}`); code != http.StatusUnauthorized {
		t.Fatalf("no token: %d", code)
	}
	if code, _ := call(t, srv, "GET", "/brain/healthz", "", ""); code != http.StatusUnauthorized {
		t.Fatalf("health with no token: %d", code)
	}
	if code, _ := call(t, srv, "GET", "/brain/healthz", "secret", ""); code != http.StatusOK {
		t.Fatalf("health: %d", code)
	}
	code, body := call(t, srv, "POST", "/brain/mcp", "secret", `{"jsonrpc":"2.0","id":1,"method":"ping"}`)
	if code != http.StatusOK || body != `{"jsonrpc":"2.0","id":1,"result":{}}` {
		t.Fatalf("forwarded: %d %s", code, body)
	}
	if got != `{"jsonrpc":"2.0","id":1,"method":"ping"}` {
		t.Fatalf("the brain got %q", got)
	}

	brain.Close()
	if code, _ := call(t, srv, "POST", "/brain/mcp", "secret", `{}`); code != http.StatusBadGateway {
		t.Fatalf("a brain that is down: %d", code)
	}
	if code, _ := call(t, srv, "GET", "/brain/healthz", "secret", ""); code != http.StatusBadGateway {
		t.Fatalf("health of a brain that is down: %d", code)
	}
}
