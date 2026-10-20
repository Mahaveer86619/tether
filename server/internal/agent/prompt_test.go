package agent

import (
	"io"
	"log/slog"
	"reflect"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestParseDialog(t *testing.T) {
	cases := []struct {
		name     string
		screen   string
		title    string
		options  []string
		keys     []string
		selected int
	}{
		{
			name: "boxed numbered menu (folder trust)",
			screen: `
╭──────────────────────────────────────────────────────────────╮
│ Do you trust the files in this folder?                       │
│                                                              │
│ /home/me/project                                             │
│                                                              │
│ ❯ 1. Yes, proceed                                            │
│   2. No, exit                                                │
│                                                              │
│ Enter to confirm · Esc to exit                               │
╰──────────────────────────────────────────────────────────────╯
`,
			title: "/home/me/project", options: []string{"Yes, proceed", "No, exit"}, selected: 0,
		},
		{
			name: "permission menu with the cursor further down",
			screen: `● Bash(rm -rf build)
  ⎿  Running…

 Do you want to proceed?
   1. Yes
 ❯ 2. Yes, and don't ask again for rm commands in /home/me/project
   3. No, and tell Claude what to do differently (esc)
`,
			title:   "Do you want to proceed?",
			options: []string{"Yes", "Yes, and don't ask again for rm commands in /home/me/project", "No, and tell Claude what to do differently (esc)"},
			selected: 1,
		},
		{
			name: "picker with a current-value mark and descriptions",
			screen: ` Select model
 Switch between Claude models.

 ❯ 1. Default (recommended)  Opus for complex work ✔
   2. Sonnet                 Fast everyday model
   3. Haiku                  Quickest

 Enter to confirm · Esc to exit
`,
			title:    "Switch between Claude models.",
			options:  []string{"Default (recommended)  Opus for complex work", "Sonnet                 Fast everyday model", "Haiku                  Quickest"},
			selected: 0,
		},
		{
			name: "unnumbered menu",
			screen: ` Auto mode is on. Was that helpful?
 ❯ Yes
   No
   Don't ask again
`,
			title: "Auto mode is on. Was that helpful?", options: []string{"Yes", "No", "Don't ask again"}, selected: 0,
		},
		{
			name: "one-line survey",
			screen: `⏺ Done. The tests pass.

● How is Claude doing this session? (optional)
  1: Bad    2: Fine   3: Good   0: Dismiss

╭────────────────────────────────╮
│ >                              │
╰────────────────────────────────╯
`,
			title: "How is Claude doing this session? (optional)", options: []string{"Bad", "Fine", "Good", "Dismiss"},
			keys: []string{"1", "2", "3", "0"}, selected: -1,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			d := parseDialog(c.screen)
			if d == nil {
				t.Fatal("no dialog found")
			}
			if d.title != c.title || !reflect.DeepEqual(d.options, c.options) || d.selected != c.selected || !reflect.DeepEqual(d.keys, c.keys) {
				t.Fatalf("got title %q options %q keys %q selected %d", d.title, d.options, d.keys, d.selected)
			}
		})
	}
}

func TestParseDialogIgnoresOrdinaryScreens(t *testing.T) {
	for name, screen := range map[string]string{
		"idle input box": `⏺ All set.

╭──────────────────────────────╮
│ > fix the login bug          │
╰──────────────────────────────╯
  ? for shortcuts
`,
		"a numbered list in Claude's answer": `⏺ Here's the plan:
  1. Add the migration
  2. Update the store
  3. Write tests

╭──────────────────────────────╮
│ >                            │
╰──────────────────────────────╯
`,
		"working": `✻ Thinking… (12s · esc to interrupt)
`,
		"empty": "",
	} {
		if d := parseDialog(screen); d != nil {
			t.Errorf("%s: found a dialog %+v", name, d)
		}
	}
}

func TestScreenPromptLifecycle(t *testing.T) {
	a := &Agent{log: slog.New(slog.NewTextHandler(io.Discard, nil)), index: NewIndex(t.TempDir()), prompts: map[string]*screenPrompt{},
		hooks: map[string]*hookSession{}, hookApprovals: map[string]*hookApproval{}, trust: map[string]string{}, trustUntil: map[string]time.Time{}}
	target := screenTarget{session: "s1", pane: "%1"}
	survey := "● How is Claude doing this session? (optional)\n  1: Bad    2: Fine   3: Good   0: Dismiss\n"

	a.noteScreen(target, survey)
	first := a.prompts["s1"]
	if first == nil {
		t.Fatal("a dialog on screen should become a prompt")
	}
	a.noteScreen(target, survey)
	if a.prompts["s1"] != first {
		t.Fatal("the same dialog again must not raise a second prompt")
	}
	a.noteScreen(target, "● Which file?\n ❯ 1. a.go\n   2. b.go\n")
	if p := a.prompts["s1"]; p == nil || p == first {
		t.Fatal("a different dialog replaces the prompt")
	}
	a.noteScreen(target, "✻ Working…\n")
	if a.prompts["s1"] != nil {
		t.Fatal("the prompt goes when the dialog leaves the screen")
	}

	// A tool permission the hook already turned into a card isn't asked twice.
	a.hookApprovals["h1"] = &hookApproval{session: "s1"}
	a.noteScreen(target, " Do you want to proceed?\n ❯ 1. Yes\n   2. No\n")
	if a.prompts["s1"] != nil {
		t.Fatal("a dialog a hook reported must not become a second card")
	}
}

func TestAnswerPromptOnlyClaimsItsOwnCards(t *testing.T) {
	a := &Agent{log: slog.New(slog.NewTextHandler(io.Discard, nil)), prompts: map[string]*screenPrompt{}}
	if a.answerPrompt("other", &v1.ApprovalDecision{ApprovalId: "other"}) {
		t.Fatal("an unknown approval isn't a prompt")
	}
}

func TestScreenMode(t *testing.T) {
	for screen, want := range map[string]string{
		"╭──╮\n│ > │\n╰──╯\n  ⏵⏵ accept edits on (shift+tab to cycle)": "acceptEdits",
		"│ > │\n  ⏸ plan mode on (shift+tab to cycle)":                         "plan",
		"│ > │\n  ⏵⏵ auto mode on (shift+tab to cycle)":                        "auto",
		"│ > │\n  ? for shortcuts":                                            "default",
		// Only the bottom lines count: the words in Claude's answer don't.
		"⏺ I turned plan mode on earlier.\n\n\n\n\n\n\n│ > │\n  ? for shortcuts": "default",
	} {
		if got := screenMode(screen); got != want {
			t.Errorf("%q: got %s, want %s", screen, got, want)
		}
	}
}
