package agent

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func facts(t *testing.T) doctorFacts {
	t.Helper()
	have := map[string]bool{"git": true, "tmux": true}
	return doctorFacts{
		ClaudeVersion: "2.1.312",
		ClaudePath:    "claude",
		SettingsPath:  "/home/me/.claude/settings.json",
		HookPath:      "/tether-hook",
		MCP:           "ok",
		HomeDir:       t.TempDir(),
		LookPath: func(n string) (string, error) {
			if have[n] {
				return "/bin/" + n, nil
			}
			return "", errors.New("not found")
		},
		ReadFile: func(string) ([]byte, error) { return []byte(`{"hooks":{"PreToolUse":[{"hooks":[{"url":"http://127.0.0.1:1/tether-hook"}]}]}}`), nil },
		CanWrite: func(string) error { return nil },
		OS:       "linux",
	}
}

func byID(t *testing.T, f doctorFacts) map[string]bool {
	t.Helper()
	out := map[string]bool{}
	for _, c := range doctor(f) {
		out[c.Id] = c.Ok
	}
	return out
}

func TestDoctorPassesAHealthyMachine(t *testing.T) {
	for id, ok := range byID(t, facts(t)) {
		if !ok {
			t.Errorf("%s should pass", id)
		}
	}
}

func TestDoctorSaysWhatIsWrong(t *testing.T) {
	f := facts(t)
	f.ClaudeVersion = ""
	f.ReadFile = func(string) ([]byte, error) { return []byte(`{}`), nil }
	f.MCP = "the hub's certificate is self-signed"
	f.LookPath = func(string) (string, error) { return "", errors.New("no") }
	f.CanWrite = func(string) error { return errors.New("read-only file system") }

	checks := doctor(f)
	got := map[string]string{}
	for _, c := range checks {
		if c.Ok {
			t.Errorf("%s should fail", c.Id)
		}
		got[c.Id] = c.Detail
	}
	if got["mcp"] != "the hub's certificate is self-signed" {
		t.Errorf("mcp detail %q", got["mcp"])
	}
	required := map[string]bool{}
	for _, c := range checks {
		required[c.Id] = c.Required
	}
	if !required["claude"] || !required["hooks"] || !required["data"] || required["git"] || required["tmux"] || required["mcp"] {
		t.Errorf("required: %v", required)
	}
}

func TestDoctorSkipsTmuxOnWindowsAndNotesHooksOff(t *testing.T) {
	f := facts(t)
	f.OS = "windows"
	f.SettingsPath = ""
	got := byID(t, f)
	if _, ok := got["tmux"]; ok {
		t.Error("tmux is not a thing on Windows")
	}
	if got["hooks"] {
		t.Error("turned-off hooks are not fine")
	}
}

func TestCanWriteDir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "made", "on", "demand")
	if err := canWriteDir(dir); err != nil {
		t.Fatal(err)
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 0 {
		t.Errorf("the probe file should be removed, found %d", len(entries))
	}
}
