package agent

import (
	"slices"
	"testing"
)

func TestSessionArgsPassTheSystemPrompt(t *testing.T) {
	args := sessionArgs(startOpts{session: "s", systemPrompt: "You are in chat c."})
	i := slices.Index(args, "--append-system-prompt")
	if i < 0 || args[i+1] != "You are in chat c." {
		t.Fatalf("args %v", args)
	}
	if slices.Contains(sessionArgs(startOpts{session: "s"}), "--append-system-prompt") {
		t.Fatal("no system prompt, no flag")
	}
}
