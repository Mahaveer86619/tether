package agent

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// What the doctor looks at. Everything is passed in so the checks can be
// tested without a machine to match.
type doctorFacts struct {
	ClaudeVersion string // empty when Claude Code did not answer
	ClaudePath    string // what the agent was told to run
	SettingsPath  string // Claude Code's settings file the hooks go in; empty when hooks are off
	HookPath      string // the path the hooks call, to recognise ours
	MCP           string // "" not tried, "ok", or why it failed
	HomeDir       string
	LookPath      func(string) (string, error)
	ReadFile      func(string) ([]byte, error)
	CanWrite      func(dir string) error
	OS            string
}

// doctor checks that this machine can do what Tether asks of it, for the
// device's checklist. Required checks are the ones without which nothing
// works; the rest are conveniences.
func doctor(f doctorFacts) []*v1.DoctorCheck {
	var out []*v1.DoctorCheck
	add := func(id, label string, required, ok bool, detail string) {
		out = append(out, &v1.DoctorCheck{Id: id, Label: label, Ok: ok, Required: required, Detail: detail})
	}

	if f.ClaudeVersion != "" {
		add("claude", "Claude Code", true, true, "Claude Code "+f.ClaudeVersion)
	} else {
		add("claude", "Claude Code", true, false, "Claude Code did not answer at \""+f.ClaudePath+"\". Install it, sign in once with `claude`, then restart the agent.")
	}

	switch {
	case f.SettingsPath == "":
		add("hooks", "Hooks in Claude Code", false, false, "Hooks are turned off, so sessions started in a terminal are not tracked.")
	default:
		b, err := f.ReadFile(f.SettingsPath)
		if err == nil && strings.Contains(string(b), f.HookPath) {
			add("hooks", "Hooks in Claude Code", true, true, "Installed in "+f.SettingsPath)
		} else {
			add("hooks", "Hooks in Claude Code", true, false, "Not found in "+f.SettingsPath+". Restart the agent to install them.")
		}
	}

	switch f.MCP {
	case "ok":
		add("mcp", "Tether tools for Claude", false, true, "Claude can see your other machines and the shared files.")
	case "":
		add("mcp", "Tether tools for Claude", false, false, "Not registered yet.")
	default:
		add("mcp", "Tether tools for Claude", false, false, f.MCP)
	}

	if _, err := f.LookPath("git"); err == nil {
		add("git", "git", false, true, "Found.")
	} else {
		add("git", "git", false, false, "Not found. Projects are matched and copied with it.")
	}

	if f.OS != "windows" {
		if _, err := f.LookPath("tmux"); err == nil {
			add("tmux", "tmux", false, true, "Sessions can run in tmux and survive the agent restarting.")
		} else {
			add("tmux", "tmux", false, false, "Not found. Sessions run headless instead.")
		}
	}

	if err := f.CanWrite(filepath.Join(f.HomeDir, ".tether")); err == nil {
		add("data", "Tether's folder", true, true, "Writable.")
	} else {
		add("data", "Tether's folder", true, false, "Cannot write to "+filepath.Join(f.HomeDir, ".tether")+": "+err.Error())
	}
	return out
}

func canWriteDir(dir string) error {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	f, err := os.CreateTemp(dir, ".doctor-*")
	if err != nil {
		return err
	}
	name := f.Name()
	f.Close()
	return os.Remove(name)
}

// doctorChecks runs the checks against this machine now.
func (a *Agent) doctorChecks() []*v1.DoctorCheck {
	home, _ := os.UserHomeDir()
	a.mu.Lock()
	mcp := a.mcpState
	a.mu.Unlock()
	return doctor(doctorFacts{
		ClaudeVersion: a.claudeV,
		ClaudePath:    a.cfg.Claude,
		SettingsPath:  a.cfg.SettingsPath,
		HookPath:      hookPath,
		MCP:           mcp,
		HomeDir:       home,
		LookPath:      lookPath,
		ReadFile:      os.ReadFile,
		CanWrite:      canWriteDir,
		OS:            runtime.GOOS,
	})
}
