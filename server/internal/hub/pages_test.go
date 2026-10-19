package hub

import (
	"net/http"
	"strings"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestPagesAreListedAndServedWithTheirOwnFiles(t *testing.T) {
	_, srv := newTestHubWith(t)
	page := func(path, body string) {
		name := path[strings.LastIndex(path, "/")+1:]
		upload(t, srv.URL, name, body, map[string]string{"X-Session": "s1", "X-Origin": "page", "X-Path": path})
	}
	page("demo/index.html", `<link rel="stylesheet" href="css/site.css"><h1>old</h1>`)
	time.Sleep(2 * time.Millisecond)
	page("demo/index.html", `<link rel="stylesheet" href="css/site.css"><h1>new</h1>`)
	page("demo/css/site.css", "h1{color:red}")

	status, body := call(t, srv, "GET", "/api/v1/pages?session=s1", "secret", "")
	list := &v1.PageList{}
	if status != 200 || protojson.Unmarshal([]byte(body), list) != nil || len(list.Pages) != 1 {
		t.Fatalf("pages: %d %s", status, body)
	}
	p := list.Pages[0]
	if p.Name != "demo" || p.Files != 2 || !strings.HasSuffix(p.Url, "/index.html") {
		t.Fatalf("want one page with its two newest files, got %v", p)
	}

	// No token: the link itself is the credential.
	res, err := http.Get(srv.URL + p.Url)
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != 200 || !strings.HasPrefix(res.Header.Get("Content-Type"), "text/html") ||
		!strings.Contains(res.Header.Get("Content-Security-Policy"), "sandbox") {
		t.Fatalf("index: %d %v", res.StatusCode, res.Header)
	}
	if code, b := get(t, srv.URL+p.Url, ""); code != 200 || !strings.Contains(b, "new") {
		t.Fatalf("want the newest version, got %d %s", code, b)
	}
	css := strings.TrimSuffix(p.Url, "index.html") + "css/site.css"
	if code, b := get(t, srv.URL+css, ""); code != 200 || b != "h1{color:red}" {
		t.Fatalf("a relative file should resolve, got %d %s", code, b)
	}
	if code, _ := get(t, srv.URL+strings.TrimSuffix(p.Url, "index.html"), ""); code != 200 {
		t.Fatalf("the page's folder should serve index.html, got %d", code)
	}

	forged := strings.Replace(p.Url, "/demo/", "/other/", 1)
	if code, _ := get(t, srv.URL+forged, ""); code != http.StatusForbidden {
		t.Fatalf("a link signed for another page must not work, got %d", code)
	}
	if code, _ := get(t, srv.URL+strings.TrimSuffix(p.Url, "index.html")+"../../../../../api/v1/state", ""); code == 200 {
		t.Fatal("a page link must not reach the API")
	}
}
