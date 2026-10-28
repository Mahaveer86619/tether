package agent

import "testing"

func TestPagePath(t *testing.T) {
	for in, want := range map[string]string{
		`C:\code\app\.tether\pages\demo\index.html`: "demo/index.html",
		"/srv/app/.tether/pages/demo/css/site.css":  "demo/css/site.css",
		"/srv/app/.tether/pages/demo":               "",
		"/srv/app/src/index.html":                   "",
	} {
		if got, ok := pagePath(in); got != want || ok != (want != "") {
			t.Errorf("pagePath(%q) = %q, %v; want %q", in, got, ok, want)
		}
	}
}
