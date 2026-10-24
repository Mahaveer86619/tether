// Package hooks installs, uninstalls, and models Claude Code HTTP hook events.
package hooks

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"
)

const (
	// Path is the URL subpath where Claude Code sends hook events.
	Path = "/tether/hook"

	// ApprovalTimeout is the timeout (in seconds) for a PermissionRequest hook to wait for an answer.
	ApprovalTimeout = 3600

	// StaleTimeout is the duration after which sessions with no events are considered closed.
	StaleTimeout = 12 * time.Hour
)

// Events are the Claude Code hook events the agent listens to.
var Events = []string{"SessionStart", "UserPromptSubmit", "PermissionRequest", "PostToolUse", "Notification", "Stop", "StopFailure", "SessionEnd"}

// Input is the JSON payload received from a Claude Code hook.
type Input struct {
	SessionID        string          `json:"session_id"`
	Cwd              string          `json:"cwd"`
	Event            string          `json:"hook_event_name"`
	ToolName         string          `json:"tool_name"`
	ToolInput        json.RawMessage `json:"tool_input"`
	ToolUseID        string          `json:"tool_use_id"`
	NotificationType string          `json:"notification_type"`
	Message          string          `json:"message"`
	Error            string          `json:"error"`
}

// Install adds Tether's HTTP hooks to a Claude Code settings file,
// replacing any earlier Tether entries and leaving everything else as is.
func Install(settingsPath, url string) error {
	return editHooks(settingsPath, func(hooks map[string][]map[string]any) {
		for _, ev := range Events {
			entry := map[string]any{"type": "http", "url": url, "timeout": 10}
			if ev == "PermissionRequest" {
				entry["timeout"] = ApprovalTimeout
			}
			hooks[ev] = append(hooks[ev], map[string]any{"hooks": []any{entry}})
		}
	})
}

// Uninstall removes Tether's hooks from a Claude Code settings file.
func Uninstall(settingsPath string) error {
	return editHooks(settingsPath, func(map[string][]map[string]any) {})
}

func editHooks(path string, add func(map[string][]map[string]any)) error {
	orig, err := os.ReadFile(path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	if len(bytes.TrimSpace(orig)) == 0 {
		orig = []byte("{}")
	}
	keys, values, err := orderedObject(orig)
	if err != nil {
		return fmt.Errorf("%s: %w", path, err)
	}

	hooks := map[string][]map[string]any{}
	if raw, ok := values["hooks"]; ok {
		if err := json.Unmarshal(raw, &hooks); err != nil {
			return fmt.Errorf("%s: hooks: %w", path, err)
		}
	}
	for ev, groups := range hooks {
		var kept []map[string]any
		for _, g := range groups {
			list, _ := g["hooks"].([]any)
			var rest []any
			for _, h := range list {
				if m, ok := h.(map[string]any); ok && isTetherHook(m) {
					continue
				}
				rest = append(rest, h)
			}
			if len(list) == 0 {
				kept = append(kept, g)
				continue
			}
			if len(rest) == 0 {
				continue
			}
			g["hooks"] = rest
			kept = append(kept, g)
		}
		if len(kept) == 0 {
			delete(hooks, ev)
		} else {
			hooks[ev] = kept
		}
	}
	add(hooks)

	if len(hooks) == 0 {
		if _, ok := values["hooks"]; ok {
			delete(values, "hooks")
			keys = without(keys, "hooks")
		}
	} else {
		raw, err := json.Marshal(hooks)
		if err != nil {
			return err
		}
		if _, ok := values["hooks"]; !ok {
			keys = append(keys, "hooks")
		}
		values["hooks"] = raw
	}

	out := writeObject(keys, values)
	if bytes.Equal(bytes.TrimSpace(out), bytes.TrimSpace(orig)) {
		return nil
	}
	if _, err := os.Stat(path + ".tether-backup"); errors.Is(err, os.ErrNotExist) && len(orig) > 2 {
		if err := os.WriteFile(path+".tether-backup", orig, 0o600); err != nil {
			return err
		}
	}
	tmp := path + ".tether-tmp"
	if err := os.WriteFile(tmp, out, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func isTetherHook(m map[string]any) bool {
	url, _ := m["url"].(string)
	return m["type"] == "http" && strings.HasSuffix(url, Path)
}

func orderedObject(data []byte) ([]string, map[string]json.RawMessage, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	tok, err := dec.Token()
	if err != nil {
		return nil, nil, err
	}
	if d, ok := tok.(json.Delim); !ok || d != '{' {
		return nil, nil, errors.New("not a JSON object")
	}
	var keys []string
	values := map[string]json.RawMessage{}
	for dec.More() {
		tok, err := dec.Token()
		if err != nil {
			return nil, nil, err
		}
		k, _ := tok.(string)
		var raw json.RawMessage
		if err := dec.Decode(&raw); err != nil {
			return nil, nil, err
		}
		if _, dup := values[k]; !dup {
			keys = append(keys, k)
		}
		values[k] = raw
	}
	return keys, values, nil
}

func writeObject(keys []string, values map[string]json.RawMessage) []byte {
	var b bytes.Buffer
	b.WriteString("{")
	for i, k := range keys {
		if i > 0 {
			b.WriteString(",")
		}
		kb, _ := json.Marshal(k)
		var v bytes.Buffer
		if json.Indent(&v, values[k], "  ", "  ") != nil {
			v.Write(values[k])
		}
		fmt.Fprintf(&b, "\n  %s: %s", kb, v.Bytes())
	}
	b.WriteString("\n}\n")
	return b.Bytes()
}

func without(ss []string, s string) []string {
	var out []string
	for _, x := range ss {
		if x != s {
			out = append(out, x)
		}
	}
	return out
}
