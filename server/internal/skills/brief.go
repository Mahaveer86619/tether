package skills

import (
	"fmt"
	"strings"
)

// DraftBrief is what a session is told to write a skill from a routine. The
// session sees only what the hub kept of the runs: the requests and the steps,
// with ids, dates and addresses already masked.
func DraftBrief(c Candidate) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Write a Tether skill from a routine the user keeps asking for. It was asked %d times in %d sessions", len(c.Runs), c.Sessions)
	if len(c.Nodes) > 0 {
		fmt.Fprintf(&b, ", mostly on %s", c.Nodes[0])
	}
	b.WriteString(".\n\nHow it was asked:\n")
	for i, t := range c.Runs {
		if i == 6 {
			break
		}
		fmt.Fprintf(&b, "- %q\n", oneLine(t.Request))
	}
	b.WriteString("\nThe steps most runs took, in order. Ids, dates, times, addresses and big numbers are shown as <id>, <date>, <time>, <ip> and <n>: they changed every run, so the skill should say how to find the right value, not copy one.\n")
	for _, s := range c.Steps {
		label := "read-only"
		if s.Mutating {
			label = "CHANGES THINGS"
		}
		fmt.Fprintf(&b, "- (%s, %.0f%% of runs) %s\n", label, s.Share*100, s.Detail)
	}
	if len(c.Steps) == 0 {
		b.WriteString("- (no step was common to most runs: the runs were worded alike but done differently, so describe what they have in common and leave the commands to Claude)\n")
	}
	b.WriteString(`
Write the skill as a SKILL.md and save it with the tether tool propose_skill (skill_md, mutating, source). Then stop; the user reviews it in the Tether app.

The file:
- Starts with front matter: ---, name: (lower case, dashes, at most 40 characters), description: (one or two sentences that say WHEN to use it, in the words the user uses), ---.
- Then the steps, numbered. Say what each step is for, what a good result looks like, and what to look at when it doesn't. Mark every step "Read-only" or "Changes things"; a step that changes something must say to confirm with the user first.
- Name the parameters (what changes from run to run) and how to find each one.
- End with what to report back: a short table or list, in plain words.
- Never put a password, token, key or connection string in it. Say where to read it from instead.
- If a step fails or its output is not what the skill says, tell Claude to fix the skill with update_skill, with a note on what was wrong.
- Keep it short: under 80 lines.

Set mutating to true if any step changes something. Set source to the example request: `)
	fmt.Fprintf(&b, "%q.\n\nYou are on Tether's hub machine, not where the routine runs. Do not run the steps; only write the skill.\n", oneLine(c.Example))
	return b.String()
}
