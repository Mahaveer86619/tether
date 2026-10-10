package agent

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const userSettings = `{
  "model": "opus",
  "permissions": {"defaultMode": "auto"},
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "notify-send done"}]}],
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "audit"}]}]
  },
  "theme": "dark"
}
`

func TestInstallAndUninstallHooks(t *testing.T) {
	path := filepath.Join(t.TempDir(), "settings.json")
	if err := os.WriteFile(path, []byte(userSettings), 0o600); err != nil {
		t.Fatal(err)
	}
	url := "http://127.0.0.1:7421" + hookPath

	for range 2 {
		if err := InstallHooks(path, url); err != nil {
			t.Fatal(err)
		}
	}
	got, _ := os.ReadFile(path)
	var s struct {
		Model string                      `json:"model"`
		Theme string                      `json:"theme"`
		Hooks map[string][]map[string]any `json:"hooks"`
	}
	if err := json.Unmarshal(got, &s); err != nil {
		t.Fatalf("invalid JSON written: %v\n%s", err, got)
	}
	if s.Model != "opus" || s.Theme != "dark" {
		t.Errorf("other settings lost: %s", got)
	}
	if i, j := strings.Index(string(got), `"model"`), strings.Index(string(got), `"theme"`); i > j {
		t.Errorf("key order changed: %s", got)
	}
	if len(s.Hooks["Stop"]) != 2 || len(s.Hooks["PreToolUse"]) != 1 {
		t.Errorf("user hooks not kept or Tether hook duplicated: %v", s.Hooks)
	}
	for _, ev := range hookEvents {
		if strings.Count(string(got), url) != len(hookEvents) {
			t.Fatalf("want %d Tether hooks, got %d", len(hookEvents), strings.Count(string(got), url))
		}
		if len(s.Hooks[ev]) == 0 {
			t.Errorf("no hook for %s", ev)
		}
	}
	if _, err := os.Stat(path + ".tether-backup"); err != nil {
		t.Errorf("no backup written: %v", err)
	}

	if err := UninstallHooks(path); err != nil {
		t.Fatal(err)
	}
	got, _ = os.ReadFile(path)
	if strings.Contains(string(got), hookPath) {
		t.Errorf("Tether hooks left behind: %s", got)
	}
	if !strings.Contains(string(got), "notify-send done") || !strings.Contains(string(got), `"audit"`) {
		t.Errorf("user hooks removed: %s", got)
	}
}

func TestInstallHooksCreatesSettings(t *testing.T) {
	path := filepath.Join(t.TempDir(), "settings.json")
	if err := InstallHooks(path, "http://127.0.0.1:7421"+hookPath); err != nil {
		t.Fatal(err)
	}
	if err := UninstallHooks(path); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(path)
	if strings.TrimSpace(string(got)) != "{\n}" {
		t.Errorf("expected empty object, got %q", got)
	}
}
