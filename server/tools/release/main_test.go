package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeDist(t *testing.T, names ...string) string {
	t.Helper()
	dist := t.TempDir()
	for _, name := range names {
		if err := os.WriteFile(filepath.Join(dist, name), []byte(name), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dist
}

func changelogFile(t *testing.T) string {
	t.Helper()
	f := filepath.Join(t.TempDir(), "CHANGELOG.md")
	_ = os.WriteFile(f, []byte("# Changelog\n\n## 0.17.0 (2026-10-24)\n\n- In-app updates.\n\n## 0.16.0\n\n- Chats.\n"), 0o644)
	return f
}

func readManifest(t *testing.T, dist, file string) manifest {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(dist, file))
	if err != nil {
		t.Fatal(err)
	}
	var m manifest
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	return m
}

func TestCoreManifestFromADistFolder(t *testing.T) {
	dist := writeDist(t, "tether-hub-linux-amd64", "tether-agent-windows-amd64.exe", "tetherctl-linux-amd64", "notes.txt")

	if err := run(dist, "0.17.0", "https://example.com/core-v0.17.0", changelogFile(t), "0.15.0",
		options{track: "core", minApp: "0.15.0"}); err != nil {
		t.Fatal(err)
	}
	m := readManifest(t, dist, "core-latest.json")
	if m.Version != "0.17.0" || m.MinSupported != "0.15.0" || m.Notes != "- In-app updates." {
		t.Fatalf("manifest %+v", m)
	}
	if m.Track != "core" || m.MinAppVersion != "0.15.0" || m.MinCoreVersion != "" {
		t.Fatalf("compat %+v", m)
	}
	want := map[string]string{"hub-linux-amd64": "tether-hub-linux-amd64", "agent-windows-amd64": "tether-agent-windows-amd64.exe", "tetherctl-linux-amd64": "tetherctl-linux-amd64"}
	if len(m.Platforms) != len(want) {
		t.Fatalf("platforms %v", m.Platforms)
	}
	for key, name := range want {
		a := m.Platforms[key]
		if a == nil || a.Name != name || a.URL != "https://example.com/core-v0.17.0/"+name || len(a.Sha256) != 64 {
			t.Fatalf("%s: %+v", key, a)
		}
	}
	if alias := readManifest(t, dist, "latest.json"); alias.Version != m.Version {
		t.Fatalf("legacy alias %+v", alias)
	}
	sums, _ := os.ReadFile(filepath.Join(dist, "core-SHA256SUMS"))
	if strings.Count(string(sums), "\n") != 4 || !strings.Contains(string(sums), "  notes.txt") {
		t.Fatalf("core-SHA256SUMS:\n%s", sums)
	}
}

func TestAppManifestIgnoresCoreFiles(t *testing.T) {
	dist := writeDist(t, "tether-0.17.0.apk", "tether-windows-0.17.0.zip", "tether-hub-linux-amd64")

	if err := run(dist, "0.17.0", "https://example.com/app-v0.17.0", changelogFile(t), "0.15.0",
		options{track: "app", minCore: "0.16.0"}); err != nil {
		t.Fatal(err)
	}
	m := readManifest(t, dist, "app-latest.json")
	if m.Track != "app" || m.MinCoreVersion != "0.16.0" || len(m.Platforms) != 2 {
		t.Fatalf("manifest %+v", m)
	}
	if m.Platforms["android"] == nil || m.Platforms["windows"] == nil {
		t.Fatalf("platforms %v", m.Platforms)
	}
}

func TestUnifiedManifestKeepsBothKindsOfFiles(t *testing.T) {
	dist := writeDist(t, "tether-hub-linux-amd64", "tether-0.17.0.apk", "tether-windows-0.17.0.zip", "tether-herdr-linux-amd64")

	if err := run(dist, "0.17.0", "https://example.com/v0.17.0", "", "0.15.0", options{}); err != nil {
		t.Fatal(err)
	}
	m := readManifest(t, dist, "latest.json")
	if m.Track != "" || len(m.Platforms) != 4 {
		t.Fatalf("manifest %+v", m)
	}
	for _, key := range []string{"android", "windows", "hub-linux-amd64", "herdr-linux-amd64"} {
		if m.Platforms[key] == nil {
			t.Fatalf("missing %s in %v", key, m.Platforms)
		}
	}
	if _, err := os.Stat(filepath.Join(dist, "core-latest.json")); !os.IsNotExist(err) {
		t.Fatalf("unified release wrote a track manifest: %v", err)
	}
}

func TestTrackRejectsMixedFiles(t *testing.T) {
	for _, tc := range []struct {
		track string
		files []string
	}{
		{"core", []string{"tether-0.17.0.apk"}},
		{"app", []string{"tether-agent-linux-amd64"}},
	} {
		dist := writeDist(t, tc.files...)
		if err := run(dist, "0.17.0", "https://example.com", "", "", options{track: tc.track}); err == nil {
			t.Fatalf("%s track accepted %v", tc.track, tc.files)
		}
	}
}
