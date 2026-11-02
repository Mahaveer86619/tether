package skills

import (
	"errors"
	"strings"
	"testing"
)

type memKV map[string][]byte

func (m memKV) Get(k string) ([]byte, error) { return m[k], nil }
func (m memKV) Put(k string, v []byte) error { m[k] = v; return nil }

const goodSkill = `---
name: v2-sync-progress
description: Use when asked how far the v2 sync is, or "progress?" about the WVS sync on the mini PC.
---
# Steps
1. Read-only: run tmux ls and check that wvs-v2 is listed.
2. Read-only: tail the newest log under ~/logs and note the last pass.
3. Read-only: ask the dashboard for its state and read the per-machine table.
Report rows handled out of the total, images saved, the speed, and which machines are stuck.
`

func TestParseSkillReadsTheFrontMatter(t *testing.T) {
	p, err := ParseSkill(goodSkill)
	if err != nil || p.Name != "v2-sync-progress" || !strings.HasPrefix(p.Description, "Use when asked") || !strings.HasPrefix(p.Body, "# Steps") {
		t.Fatalf("%+v %v", p, err)
	}
	if _, err := ParseSkill("# no front matter"); err == nil {
		t.Fatal("front matter is required")
	}
	if _, err := ParseSkill("---\nname: x\nno end"); err == nil {
		t.Fatal("the front matter must close")
	}
	if p, _ := ParseSkill("---\r\nname: \"quoted\"\r\ndescription: 'ok then'\r\n---\r\nbody"); p.Name != "quoted" || p.Description != "ok then" {
		t.Fatalf("quotes and CRLF: %+v", p)
	}
}

func TestValidateRefusesWhatShouldNotBeKept(t *testing.T) {
	bad := map[string]string{
		"bad name":      strings.Replace(goodSkill, "v2-sync-progress", "V2 Sync!", 1),
		"short desc":    strings.Replace(goodSkill, `Use when asked how far the v2 sync is, or "progress?" about the WVS sync on the mini PC.`, "sync", 1),
		"no steps":      "---\nname: empty-one\ndescription: Use when something happens that needs a skill.\n---\nok",
		"private key":   goodSkill + "\n-----BEGIN RSA PRIVATE KEY-----\n",
		"aws key":       goodSkill + "\nkey AKIAABCDEFGHIJKLMNOP\n",
		"password":      goodSkill + "\npassword=hunter2hunter2\n",
		"api token":     goodSkill + "\nAPI_KEY: abcd1234efgh5678\n",
		"bearer":        goodSkill + "\ncurl -H 'Authorization: Bearer abcdefghijklmnopqrstuvwx'\n",
		"url with pass": goodSkill + "\npsql postgres://admin:s3cretpass@db/wvs\n",
		"too big":       goodSkill + strings.Repeat("x ", 12<<10),
	}
	for name, md := range bad {
		if _, err := Validate(md); err == nil {
			t.Errorf("%s: should be refused", name)
		}
	}
	if _, err := Validate(goodSkill); err != nil {
		t.Fatalf("a good skill: %v", err)
	}
	// Naming where a secret lives is fine.
	ok := goodSkill + "\nThe token is in ~/tether/tether.env as TETHER_TOKEN; read it from there, set TOKEN=$TETHER_TOKEN.\n"
	if _, err := Validate(ok); err != nil {
		t.Fatalf("naming the place of a secret: %v", err)
	}
}

func TestSkillLifecycle(t *testing.T) {
	l := NewLibrary(memKV{})
	s, err := l.Propose(goodSkill, false, "progress?", "claude", 100)
	if err != nil || s.Status != "proposed" || s.Latest().N != 1 {
		t.Fatalf("propose: %+v %v", s, err)
	}
	if active, _ := l.Active(); len(active) != 0 {
		t.Fatal("a proposal is not usable until approved")
	}
	if _, err := l.Propose(goodSkill, false, "x", "claude", 101); !errors.Is(err, ErrExists) {
		t.Fatalf("same name twice: %v", err)
	}
	if _, err := l.Approve("v2-sync-progress", 200); err != nil {
		t.Fatal(err)
	}
	if active, _ := l.Active(); len(active) != 1 || active[0].Name != "v2-sync-progress" {
		t.Fatalf("active: %+v", active)
	}

	fixed := strings.Replace(goodSkill, "tail the newest log", "tail -n 60 the newest log", 1)
	s, err = l.Update("v2-sync-progress", fixed, "tail showed too little", "claude", 300)
	if err != nil || len(s.Versions) != 2 || s.Latest().Note != "tail showed too little" || s.Status != "active" {
		t.Fatalf("update: %+v %v", s, err)
	}
	if s, _ = l.Update("v2-sync-progress", fixed, "again", "claude", 301); len(s.Versions) != 2 {
		t.Fatal("the same text is not a new version")
	}
	if _, err := l.Update("v2-sync-progress", strings.Replace(fixed, "v2-sync-progress", "other-name", 1), "x", "claude", 302); err == nil {
		t.Fatal("a skill can't be renamed by an update")
	}
	if _, err := l.Update("v2-sync-progress", fixed+"\npassword=hunter2hunter2", "x", "claude", 303); err == nil {
		t.Fatal("a correction is checked like the first draft")
	}

	s, err = l.Rollback("v2-sync-progress", 1, "owner", 400)
	if err != nil || len(s.Versions) != 3 || s.Latest().MD != strings.TrimSpace(goodSkill) || s.Latest().Note != "back to version 1" {
		t.Fatalf("rollback keeps the history and adds a version: %+v %v", s, err)
	}
	if _, err := l.Rollback("v2-sync-progress", 9, "owner", 401); err == nil {
		t.Fatal("no such version")
	}
}

func TestDismissedSkillsAreHiddenAndNotProposedAgain(t *testing.T) {
	l := NewLibrary(memKV{})
	if _, err := l.Propose(goodSkill, false, "progress?", "claude", 1); err != nil {
		t.Fatal(err)
	}
	if _, err := l.Dismiss("v2-sync-progress", 2); err != nil {
		t.Fatal(err)
	}
	if all, _ := l.List(); len(all) != 0 {
		t.Fatalf("dismissed skills are not listed: %+v", all)
	}
	if _, err := l.Propose(goodSkill, false, "progress?", "claude", 3); !errors.Is(err, ErrExists) {
		t.Fatalf("the owner said no: %v", err)
	}
	if _, err := l.Update("v2-sync-progress", goodSkill+"\nmore steps here and there", "x", "claude", 4); !errors.Is(err, ErrNotFound) {
		t.Fatalf("a dismissed skill can't be updated: %v", err)
	}
	if _, err := l.Get("nope"); !errors.Is(err, ErrNotFound) {
		t.Fatal("unknown skill")
	}
}

func TestDraftBriefCarriesTheEvidenceAndTheRules(t *testing.T) {
	now := 100 * day
	cands := Cluster(corpus(now), DefaultOptions(now))
	brief := DraftBrief(cands[0])
	for _, want := range []string{
		"asked 5 times in 5 sessions", "mostly on minipc", "check the v2 sync progress", "wvs-v2-run-<date>.log",
		"(read-only, 100% of runs) tmux ls", "propose_skill", "update_skill", "Never put a password", "Do not run the steps",
	} {
		if !strings.Contains(brief, want) {
			t.Errorf("the brief lacks %q:\n%s", want, brief)
		}
	}
	// A routine with changing steps says so, in capitals.
	changing := DraftBrief(Candidate{Example: "copy a file", Runs: make([]Task, 3), Sessions: 2, Steps: []CommonStep{{Key: "Bash:scp", Detail: "scp a b", Mutating: true, Share: 1}}})
	if !strings.Contains(changing, "CHANGES THINGS") {
		t.Errorf("changing steps must stand out:\n%s", changing)
	}
}
