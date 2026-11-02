package console

import (
	"reflect"
	"testing"
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
			title:    "Do you want to proceed?",
			options:  []string{"Yes", "Yes, and don't ask again for rm commands in /home/me/project", "No, and tell Claude what to do differently (esc)"},
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
			d := ParseDialog(c.screen)
			if d == nil {
				t.Fatal("no dialog found")
			}
			if d.Title != c.title || !reflect.DeepEqual(d.Options, c.options) || d.Selected != c.selected || !reflect.DeepEqual(d.Keys, c.keys) {
				t.Fatalf("got title %q options %q keys %q selected %d", d.Title, d.Options, d.Keys, d.Selected)
			}
		})
	}
}
