package agent

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestDownloadResumesAfterACutConnection(t *testing.T) {
	data := bytes.Repeat([]byte("0123456789abcdef"), 64<<10)
	sum := sha256.Sum256(data)
	sha := hex.EncodeToString(sum[:])
	var calls, ranged atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("ETag", `"`+sha+`"`)
		if calls.Add(1) == 1 {
			w.Header().Set("Content-Length", "1048576")
			w.WriteHeader(200)
			_, _ = w.Write(data[:300_000])
			w.(http.Flusher).Flush()
			panic(http.ErrAbortHandler)
		}
		if r.Header.Get("Range") != "" {
			ranged.Add(1)
		}
		http.ServeContent(w, r, "data.bin", time.Time{}, bytes.NewReader(data))
	}))
	defer srv.Close()

	a := &Agent{cfg: Config{HubURL: "ws" + strings.TrimPrefix(srv.URL, "http") + "/ws"}, log: slog.New(slog.NewTextHandler(io.Discard, nil))}
	dst := filepath.Join(t.TempDir(), "data.bin")
	if err := a.fetchArtifact(&v1.Artifact{Id: "a1", Sha256: sha, Size: int64(len(data))}, dst); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(dst)
	if !bytes.Equal(got, data) {
		t.Fatalf("got %d bytes, want %d", len(got), len(data))
	}
	if ranged.Load() != 1 {
		t.Fatalf("the second request should resume with Range, got %d ranged of %d", ranged.Load(), calls.Load())
	}
	if _, err := os.Stat(dst + ".part"); !os.IsNotExist(err) {
		t.Fatal("the partial file should be gone")
	}

	// Already there with the same content: no request at all.
	before := calls.Load()
	if err := a.fetchArtifact(&v1.Artifact{Id: "a1", Sha256: sha, Size: int64(len(data))}, dst); err != nil || calls.Load() != before {
		t.Fatalf("a file already in place was downloaded again (%v)", err)
	}
}

func TestDownloadRejectsWrongContent(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("tampered"))
	}))
	defer srv.Close()
	a := &Agent{cfg: Config{HubURL: "ws" + strings.TrimPrefix(srv.URL, "http") + "/ws"}, log: slog.New(slog.NewTextHandler(io.Discard, nil))}
	dst := filepath.Join(t.TempDir(), "x.txt")
	if err := a.download("a1", strings.Repeat("0", 64), dst); err == nil {
		t.Fatal("a file that doesn't match its sha256 should fail")
	}
	if _, err := os.Stat(dst); !os.IsNotExist(err) {
		t.Fatal("the bad file was put in place")
	}
}
