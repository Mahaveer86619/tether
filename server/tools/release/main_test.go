package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestManifestFromADistFolder(t *testing.T) {
	dist := t.TempDir()
	for _, name := range []string{"tether-0.17.0.apk", "tether-windows-0.17.0.zip", "tether-hub-linux-amd64", "tether-agent-windows-amd64.exe", "tetherctl-linux-amd64", "notes.txt"} {
		if err := os.WriteFile(filepath.Join(dist, name), []byte(name), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	changelog := filepath.Join(t.TempDir(), "CHANGELOG.md")
	_ = os.WriteFile(changelog, []byte("# Changelog\n\n## 0.17.0 (2026-10-24)\n\n- In-app updates.\n\n## 0.16.0\n\n- Chats.\n"), 0o644)

	if err := run(dist, "0.17.0", "https://example.com/v0.17.0", changelog, "0.15.0"); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(filepath.Join(dist, "latest.json"))
	var m manifest
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	if m.Version != "0.17.0" || m.MinSupported != "0.15.0" || m.Notes != "- In-app updates." {
		t.Fatalf("manifest %+v", m)
	}
	want := map[string]string{"android": "tether-0.17.0.apk", "windows": "tether-windows-0.17.0.zip", "hub-linux-amd64": "tether-hub-linux-amd64",
		"agent-windows-amd64": "tether-agent-windows-amd64.exe", "tetherctl-linux-amd64": "tetherctl-linux-amd64"}
	if len(m.Platforms) != len(want) {
		t.Fatalf("platforms %v", m.Platforms)
	}
	for key, name := range want {
		a := m.Platforms[key]
		if a == nil || a.Name != name || a.URL != "https://example.com/v0.17.0/"+name || len(a.Sha256) != 64 || a.Size != int64(len(name)) {
			t.Fatalf("%s: %+v", key, a)
		}
	}
	sums, _ := os.ReadFile(filepath.Join(dist, "SHA256SUMS"))
	if strings.Count(string(sums), "\n") != 6 || !strings.Contains(string(sums), "  notes.txt") {
		t.Fatalf("SHA256SUMS:\n%s", sums)
	}
}
