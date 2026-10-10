package hub

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/store"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func newTestHub(t *testing.T) *httptest.Server {
	t.Helper()
	st, err := store.Open(filepath.Join(t.TempDir(), "hub.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { st.Close() })
	h, err := New(Config{Token: "secret", Version: "test", Log: slog.New(slog.NewTextHandler(io.Discard, nil))}, st)
	if err != nil {
		t.Fatal(err)
	}
	h.putSession(&v1.SessionInfo{Id: "s1", Node: "laptop", Title: "existing", State: v1.SessionState_SESSION_STATE_IDLE})
	if err := st.SetTranscriptOffset("s1", 0); err != nil {
		t.Fatal(err)
	}
	if _, _, err := st.PutItems("s1", []*v1.TimelineItem{
		{ItemId: "a", Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "hi"}}},
		{ItemId: "b", Kind: &v1.TimelineItem_Notice{Notice: &v1.Notice{Text: "done"}}},
	}); err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(h.Handler())
	t.Cleanup(srv.Close)
	return srv
}

func call(t *testing.T, srv *httptest.Server, method, path, token, body string) (int, string) {
	t.Helper()
	req, _ := http.NewRequest(method, srv.URL+path, strings.NewReader(body))
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

func TestAPIErrors(t *testing.T) {
	srv := newTestHub(t)
	cases := []struct {
		name, method, path, token, body string
		status                          int
		code                            string
	}{
		{"no token", "GET", "/api/v1/state", "", "", 401, "unauthorized"},
		{"wrong token", "GET", "/api/v1/state", "nope", "", 401, "unauthorized"},
		{"unknown session", "GET", "/api/v1/sessions/zzz/timeline", "secret", "", 404, "not_found"},
		{"bad after", "GET", "/api/v1/sessions/s1/timeline?after=x", "secret", "", 400, "invalid"},
		{"malformed json", "POST", "/api/v1/sessions", "secret", "{", 400, "invalid"},
		{"send to offline node", "POST", "/api/v1/sessions/s1/messages", "secret", `{"text":" "}`, 503, "node_offline"},
		{"offline node", "POST", "/api/v1/sessions", "secret", `{"node":"laptop","prompt":"x"}`, 503, "node_offline"},
		{"missing decision", "POST", "/api/v1/approvals/a1", "secret", `{}`, 400, "invalid"},
		{"resolved approval", "POST", "/api/v1/approvals/a1", "secret", `{"decision":"DECISION_ALLOW"}`, 404, "not_found"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			status, body := call(t, srv, tc.method, tc.path, tc.token, tc.body)
			if status != tc.status {
				t.Fatalf("status %d, want %d: %s", status, tc.status, body)
			}
			var e v1.Error
			if err := protojson.Unmarshal([]byte(body), &e); err != nil || e.Code != tc.code {
				t.Fatalf("error body %q, want code %q", body, tc.code)
			}
		})
	}
}

func TestAPIStateAndTimeline(t *testing.T) {
	srv := newTestHub(t)

	status, body := call(t, srv, "GET", "/api/v1/state", "secret", "")
	var w v1.Welcome
	if status != 200 || protojson.Unmarshal([]byte(body), &w) != nil || len(w.Sessions) != 1 {
		t.Fatalf("state: %d %s", status, body)
	}

	status, body = call(t, srv, "GET", "/api/v1/sessions/s1/timeline", "secret", "")
	var page v1.TimelinePage
	if status != 200 || protojson.Unmarshal([]byte(body), &page) != nil {
		t.Fatalf("timeline: %d %s", status, body)
	}
	if len(page.Items) != 2 || page.Items[0].ItemId != "a" || page.Seq != 2 {
		t.Fatalf("unexpected page: %v", &page)
	}

	_, body = call(t, srv, "GET", "/api/v1/sessions/s1/timeline?after=2", "secret", "")
	page.Reset()
	if protojson.Unmarshal([]byte(body), &page) != nil || len(page.Items) != 0 || page.Seq != 2 {
		t.Fatalf("after=2 should be empty with seq 2: %s", body)
	}

	_, body = call(t, srv, "GET", "/api/v1/sessions/s1/timeline?after=99", "secret", "")
	page.Reset()
	if protojson.Unmarshal([]byte(body), &page) != nil || page.Seq != 2 {
		t.Fatalf("a cache ahead of the hub must see the real latest seq: %s", body)
	}
}

func TestWebSocketRejectsBadToken(t *testing.T) {
	srv := newTestHub(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http")+"/ws")
	if err != nil {
		t.Fatal(err)
	}
	if err := conn.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_ClientHello{ClientHello: &v1.ClientHello{Token: "wrong"}}}); err != nil {
		t.Fatal(err)
	}
	f, err := conn.Read(ctx)
	if err != nil {
		t.Fatalf("expected an error frame before the close, got %v", err)
	}
	if f.GetError().GetCode() != "unauthorized" {
		t.Fatalf("want unauthorized error frame, got %v", f)
	}
}
