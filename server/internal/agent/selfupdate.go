package agent

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/updates"
)

// The agent updates itself when the hub asks: it downloads the new binary
// through the hub, checks its sha256 and that it runs, keeps the old one
// as <exe>.prev and restarts. A marker file counts the new binary's starts;
// if it can't reach the hub within a few, the old one is put back. See
// docs/releasing.md.

// ExitRestart is the exit code that tells the service manager to start
// the agent again.
const ExitRestart = updates.ExitRestart
const maxUpdateStarts = 3

func markerPath(exe string) string { return updates.MarkerPath(exe) }

// Relaunch asks Task Scheduler to start the agent again on Windows.
func Relaunch(log *slog.Logger) {
	updates.Relaunch(log)
}

func (a *Agent) selfUpdate(u *v1.AgentCommand_SelfUpdate) {
	if !a.cfg.SelfUpdate || a.cfg.Exe == "" || u.GetAsset() == nil {
		return
	}
	a.mu.Lock()
	busy := len(a.runs) > 0
	a.mu.Unlock()
	if busy {
		// Headless runs would die with the process; the hub asks again later.
		a.log.Info("update postponed: sessions are running", "version", u.Version)
		return
	}
	if err := a.installUpdate(u); err != nil {
		a.log.Error("self-update", "version", u.Version, "err", err)
		return
	}
	a.log.Info("updated; restarting", "from", a.cfg.Version, "to", u.Version)
	a.cfg.Restart()
}

func (a *Agent) installUpdate(u *v1.AgentCommand_SelfUpdate) error {
	exe := a.cfg.Exe
	next := exe + ".new"
	if err := a.downloadFrom(u.Asset.Url, u.Asset.Sha256, next); err != nil {
		return err
	}
	if err := runCheck(next, u.Version); err != nil {
		os.Remove(next)
		return err
	}
	prev := exe + ".prev"
	_ = os.Remove(prev)
	// A running executable can be renamed, even on Windows.
	if err := os.Rename(exe, prev); err != nil {
		return err
	}
	if err := os.Rename(next, exe); err != nil {
		_ = os.Rename(prev, exe)
		return err
	}
	if err := os.Chmod(exe, 0o755); err != nil {
		return err
	}
	return updates.WriteMarker(exe, a.cfg.Version, u.Version)
}

// runCheck is checkRuns; tests replace it.
var runCheck = checkRuns

// checkRuns makes sure the downloaded binary starts and is the version
// it should be.
func checkRuns(exe, want string) error {
	if err := os.Chmod(exe, 0o755); err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, exe, "version")
	hideWindow(cmd)
	out, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("the new binary doesn't run: %w", err)
	}
	if got := strings.TrimSpace(string(out)); got != want {
		return fmt.Errorf("the new binary says it is %q, want %q", got, want)
	}
	return nil
}

// downloadFrom fetches a file from a path on the hub into dst, checking
// its sha256.
func (a *Agent) downloadFrom(path, sha, dst string) error {
	if !strings.HasPrefix(path, "/") {
		return fmt.Errorf("update url %q is not on the hub", path)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
	defer cancel()
	req, err := a.hubRequest(ctx, http.MethodGet, path, nil)
	if err != nil {
		return err
	}
	res, err := a.hubClient().Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("hub said %s", res.Status)
	}
	f, err := os.Create(dst)
	if err != nil {
		return err
	}
	_, err = io.Copy(f, res.Body)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		var got string
		if got, err = fileSHA256(dst); err == nil && !strings.EqualFold(got, sha) {
			err = errors.New("the update doesn't match its sha256")
		}
	}
	if err != nil {
		os.Remove(dst)
	}
	return err
}

// CheckUpdate runs at startup. After an update it counts this start, and
// once the new binary has failed to reach the hub too often it puts the
// previous one back and returns true: the caller should exit with
// ExitRestart so the old binary starts.
func CheckUpdate(exe, version string, log *slog.Logger) bool {
	return updates.Check(exe, version, log)
}

// commitUpdate forgets the marker once the new binary has reached the hub.
func (a *Agent) commitUpdate() {
	if a.cfg.Exe == "" {
		return
	}
	if err := os.Remove(markerPath(a.cfg.Exe)); err == nil {
		a.log.Info("update confirmed", "version", a.cfg.Version)
	}
}
