package hub

import (
	"encoding/json"
	"testing"
)

func TestHelloNamesTheHubWithoutAToken(t *testing.T) {
	_, srv := newTestHubWith(t)
	status, body := call(t, srv, "GET", "/api/v1/hello", "", "")
	var got struct {
		App     string `json:"app"`
		Version string `json:"version"`
		Trusted bool   `json:"trusted"`
	}
	if status != 200 || json.Unmarshal([]byte(body), &got) != nil || got.App != "tether-hub" {
		t.Fatalf("hello: %d %s", status, body)
	}
	if got.Trusted {
		t.Error("a caller with no token and no tailnet trust is not trusted")
	}
	// Asking is not a failed login: it must not lock the caller out.
	for i := 0; i < 30; i++ {
		if status, _ := call(t, srv, "GET", "/api/v1/hello", "", ""); status != 200 {
			t.Fatalf("hello was refused on try %d: %d", i, status)
		}
	}
	if status, _ := call(t, srv, "GET", "/api/v1/state", "secret", ""); status != 200 {
		t.Errorf("the token should still work: %d", status)
	}
}
