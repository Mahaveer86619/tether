package hooks

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
	url := "http://127.0.0.1:7421" + Path

	for range 2 {
		if err := Install(path, url); err != nil {
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

	if err := Uninstall(path); err != nil {
		t.Fatal(err)
	}
	got, _ = os.ReadFile(path)
	if err := json.Unmarshal(got, &s); err != nil {
		t.Fatalf("invalid JSON written: %v\n%s", err, got)
	}
	if len(s.Hooks["Stop"]) != 1 || len(s.Hooks["PreToolUse"]) != 1 {
		t.Errorf("user hooks damaged: %v", s.Hooks)
	}
}
