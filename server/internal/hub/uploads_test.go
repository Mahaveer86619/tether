package hub

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"math/rand/v2"
	"net/http"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func randomBytes(n int) []byte {
	b := make([]byte, n)
	r := rand.New(rand.NewPCG(1, 2))
	for i := range b {
		b[i] = byte(r.Uint32())
	}
	return b
}

func shaHex(b []byte) string {
	s := sha256.Sum256(b)
	return hex.EncodeToString(s[:])
}

func request(t *testing.T, method, url string, body io.Reader, headers map[string]string) (*http.Response, []byte) {
	t.Helper()
	req, _ := http.NewRequest(method, url, body)
	req.Header.Set("Authorization", "Bearer secret")
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return res, b
}

func TestDownloadResumesWithRange(t *testing.T) {
	_, srv := newTestHubWith(t)
	data := randomBytes(1 << 20)
	a := upload(t, srv.URL, "data.csv", string(data), nil)
	url := srv.URL + "/api/v1/artifacts/" + a.Id + "/content"
	etag := `"` + a.Sha256 + `"`

	res, body := request(t, "GET", url, nil, nil)
	if res.StatusCode != 200 || res.Header.Get("ETag") != etag || res.Header.Get("Accept-Ranges") != "bytes" || !bytes.Equal(body, data) {
		t.Fatalf("full: %d etag %q ranges %q, %d bytes", res.StatusCode, res.Header.Get("ETag"), res.Header.Get("Accept-Ranges"), len(body))
	}

	res, body = request(t, "GET", url, nil, map[string]string{"Range": "bytes=700000-", "If-Range": etag})
	if res.StatusCode != 206 || !bytes.Equal(body, data[700000:]) {
		t.Fatalf("resume: %d, %d bytes", res.StatusCode, len(body))
	}
	if cr := res.Header.Get("Content-Range"); cr != fmt.Sprintf("bytes 700000-%d/%d", len(data)-1, len(data)) {
		t.Fatalf("Content-Range %q", cr)
	}

	// A different file under the same id would fail If-Range: start over.
	res, body = request(t, "GET", url, nil, map[string]string{"Range": "bytes=700000-", "If-Range": `"other"`})
	if res.StatusCode != 200 || len(body) != len(data) {
		t.Fatalf("stale If-Range should send the whole file: %d, %d bytes", res.StatusCode, len(body))
	}

	res, _ = request(t, "GET", url, nil, map[string]string{"Range": fmt.Sprintf("bytes=%d-", len(data))})
	if res.StatusCode != http.StatusRequestedRangeNotSatisfiable {
		t.Fatalf("past the end: %d", res.StatusCode)
	}

	res, _ = request(t, "GET", url+"?download=1", nil, nil)
	if !strings.HasPrefix(res.Header.Get("Content-Disposition"), "attachment") {
		t.Fatalf("download=1: %q", res.Header.Get("Content-Disposition"))
	}
}

func TestUploadHasNoSizeCapAndChecksSha(t *testing.T) {
	h, srv := newTestHubWith(t)
	// Over the old 50 MB cap.
	data := randomBytes(60 << 20)
	res, body := request(t, "POST", srv.URL+"/api/v1/artifacts", bytes.NewReader(data), map[string]string{"X-Name": "big.bin", "X-Sha256": shaHex(data)})
	a := &v1.Artifact{}
	if res.StatusCode != 200 || protojson.Unmarshal(body, a) != nil || a.Size != int64(len(data)) || a.Sha256 != shaHex(data) {
		t.Fatalf("big upload: %d %s", res.StatusCode, body)
	}

	res, body = request(t, "POST", srv.URL+"/api/v1/artifacts", strings.NewReader("not it"), map[string]string{"X-Name": "x.txt", "X-Sha256": shaHex(data)})
	if res.StatusCode != http.StatusUnprocessableEntity {
		t.Fatalf("wrong sha256 should be refused: %d %s", res.StatusCode, body)
	}
	if _, err := os.Stat(h.blobPath(shaHex([]byte("not it")))); !os.IsNotExist(err) {
		t.Fatal("content that failed its check was kept")
	}
}

// failingReader gives n bytes and then breaks, like a dropped connection.
type failingReader struct {
	r io.Reader
	n int
}

func (f *failingReader) Read(p []byte) (int, error) {
	if f.n <= 0 {
		return 0, errors.New("connection lost")
	}
	if len(p) > f.n {
		p = p[:f.n]
	}
	n, err := f.r.Read(p)
	f.n -= n
	return n, err
}

func TestResumableUpload(t *testing.T) {
	h, srv := newTestHubWith(t)
	h.mu.Lock()
	h.sessions["s1"].Cwd = "/work/project"
	h.mu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
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

	data := randomBytes(3<<20 + 123)
	res, body := request(t, "POST", srv.URL+"/api/v1/uploads", nil, map[string]string{
		"X-Name": "data.csv", "X-Size": strconv.Itoa(len(data)), "X-Sha256": shaHex(data),
		"X-Session": "s1", "X-Origin": "attachment", "X-Note": "q3%20numbers", "X-Deliver": "1",
	})
	u := &v1.Upload{}
	if res.StatusCode != 200 || protojson.Unmarshal(body, u) != nil || u.Id == "" || u.Size != int64(len(data)) {
		t.Fatalf("start: %d %s", res.StatusCode, body)
	}
	patch := func(off int64, r io.Reader) (*http.Response, []byte) {
		req, _ := http.NewRequest("PATCH", srv.URL+"/api/v1/uploads/"+u.Id, r)
		req.Header.Set("Authorization", "Bearer secret")
		req.Header.Set("Upload-Offset", strconv.FormatInt(off, 10))
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			return nil, nil
		}
		defer res.Body.Close()
		b, _ := io.ReadAll(res.Body)
		return res, b
	}
	offset := func() int64 {
		_, body := request(t, "GET", srv.URL+"/api/v1/uploads/"+u.Id, nil, nil)
		got := &v1.Upload{}
		if err := protojson.Unmarshal(body, got); err != nil {
			t.Fatalf("offset: %s", body)
		}
		return got.Offset
	}

	if res, body := patch(0, bytes.NewReader(data[:1<<20])); res == nil || res.StatusCode != 200 {
		t.Fatalf("first chunk: %v %s", res, body)
	}
	if res, _ := patch(5, bytes.NewReader(data[5:10])); res == nil || res.StatusCode != http.StatusConflict || res.Header.Get("Upload-Offset") != strconv.Itoa(1<<20) {
		t.Fatalf("a wrong offset should be refused with the right one: %v", res)
	}

	// The connection drops partway through a chunk: what arrived is kept.
	_, _ = patch(1<<20, &failingReader{r: bytes.NewReader(data[1<<20 : 2<<20]), n: 300_000})
	// Like a client: ask where the upload is and go on from there. The hub
	// may still be writing what arrived, which a 409 reports.
	done := &v1.Upload{}
	for i := 0; ; i++ {
		at := offset()
		if at < 1<<20 || at > 1<<20+300_000 {
			t.Fatalf("after a dropped chunk the upload is at %d", at)
		}
		res, body = patch(at, bytes.NewReader(data[at:]))
		if res != nil && res.StatusCode == http.StatusConflict && i < 50 {
			time.Sleep(20 * time.Millisecond)
			continue
		}
		if res == nil || res.StatusCode != 200 || protojson.Unmarshal(body, done) != nil || done.Artifact == nil {
			t.Fatalf("last chunk: %v %s", res, body)
		}
		break
	}
	a := done.Artifact
	if a.Sha256 != shaHex(data) || a.Size != int64(len(data)) || a.Session != "s1" || a.Origin != "attachment" || a.Note != "q3 numbers" {
		t.Fatalf("artifact: %v", a)
	}
	// An answer lost on the way back can be asked for again.
	_, body = request(t, "GET", srv.URL+"/api/v1/uploads/"+u.Id, nil, nil)
	again := &v1.Upload{}
	if err := protojson.Unmarshal(body, again); err != nil || again.Artifact.GetId() != a.Id || again.Offset != again.Size {
		t.Fatalf("a finished upload should report its artifact: %s", body)
	}
	if _, err := os.Stat(h.uploadPath(u.Id)); !os.IsNotExist(err) {
		t.Fatal("the partial file should have moved into the store")
	}
	if _, got := get(t, srv.URL+"/api/v1/artifacts/"+a.Id+"/content", "secret"); got != string(data) {
		t.Fatal("stored content differs")
	}

	var fetch *v1.AgentCommand_FetchAttachment
	for fetch == nil {
		f, err := agent.Read(ctx)
		if err != nil {
			t.Fatal("the session's node should be told to fetch the file: ", err)
		}
		fetch = f.GetAgentCommand().GetFetch()
	}
	if fetch.Session != "s1" || fetch.Cwd != "/work/project" || fetch.Artifact.GetId() != a.Id {
		t.Fatalf("fetch: %v", fetch)
	}
}

func TestResumableUploadChecksSha(t *testing.T) {
	_, srv := newTestHubWith(t)
	data := []byte("hello world")
	_, body := request(t, "POST", srv.URL+"/api/v1/uploads", nil, map[string]string{"X-Name": "a.txt", "X-Size": "11", "X-Sha256": shaHex([]byte("other"))})
	u := &v1.Upload{}
	if err := protojson.Unmarshal(body, u); err != nil {
		t.Fatal(string(body))
	}
	res, _ := request(t, "PATCH", srv.URL+"/api/v1/uploads/"+u.Id, bytes.NewReader(data), map[string]string{"Upload-Offset": "0"})
	if res.StatusCode != http.StatusUnprocessableEntity {
		t.Fatalf("mismatch: %d", res.StatusCode)
	}
	if res, _ := request(t, "GET", srv.URL+"/api/v1/uploads/"+u.Id, nil, nil); res.StatusCode != 404 {
		t.Fatalf("a failed upload should be dropped, got %d", res.StatusCode)
	}
}

func TestStaleUploadsAreDropped(t *testing.T) {
	h, srv := newTestHubWith(t)
	_, body := request(t, "POST", srv.URL+"/api/v1/uploads", nil, map[string]string{"X-Name": "a.txt", "X-Size": "5"})
	u := &v1.Upload{}
	if err := protojson.Unmarshal(body, u); err != nil {
		t.Fatal(string(body))
	}
	h.dropStaleUploads(time.Now())
	if _, err := os.Stat(h.uploadPath(u.Id)); err != nil {
		t.Fatal("a fresh upload was dropped")
	}
	h.dropStaleUploads(time.Now().Add(staleUpload + time.Hour))
	if _, err := os.Stat(h.uploadPath(u.Id)); !os.IsNotExist(err) {
		t.Fatal("a stale upload was kept")
	}
	if _, err := os.Stat(h.uploadPath(u.Id) + ".json"); !os.IsNotExist(err) {
		t.Fatal("a stale upload's details were kept")
	}
}
