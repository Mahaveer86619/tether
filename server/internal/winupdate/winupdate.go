// Package winupdate swaps a new version of the Windows app in for the
// running one, and goes back to the old one if the new one does not come
// up. The app starts it as a separate program (tether-updater.exe) and exits.
// See docs/releasing.md#how-apps-and-agents-update.
package winupdate

import (
	"archive/zip"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Config says what to swap.
type Config struct {
	Zip string // the downloaded release
	App string // the app's folder, which holds Exe
	Exe string // the app's executable name, e.g. tether.exe
	// OKFile is where the new app writes a file once it has drawn its first
	// frame. Without it within Timeout, the old version is put back.
	OKFile  string
	Pid     int           // the running app, which must exit first; 0 to skip
	Timeout time.Duration // how long to wait for OKFile
	// WaitExit is how long to wait for Pid to exit.
	WaitExit time.Duration
}

// Hooks are the parts that depend on the operating system.
type Hooks struct {
	// Wait returns once the process has exited, or an error after d.
	Wait func(pid int, d time.Duration) error
	// Start runs exe with extra environment variables, not waiting for it.
	// stop ends it.
	Start func(exe string, env []string) (stop func(), err error)
	Log   func(format string, args ...any)
	Sleep func(time.Duration)
}

func (h Hooks) log(format string, args ...any) {
	if h.Log != nil {
		h.Log(format, args...)
	}
}

func (h Hooks) sleep(d time.Duration) {
	if h.Sleep != nil {
		h.Sleep(d)
		return
	}
	time.Sleep(d)
}

// Apply swaps the app for the release in cfg.Zip.
//
// The old folder is kept as <App>.prev. If the new app does not report in,
// it is removed, the old one put back and started again, and an error is
// returned. The zip is deleted only after a good start.
func Apply(cfg Config, h Hooks) error {
	if cfg.Exe == "" {
		cfg.Exe = "tether.exe"
	}
	if cfg.Timeout == 0 {
		cfg.Timeout = 30 * time.Second
	}
	if cfg.WaitExit == 0 {
		cfg.WaitExit = time.Minute
	}
	h.log("updating %s from %s", cfg.App, cfg.Zip)

	if cfg.Pid > 0 && h.Wait != nil {
		if err := h.Wait(cfg.Pid, cfg.WaitExit); err != nil {
			return fmt.Errorf("the app did not exit: %w", err)
		}
	}

	staging, prev := cfg.App+".new", cfg.App+".prev"
	if err := os.RemoveAll(staging); err != nil {
		return err
	}
	if err := extract(cfg.Zip, staging); err != nil {
		os.RemoveAll(staging)
		return fmt.Errorf("unpack the update: %w", err)
	}
	if _, err := os.Stat(filepath.Join(staging, cfg.Exe)); err != nil {
		os.RemoveAll(staging)
		return fmt.Errorf("the update has no %s", cfg.Exe)
	}

	if err := os.RemoveAll(prev); err != nil {
		return err
	}
	// Windows can hold the old files for a moment after the app exits.
	if err := retry(h, 20, 500*time.Millisecond, func() error { return os.Rename(cfg.App, prev) }); err != nil {
		os.RemoveAll(staging)
		return fmt.Errorf("move the old version aside: %w", err)
	}
	if err := os.Rename(staging, cfg.App); err != nil {
		_ = os.Rename(prev, cfg.App)
		return fmt.Errorf("put the new version in place: %w", err)
	}
	h.log("new version in place; starting it")

	_ = os.Remove(cfg.OKFile)
	stop, err := h.Start(filepath.Join(cfg.App, cfg.Exe), []string{"TETHER_UPDATE_OK=" + cfg.OKFile})
	if err == nil && cfg.OKFile != "" {
		err = waitFor(h, cfg.OKFile, cfg.Timeout)
	}
	if err == nil {
		h.log("the new version is up")
		_ = os.Remove(cfg.Zip)
		return nil
	}

	h.log("the new version did not start (%v); going back", err)
	if stop != nil {
		stop()
	}
	failed := cfg.App + ".failed"
	_ = os.RemoveAll(failed)
	if rerr := retry(h, 20, 500*time.Millisecond, func() error { return os.Rename(cfg.App, failed) }); rerr != nil {
		return fmt.Errorf("the new version did not start (%v) and could not be removed: %w", err, rerr)
	}
	if rerr := os.Rename(prev, cfg.App); rerr != nil {
		return fmt.Errorf("the new version did not start (%v) and the old one could not be put back: %w", err, rerr)
	}
	_ = os.RemoveAll(failed)
	if _, serr := h.Start(filepath.Join(cfg.App, cfg.Exe), nil); serr != nil {
		h.log("could not start the old version: %v", serr)
	}
	return fmt.Errorf("the new version did not start: %w", err)
}

func retry(h Hooks, n int, gap time.Duration, f func() error) error {
	var err error
	for i := 0; i < n; i++ {
		if err = f(); err == nil {
			return nil
		}
		h.sleep(gap)
	}
	return err
}

func waitFor(h Hooks, path string, d time.Duration) error {
	deadline := time.Now().Add(d)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(path); err == nil {
			return nil
		}
		h.sleep(250 * time.Millisecond)
	}
	return errors.New("it did not report in within " + d.String())
}

// extract unpacks zipPath into dir, refusing names that leave it.
func extract(zipPath, dir string) error {
	r, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer r.Close()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	root := filepath.Clean(dir) + string(os.PathSeparator)
	for _, f := range r.File {
		target := filepath.Join(dir, filepath.FromSlash(f.Name))
		if !strings.HasPrefix(target+string(os.PathSeparator), root) && filepath.Clean(target) != filepath.Clean(dir) {
			return fmt.Errorf("unsafe path %q in the update", f.Name)
		}
		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(target, 0o755); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		if err := copyOut(f, target); err != nil {
			return err
		}
	}
	return nil
}

func copyOut(f *zip.File, target string) error {
	in, err := f.Open()
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o755)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}
