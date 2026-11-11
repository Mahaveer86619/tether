package agent

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
)

// Programs whose presence says what a machine can do; the lead's prompt
// lists them so "build the APK" goes to the machine that can.
var capabilityTools = []string{"git", "go", "node", "python", "java", "gradle", "flutter", "dart", "docker", "tmux", "cargo", "dotnet"}

// findCapabilities reports the tools on PATH, and "android-sdk" when an
// Android SDK is installed. getenv and home are injected for tests.
var lookPath = exec.LookPath

func findCapabilities(lookPath func(string) (string, error), getenv func(string) string, home string) []string {
	var out []string
	for _, tool := range capabilityTools {
		if _, err := lookPath(tool); err == nil {
			out = append(out, tool)
		}
	}
	if hasAndroidSDK(getenv, home) {
		out = append(out, "android-sdk")
	}
	sort.Strings(out)
	return out
}

func hasAndroidSDK(getenv func(string) string, home string) bool {
	candidates := []string{getenv("ANDROID_HOME"), getenv("ANDROID_SDK_ROOT")}
	switch runtime.GOOS {
	case "windows":
		candidates = append(candidates, filepath.Join(getenv("LOCALAPPDATA"), "Android", "Sdk"))
	case "darwin":
		candidates = append(candidates, filepath.Join(home, "Library", "Android", "sdk"))
	default:
		candidates = append(candidates, filepath.Join(home, "Android", "Sdk"))
	}
	for _, dir := range candidates {
		if dir == "" {
			continue
		}
		if st, err := os.Stat(filepath.Join(dir, "platform-tools")); err == nil && st.IsDir() {
			return true
		}
	}
	return false
}

func (a *Agent) probeCapabilities() {
	home, _ := os.UserHomeDir()
	caps := findCapabilities(exec.LookPath, os.Getenv, home)
	a.mu.Lock()
	a.capabilities = caps
	a.mu.Unlock()
}
