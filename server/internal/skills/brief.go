package skills

import (
	"fmt"
	"regexp"
	"strings"
)

// Where a drafting session runs: on the hub with nothing but the brief, or in
// the project the routine ran in, where it can write a script.
const (
	DraftOnHub = iota
	DraftInProject
)

// scriptLike are commands that reach a database or a service, or run a
// project script, usually with credentials from the environment: a routine
// made of them is best kept as a script the skill runs.
var scriptLike = regexp.MustCompile(`(?i)(^|[\s;|&(])(psql|mysql|mariadb|mongosh|mongo|redis-cli|sqlite3|clickhouse-client|cqlsh|bq|snowsql|aws|gcloud|az|kubectl|python3?|node|deno|bun|go run|ts-node)(\s|$)|\$\{?[A-Z][A-Z0-9_]*(URL|DSN|HOST|USER|PASS\w*|TOKEN|KEY)\b`)

// IsScript reports whether a routine is a custom command against a database
// or a service, so its skill should carry a script.
func IsScript(c Candidate) bool {
	for _, s := range c.Steps {
		if strings.HasPrefix(s.Key, "Bash:") && scriptLike.MatchString(s.Detail) {
			return true
		}
	}
	return false
}

// DraftBrief is what a session is told to write a skill from a routine. The
// session sees only what the hub kept of the runs: the requests and the steps,
// with ids, dates and addresses already masked. where is DraftOnHub or
// DraftInProject.
func DraftBrief(c Candidate, where int) string {
	var b strings.Builder
	if len(c.Runs) <= 1 {
		b.WriteString("Write a Tether skill from a task the user did once and saved from a chat, so it can be repeated")
	} else {
		fmt.Fprintf(&b, "Write a Tether skill from a routine the user keeps asking for. It was asked %d times in %d sessions", len(c.Runs), c.Sessions)
	}
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
	fmt.Fprintf(&b, "%q.\n", oneLine(c.Example))
	script := IsScript(c)
	if script && where == DraftInProject {
		b.WriteString(`
This routine is a custom command against a database or a service, so make it a script skill:
- Write the command as a script in this project, at .tether/skills/<name>/ (or under scripts/ if the project keeps its scripts there). It reads every credential and address from environment variables (os.environ, $DB_URL and the like) and never contains a password, token, key or connection string with a password in it. Do not write any .env file.
- Add to the front matter: needs_env: [the variable names, never their values], effect: read or write (write if it changes anything), runs_on: the device it must run on, or any, and scripts: [the script paths, relative to the project].
- The steps say how to run the script and that the variables come from the project's .env (Tether keeps it sealed for allowed devices) or the device's environment.
- Pass the scripts to propose_skill as scripts: {path: the script's full contents}, so Tether keeps a hash of each and notices when one changes.
- Do not run the script or the routine's commands; only write the script and the skill.
`)
	} else if script {
		b.WriteString("\nThis routine is a custom command against a database or a service. Write the command into the steps, reading every credential and address from environment variables, and list them under needs_env: [names only] in the front matter, with effect: read or write.\n")
	}
	if where == DraftInProject {
		b.WriteString("\nYou are in the project where the routine runs. Do not run the steps; only write the skill.\n")
	} else {
		b.WriteString("\nYou are on Tether's hub machine, not where the routine runs. Do not run the steps; only write the skill.\n")
	}
	return b.String()
}
