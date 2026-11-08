package winupdate

import (
	"archive/zip"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func makeZip(t *testing.T, path string, files map[string]string) {
	t.Helper()
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	w := zip.NewWriter(f)
	for name, body := range files {
		fw, err := w.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		fw.Write([]byte(body))
	}
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	f.Close()
}

func read(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

type fixture struct {
	app, zip, ok string
	started      []string
	hooks        Hooks
}

// newFixture lays out an installed app (version "old") and an update zip
// (version "new"). The fake Start writes the OK file when okOnNew is set.
func newFixture(t *testing.T, okOnNew bool) *fixture {
	dir := t.TempDir()
	fx := &fixture{app: filepath.Join(dir, "Tether"), zip: filepath.Join(dir, "u.zip"), ok: filepath.Join(dir, "ok")}
	if err := os.MkdirAll(fx.app, 0o755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(fx.app, "tether.exe"), []byte("old"), 0o755)
	os.WriteFile(filepath.Join(fx.app, "stale.dll"), []byte("old dll"), 0o644)
	makeZip(t, fx.zip, map[string]string{"tether.exe": "new", "data/app.so": "new data"})
	fx.hooks = Hooks{
		Start: func(exe string, env []string) (func(), error) {
			fx.started = append(fx.started, read(t, exe))
			if okOnNew && read(t, exe) == "new" {
				os.WriteFile(fx.ok, []byte("1"), 0o644)
			}
			return func() {}, nil
		},
		Sleep: func(time.Duration) {},
	}
	return fx
}

func TestApplySwapsInTheNewVersionAndKeepsTheOldOne(t *testing.T) {
	fx := newFixture(t, true)
	err := Apply(Config{Zip: fx.zip, App: fx.app, Exe: "tether.exe", OKFile: fx.ok, Timeout: time.Second}, fx.hooks)
	if err != nil {
		t.Fatal(err)
	}
	if read(t, filepath.Join(fx.app, "tether.exe")) != "new" || read(t, filepath.Join(fx.app, "data", "app.so")) != "new data" {
		t.Error("the new version should be in place")
	}
	if _, err := os.Stat(filepath.Join(fx.app, "stale.dll")); !os.IsNotExist(err) {
		t.Error("files dropped from the new version should not linger")
	}
	if read(t, filepath.Join(fx.app+".prev", "tether.exe")) != "old" {
		t.Error("the old version is kept as .prev")
	}
	if _, err := os.Stat(fx.zip); !os.IsNotExist(err) {
		t.Error("the zip is deleted after a good start")
	}
	if len(fx.started) != 1 || fx.started[0] != "new" {
		t.Errorf("started %v", fx.started)
	}
}

func TestApplyGoesBackWhenTheNewVersionDoesNotReportIn(t *testing.T) {
	fx := newFixture(t, false)
	err := Apply(Config{Zip: fx.zip, App: fx.app, Exe: "tether.exe", OKFile: fx.ok, Timeout: 50 * time.Millisecond}, fx.hooks)
	if err == nil {
		t.Fatal("expected an error")
	}
	if read(t, filepath.Join(fx.app, "tether.exe")) != "old" {
		t.Error("the old version should be back")
	}
	if _, err := os.Stat(fx.app + ".failed"); !os.IsNotExist(err) {
		t.Error("the failed version is removed")
	}
	if _, err := os.Stat(fx.zip); err != nil {
		t.Error("the zip stays, so another try is possible")
	}
	if len(fx.started) != 2 || fx.started[0] != "new" || fx.started[1] != "old" {
		t.Errorf("the new one was tried, then the old one restarted: %v", fx.started)
	}
}

func TestApplyLeavesTheAppAloneWhenTheZipIsBad(t *testing.T) {
	fx := newFixture(t, true)
	os.WriteFile(fx.zip, []byte("not a zip"), 0o644)
	if err := Apply(Config{Zip: fx.zip, App: fx.app, OKFile: fx.ok}, fx.hooks); err == nil {
		t.Fatal("expected an error")
	}
	if read(t, filepath.Join(fx.app, "tether.exe")) != "old" || len(fx.started) != 0 {
		t.Error("a bad zip must not touch the installed app")
	}

	makeZip(t, fx.zip, map[string]string{"readme.txt": "no exe"})
	if err := Apply(Config{Zip: fx.zip, App: fx.app, OKFile: fx.ok}, fx.hooks); err == nil {
		t.Fatal("a zip without the app should be refused")
	}
	if read(t, filepath.Join(fx.app, "tether.exe")) != "old" {
		t.Error("still the old one")
	}
}

func TestApplyRefusesNamesThatLeaveTheFolder(t *testing.T) {
	fx := newFixture(t, true)
	makeZip(t, fx.zip, map[string]string{"tether.exe": "new", "../escape.txt": "x"})
	if err := Apply(Config{Zip: fx.zip, App: fx.app, OKFile: fx.ok}, fx.hooks); err == nil {
		t.Fatal("expected an error")
	}
	if _, err := os.Stat(filepath.Join(filepath.Dir(fx.app), "escape.txt")); !os.IsNotExist(err) {
		t.Error("a file was written outside the folder")
	}
}

func TestApplyWaitsForTheAppToExit(t *testing.T) {
	fx := newFixture(t, true)
	fx.hooks.Wait = func(pid int, d time.Duration) error { return errors.New("still running") }
	if err := Apply(Config{Zip: fx.zip, App: fx.app, OKFile: fx.ok, Pid: 42}, fx.hooks); err == nil {
		t.Fatal("expected an error")
	}
	if read(t, filepath.Join(fx.app, "tether.exe")) != "old" {
		t.Error("nothing should change while the app runs")
	}
}

// Windows PowerShell's Compress-Archive writes backslashes in entry names,
// and lists folders as entries ending in one.
func TestApplyReadsZipsMadeByPowerShell(t *testing.T) {
	fx := newFixture(t, true)
	makeZip(t, fx.zip, map[string]string{
		"tether.exe":                       "new",
		`data\`:                            "",
		`data\flutter_assets\`:             "",
		`data\flutter_assets\assets\a.txt`: "asset",
	})
	if err := Apply(Config{Zip: fx.zip, App: fx.app, OKFile: fx.ok, Timeout: time.Second}, fx.hooks); err != nil {
		t.Fatal(err)
	}
	if read(t, filepath.Join(fx.app, "data", "flutter_assets", "assets", "a.txt")) != "asset" {
		t.Error("nested files should land in their folders")
	}
}
