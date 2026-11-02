package indexer

import "testing"

func TestTetherignore(t *testing.T) {
	rules := ParseIgnore(DefaultTetherignore + "\n/docs/private/\nweb/**/*.map\n")
	cases := []struct {
		path string
		dir  bool
		want bool
	}{
		{".git", true, true},
		{"node_modules", true, true},
		{"web/node_modules", true, true},
		{"server/.env", false, true},
		{".env.local", false, true},
		{".env.example", false, false},
		{"server/main.go", false, false},
		{"build", true, true},
		{"build", false, false}, // a file called build is kept
		{"docs/private", true, true},
		{"server/docs/private", true, false},
		{"web/dist/app.js.map", false, true},
		{"web/app.js.map", false, true},
		{"app.log", false, true},
		{".tether/codebase.json", false, false},
		{".tether/attachments", true, true},
	}
	for _, c := range cases {
		if got := rules.Ignored(c.path, c.dir); got != c.want {
			t.Errorf("ignored(%q, dir=%v) = %v, want %v", c.path, c.dir, got, c.want)
		}
	}
	for name, want := range map[string]bool{".env": true, ".env.local": true, ".env.production": true, ".env.example": false, "env": false, ".envrc": false} {
		if IsEnvFile(name) != want {
			t.Errorf("isEnvFile(%q) != %v", name, want)
		}
	}
}
