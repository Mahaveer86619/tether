package skills

import (
	"fmt"
	"testing"
)

const day = int64(24 * 3600 * 1000)

// stamp gives runs of a routine start times, one a day apart.
func stamp(ts []Task, ms int64) []Task {
	for i := range ts {
		ts[i].StartMs = ms
	}
	return ts
}

func corpus(now int64) []Task {
	var all []Task
	for i := range 5 {
		all = append(all, stamp(syncProgress(i), now-int64(i)*day)...)
	}
	for i := range 3 {
		all = append(all, stamp(uploadDiagnosis(i), now-int64(10+i)*day)...)
	}
	for i := range 2 {
		all = append(all, stamp(copyFile(i), now-int64(3+i)*day)...)
	}
	all = append(all, stamp(oneOff(), now-day)...)
	return all
}

func TestClusterFindsTheRoutinesThatComeBack(t *testing.T) {
	now := 100 * day
	got := Cluster(corpus(now), DefaultOptions(now))
	if len(got) != 2 {
		t.Fatalf("want the sync check and the upload diagnosis, got %d: %+v", len(got), summary(got))
	}
	sync, upload := got[0], got[1]
	if len(sync.Runs) != 5 || sync.Sessions != 5 || sync.Nodes[0] != "minipc" {
		t.Fatalf("sync candidate: %+v", summary(got))
	}
	if sync.Mutating {
		t.Fatal("checking progress only looks, so it is not a mutating routine")
	}
	var keys []string
	for _, s := range sync.Steps {
		keys = append(keys, s.Key)
	}
	want := []string{"Bash:tmux ls", "Bash:tail", "Bash:pgrep", "Bash:psql", "Bash:curl"}
	if fmt.Sprint(keys) != fmt.Sprint(want) {
		t.Fatalf("sync steps %v, want %v", keys, want)
	}
	if sync.Steps[1].Detail != "tail -n 40 ~/logs/wvs-v2-run-<date>.log" {
		t.Fatalf("a step keeps its masked command: %q", sync.Steps[1].Detail)
	}
	if len(upload.Runs) != 3 || upload.Nodes[0] != "laptop" {
		t.Fatalf("upload candidate: %+v", summary(got))
	}
}

func TestClusterLeavesOutTwoRunsAndOneOffs(t *testing.T) {
	now := 100 * day
	for _, c := range Cluster(corpus(now), DefaultOptions(now)) {
		if c.Steps[0].Key == "Bash:tailscale status" || c.Steps[0].Key == "Grep" && c.Example == "rename the Closure Amount field to Closure Value in the billing form" {
			t.Fatalf("%q should not be a candidate", c.Example)
		}
	}
}

func TestClusterOnlyCountsTheWindow(t *testing.T) {
	now := 100 * day
	var old []Task
	for i := range 5 {
		old = append(old, stamp(syncProgress(i), now-int64(40+i)*day)...)
	}
	if got := Cluster(old, DefaultOptions(now)); len(got) != 0 {
		t.Fatalf("runs from 40 days ago are outside the 30-day window: %+v", summary(got))
	}
	if got := Cluster(old, Options{Similar: 0.45, MinRuns: 3, MinClean: 0.6}); len(got) != 1 {
		t.Fatalf("without a window they count: %+v", summary(got))
	}
}

func TestClusterDropsRoutinesThatMostlyFail(t *testing.T) {
	now := 100 * day
	var failing []Task
	for i := range 4 {
		ts := stamp(uploadDiagnosis(1), now-int64(i)*day) // this run's last step fails
		ts[0].Session = fmt.Sprintf("f%d", i)
		failing = append(failing, ts...)
	}
	if got := Cluster(failing, DefaultOptions(now)); len(got) != 0 {
		t.Fatalf("a routine that keeps failing is not one to save: %+v", summary(got))
	}
}

// The real history has many unrelated tasks that all use grep, sed and python;
// that must not make them one routine.
func TestClusterIgnoresUnrelatedWorkThatSharesCommonCommands(t *testing.T) {
	now := 100 * day
	reqs := []string{
		"rename the closure amount field in the billing form", "make the codeblocks colourful in the app",
		"add a settings screen for themes", "fix the nil pointer when the server starts", "write the release notes for the new build",
	}
	var all []Task
	for i, r := range reqs {
		b := &builder{}
		b.user(r).bash("grep -rn foo .", true).bash("sed -n 1,40p x.go", true).bash("python - <<'EOF'", true).edit("a.go")
		all = append(all, stamp(Tasks(Meta{Session: fmt.Sprintf("u%d", i)}, b.items), now-int64(i)*day)...)
	}
	if got := Cluster(all, DefaultOptions(now)); len(got) != 0 {
		t.Fatalf("different requests are not one routine: %+v", summary(got))
	}
}

func TestClusterCountsARequestOnceWhenAForkCopiedIt(t *testing.T) {
	now := 100 * day
	var all []Task
	for i := range 2 {
		// Two sessions with the same history, as after a fork or a move.
		for run := range 2 {
			ts := syncProgress(run)
			ts[0].Session = fmt.Sprintf("copy%d", i)
			all = append(all, stamp(ts, now-int64(run)*day)...)
		}
	}
	if got := Cluster(all, DefaultOptions(now)); len(got) != 0 {
		t.Fatalf("two real runs, each copied once, are still two runs: %+v", summary(got))
	}
}

func TestClusterIgnoresFollowUps(t *testing.T) {
	now := 100 * day
	var all []Task
	for i, r := range []string{"yes start", "check again.", "ok go ahead", "yes", "continue"} {
		b := &builder{}
		b.user(r).bash("tmux ls", true).bash("tail -n 40 app.log", true)
		all = append(all, stamp(Tasks(Meta{Session: fmt.Sprintf("f%d", i)}, b.items), now-int64(i)*day)...)
	}
	if got := Cluster(all, DefaultOptions(now)); len(got) != 0 {
		t.Fatalf("an answer is not a request: %+v", summary(got))
	}
}

func TestClusterIsOrderIndependent(t *testing.T) {
	now := 100 * day
	a := corpus(now)
	b := make([]Task, len(a))
	for i := range a {
		b[len(a)-1-i] = a[i]
	}
	x, y := Cluster(a, DefaultOptions(now)), Cluster(b, DefaultOptions(now))
	if len(x) != len(y) || len(x[0].Runs) != len(y[0].Runs) || len(x[1].Runs) != len(y[1].Runs) {
		t.Fatalf("order changed the result: %v vs %v", summary(x), summary(y))
	}
}

func summary(cs []Candidate) []string {
	var out []string
	for _, c := range cs {
		out = append(out, fmt.Sprintf("%d runs: %s", len(c.Runs), c.Example))
	}
	return out
}
