package updates

import (
	"encoding/json"
	"log/slog"
	"os"
)

// ExitRestart is the exit code that tells the service manager to start the agent again.
const ExitRestart = 75

const maxUpdateStarts = 3

type updateMarker struct {
	From   string `json:"from"`
	To     string `json:"to"`
	Starts int    `json:"starts"`
}

// MarkerPath returns the path to the update marker file for an executable.
func MarkerPath(exe string) string {
	return exe + ".update"
}

// WriteMarker writes the update marker file recording an upgrade attempt.
func WriteMarker(exe, from, to string) error {
	b, err := json.Marshal(updateMarker{From: from, To: to})
	if err != nil {
		return err
	}
	return os.WriteFile(MarkerPath(exe), b, 0o644)
}

// Check runs at startup. After an update it counts this start, and
// once the new binary has failed to reach the hub too often it puts the
// previous one back and returns true: the caller should exit with
// ExitRestart so the old binary starts.
func Check(exe, version string, log *slog.Logger) bool {
	b, err := os.ReadFile(MarkerPath(exe))
	if err != nil {
		return false
	}
	var m updateMarker
	if json.Unmarshal(b, &m) != nil || m.To != version {
		_ = os.Remove(MarkerPath(exe))
		return false
	}
	m.Starts++
	if m.Starts <= maxUpdateStarts {
		b, _ = json.Marshal(m)
		_ = os.WriteFile(MarkerPath(exe), b, 0o644)
		return false
	}
	log.Error("the update keeps failing; going back", "from", m.To, "to", m.From)
	_ = os.Remove(exe + ".failed")
	if err := os.Rename(exe, exe+".failed"); err != nil {
		log.Error("roll back", "err", err)
		return false
	}
	if err := os.Rename(exe+".prev", exe); err != nil {
		_ = os.Rename(exe+".failed", exe)
		log.Error("roll back", "err", err)
		return false
	}
	_ = os.Remove(MarkerPath(exe))
	return true
}
