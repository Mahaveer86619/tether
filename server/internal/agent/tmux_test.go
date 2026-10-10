package agent

import (
	"fmt"
	"testing"
)

// Captured from Claude Code 2.1.296 with `tmux capture-pane -p`.
const trustScreen = ` Accessing workspace:
 /tmp/tether-tmux-e2e
 Quick safety check: Is this a project you created or one you trust? (Like your own code, a well-known open source project, or work from your team). If
 not, take a moment to review what's in this folder first.
 Claude Code'll be able to read, edit, and execute files here.
 Security guide
 %s No, exit
 %s Yes, I trust this folder
 Enter to confirm · Esc to cancel`

func TestTrustDialog(t *testing.T) {
	noSelected := fmt.Sprintf(trustScreen, "❯", " ")
	yesSelected := fmt.Sprintf(trustScreen, " ", "❯")
	if !awaitingTrust(noSelected) || !awaitingTrust(yesSelected) {
		t.Fatal("trust dialog not detected")
	}
	if trustSelected(noSelected) {
		t.Error("cursor on No reported as Yes")
	}
	if !trustSelected(yesSelected) {
		t.Error("cursor on Yes not detected")
	}
	if awaitingTrust("❯ \n  ⏸ manual mode on · ? for shortcuts") {
		t.Error("prompt screen mistaken for trust dialog")
	}
}
