package skills

import (
	"strings"
	"testing"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

const scriptSkill = `---
name: check-prod-import
description: Use when asked whether last night's import reached the production database.
needs_env: [DB_URL, DB_SCHEMA]
runs_on: minipc
effect: read
scripts:
  - .tether/skills/check-prod-import/check.py
---
# Steps
1. Read-only: run python .tether/skills/check-prod-import/check.py with DB_URL from the project's .env.
2. Read-only: compare the row count with yesterday's and report both numbers.
`

const checkScript = `import os, psycopg
conn = psycopg.connect(os.environ["DB_URL"])
password = os.environ.get("DB_PASSWORD")
print(conn.execute("select count(*) from imports").fetchone())
`

func TestScriptSkillFrontMatterIsParsedAndValidated(t *testing.T) {
	p, err := Validate(scriptSkill)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Join(p.NeedsEnv, ",") != "DB_URL,DB_SCHEMA" || p.RunsOn != "minipc" || p.Effect != "read" ||
		len(p.Scripts) != 1 || p.Scripts[0] != ".tether/skills/check-prod-import/check.py" {
		t.Fatalf("parsed: %+v", p)
	}
	inline, _ := ParseSkill(strings.Replace(scriptSkill, "scripts:\n  - .tether/skills/check-prod-import/check.py", "scripts: [scripts/a.sh, './scripts/b.sh']", 1))
	if strings.Join(inline.Scripts, ",") != "scripts/a.sh,./scripts/b.sh" {
		t.Fatalf("inline list: %v", inline.Scripts)
	}
	bad := map[string]string{
		"env value":       strings.Replace(scriptSkill, "[DB_URL, DB_SCHEMA]", "[DB_URL=postgres://db/wvs]", 1),
		"env with pass":   strings.Replace(scriptSkill, "[DB_URL, DB_SCHEMA]", "[DB_URL, DB_PASSWORD=hunter2hunter2]", 1),
		"bad effect":      strings.Replace(scriptSkill, "effect: read", "effect: maybe", 1),
		"no effect":       strings.Replace(scriptSkill, "effect: read\n", "", 1),
		"absolute script": strings.Replace(scriptSkill, "  - .tether/", "  - /etc/", 1),
		"escaping script": strings.Replace(scriptSkill, "  - .tether/", "  - ../", 1),
		"bad runs_on":     strings.Replace(scriptSkill, "runs_on: minipc", "runs_on: two machines", 1),
	}
	for name, md := range bad {
		if _, err := Validate(md); err == nil {
			t.Errorf("%s: should be refused", name)
		}
	}
}

func TestAScriptWithASecretIsRefused(t *testing.T) {
	if err := ValidateScript("check.py", checkScript); err != nil {
		t.Fatalf("reading credentials from the environment is fine: %v", err)
	}
	for name, script := range map[string]string{
		"env password": "export DB_PASSWORD=hunter2hunter2\npsql -c 'select 1'",
		"dotenv token": "API_TOKEN='abcd1234efgh5678'\n",
		"url with pass": "conn = connect('postgres://admin:s3cretpass@db/wvs')",
		"json secret":  `{"client_secret": "abcdefgh12345678"}`,
		"aws key":      "AWS_ACCESS_KEY_ID=AKIAABCDEFGHIJKLMNOP",
	} {
		if err := ValidateScript("x", script); err == nil {
			t.Errorf("%s: should be refused", name)
		}
	}
	l := NewLibrary(memKV{})
	if _, err := l.ProposeWith(scriptSkill, map[string]string{".tether/skills/check-prod-import/check.py": checkScript + "\nTOKEN=abcd1234efgh5678\n"}, false, "x", "claude", 1); err == nil {
		t.Fatal("a skill whose script holds a secret is refused")
	}
	if _, err := l.ProposeWith(scriptSkill, nil, false, "x", "claude", 1); err == nil || !strings.Contains(err.Error(), "send the contents") {
		t.Fatalf("a listed script must be sent so it can be hashed: %v", err)
	}
	if _, err := l.ProposeWith(scriptSkill, map[string]string{".tether/skills/check-prod-import/check.py": checkScript, "other.sh": "echo hi"}, false, "x", "claude", 1); err == nil {
		t.Fatal("a script the front matter doesn't list is refused")
	}
}

func TestAChangedScriptFlagsTheSkill(t *testing.T) {
	const path = ".tether/skills/check-prod-import/check.py"
	l := NewLibrary(memKV{})
	s, err := l.ProposeWith(scriptSkill, map[string]string{path: checkScript}, false, "is the import in?", "claude", 1)
	if err != nil {
		t.Fatal(err)
	}
	if len(s.Scripts) != 1 || s.Scripts[0].Sha256 != Hash(checkScript) || s.Effect != "read" || s.RunsOn != "minipc" {
		t.Fatalf("the hash and the declarations are kept: %+v", s)
	}
	if _, err := l.Approve(s.Name, 2); err != nil {
		t.Fatal(err)
	}
	if changed, err := l.CheckScripts(s.Name, map[string]string{path: Hash(checkScript)}, 3); err != nil || len(changed) != 0 {
		t.Fatalf("unchanged: %v %v", changed, err)
	}
	edited := checkScript + "print('more')\n"
	changed, err := l.CheckScripts(s.Name, map[string]string{"./" + path: strings.ToUpper(Hash(edited))}, 4)
	if err != nil || len(changed) != 1 || changed[0] != path {
		t.Fatalf("changed: %v %v", changed, err)
	}
	if s, _ = l.Get(s.Name); !s.NeedsReview() {
		t.Fatal("the skill is flagged for review")
	}
	if changed, _ := l.CheckScripts(s.Name, nil, 5); len(changed) != 1 {
		t.Fatal("a check that doesn't mention the script keeps the flag")
	}
	// A correction to the text alone doesn't clear it.
	if s, err = l.UpdateWith(s.Name, scriptSkill+"\nReport the newest import's time too.\n", nil, "report the time", "claude", 6); err != nil || !s.NeedsReview() {
		t.Fatalf("text update: %+v %v", s, err)
	}
	// Nor does sending the new script: the owner approves a script change.
	if s, err = l.UpdateWith(s.Name, scriptSkill, map[string]string{path: edited}, "new script", "claude", 7); err != nil || !s.NeedsReview() || s.Scripts[0].Sha256 != Hash(checkScript) {
		t.Fatalf("script update waits for the owner: %+v %v", s, err)
	}
	if s, err = l.Approve(s.Name, 8); err != nil || s.NeedsReview() || s.Scripts[0].Sha256 != Hash(edited) {
		t.Fatalf("approving accepts the new script: %+v %v", s, err)
	}
	if changed, _ := l.CheckScripts(s.Name, map[string]string{path: Hash(edited)}, 9); len(changed) != 0 {
		t.Fatalf("the accepted script matches: %v", changed)
	}
}

func TestSearchFindsTheExpectedSkillInTheTopThree(t *testing.T) {
	list := []Skill{
		{Name: "v2-sync-progress", Description: "Use when asked how far the v2 sync is on the mini PC", Source: "how far is the v2 sync"},
		{Name: "build-android-apk", Description: "Build the Android app and report the APK path", Source: "build the apk for the phone"},
		{Name: "weekly-report", Description: "Summarise the week's commits into a report", Source: "write the weekly commit report"},
		{Name: "check-prod-import", Description: "Use when asked whether last night's import reached the production database", Source: "did the import land in prod"},
		{Name: "upload-diagnosis", Description: "Diagnose a failed CSV upload in the billing pipeline", Source: "why did my csv upload fail"},
		{Name: "copy-to-minipc", Description: "Copy a file from the laptop to the mini PC over the tailnet", Source: "copy this file to the mini pc"},
		{Name: "advertise-host", Description: "Add a host to the router's advertised routes list", Source: "add this to the advertise list"},
		{Name: "resume-build", Description: "Build the resume PDF from LaTeX", Source: "build my resume"},
	}
	cases := map[string]string{
		"sync":                       "v2-sync-progress",
		"syn":                        "v2-sync-progress",
		"prod database":              "check-prod-import",
		"import":                     "check-prod-import",
		"csv":                        "upload-diagnosis",
		"upload failed":              "upload-diagnosis",
		"copy file":                  "copy-to-minipc",
		"apk":                        "build-android-apk",
		"advertise":                  "advertise-host",
		"resume pdf":                 "resume-build",
		"commit report for the week": "weekly-report",
	}
	for q, want := range cases {
		got := Search(q, list, 3)
		found := false
		for _, m := range got {
			if m.Skill.Name == want {
				found = true
				if m.Reason() == "" || !strings.HasPrefix(m.Reason(), "shares ") {
					t.Errorf("%q: a match says why: %q", q, m.Reason())
				}
			}
		}
		if !found {
			t.Errorf("%q: %s not in the top three: %v", q, want, names(got))
		}
	}
	if got := Search("the capital of France", list, 3); len(got) != 0 {
		t.Errorf("unrelated: %v", names(got))
	}
	if got := Search("", list, 3); got != nil {
		t.Errorf("empty: %v", names(got))
	}
	if r := Search("prod import", list, 1)[0].Reason(); !strings.Contains(r, "prod") || !strings.Contains(r, "import") {
		t.Errorf("the reason names the shared words: %q", r)
	}
}

func names(ms []Match) []string {
	var out []string
	for _, m := range ms {
		out = append(out, m.Skill.Name)
	}
	return out
}

func TestTaskAtFindsTheStretchAroundAnItem(t *testing.T) {
	user := func(id string, ord uint64, text string) *v1.TimelineItem {
		return &v1.TimelineItem{ItemId: id, Ord: ord, Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: text}}}
	}
	shellAt := func(id string, ord uint64, cmd string) *v1.TimelineItem {
		return &v1.TimelineItem{ItemId: id, Ord: ord, Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{Name: "Bash", Detail: &v1.ToolCard_Shell{Shell: &v1.ShellCard{Command: cmd}}}}}
	}
	items := []*v1.TimelineItem{
		user("u1", 1, "hello"),
		shellAt("a", 2, "ls"),
		user("u2", 3, "did the import land in prod?"),
		shellAt("b", 4, `psql "$DB_URL" -c 'select count(*) from imports'`),
		shellAt("c", 5, "date"),
		user("u3", 6, "thanks"),
	}
	m := Meta{Session: "s", Node: "minipc", Cwd: "/srv/wh"}
	for _, id := range []string{"u2", "b", "c"} {
		task, ok := TaskAt(m, items, id)
		if !ok || task.Request != "did the import land in prod?" || len(task.Steps) != 2 {
			t.Fatalf("%s: %+v %v", id, task, ok)
		}
	}
	if _, ok := TaskAt(m, items, "nope"); ok {
		t.Fatal("unknown item")
	}
	task, _ := TaskAt(m, items, "b")
	c := FromTask(task)
	if !IsScript(c) || c.Nodes[0] != "minipc" || c.Cwds[0] != "/srv/wh" {
		t.Fatalf("a psql routine is a script: %+v", c)
	}
	brief := DraftBrief(c, DraftInProject)
	for _, want := range []string{"saved from a chat", "needs_env", ".tether/skills/<name>/", "scripts: {path", "Do not write any .env", "You are in the project"} {
		if !strings.Contains(brief, want) {
			t.Errorf("the script brief lacks %q:\n%s", want, brief)
		}
	}
	if IsScript(FromTask(Task{Request: "x", Steps: []Step{{Key: "Bash:ls", Detail: "ls -la"}}})) {
		t.Error("ls is not a script routine")
	}
}
