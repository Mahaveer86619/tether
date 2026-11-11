package agent

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestFindCapabilities(t *testing.T) {
	sdk := t.TempDir()
	if err := os.MkdirAll(filepath.Join(sdk, "platform-tools"), 0o755); err != nil {
		t.Fatal(err)
	}
	have := map[string]bool{"flutter": true, "go": true, "git": true}
	look := func(name string) (string, error) {
		if have[name] {
			return "/bin/" + name, nil
		}
		return "", errors.New("not found")
	}
	env := func(k string) string {
		if k == "ANDROID_HOME" {
			return sdk
		}
		return ""
	}
	got := findCapabilities(look, env, t.TempDir())
	want := []string{"android-sdk", "flutter", "git", "go"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %v, want %v", got, want)
	}
	if got := findCapabilities(look, func(string) string { return "" }, t.TempDir()); reflect.DeepEqual(got, want) {
		t.Errorf("an SDK that isn't there was reported: %v", got)
	}
}
