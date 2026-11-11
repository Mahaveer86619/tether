package hub

import (
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func cand(node, cwd string, score float64, uses int32, ago time.Duration) *v1.TargetCandidate {
	return &v1.TargetCandidate{Node: node, Cwd: cwd, Label: baseOf(cwd), Online: true, Score: score, Uses: uses, LastUsedMs: time.Now().Add(-ago).UnixMilli()}
}

func TestAutoPickBreaksATieByWhereTheOwnerWorks(t *testing.T) {
	day := 24 * time.Hour
	// "wvs" names the same repo on two machines; the laptop is where it is worked on.
	laptop := cand("laptop", `C:\Users\me\projects\work\fk-ims-wvs`, 3, 6, 2*day)
	minipc := cand("minipc", "/home/me/development/fk-ims-wvs", 3, 2, 3*day)
	if got := autoPick([]*v1.TargetCandidate{laptop, minipc}); got != laptop {
		t.Errorf("a repo used three times as much should win the tie, got %v", got)
	}

	// Used about equally: still ambiguous, so Claude works it out.
	minipc.Uses = 5
	if got := autoPick([]*v1.TargetCandidate{laptop, minipc}); got != nil {
		t.Errorf("a close call should not be decided by the hub, got %v", got)
	}

	// One used this week, the other not for two months.
	stale := cand("minipc", "/home/me/old/fk-ims-wvs", 3, 1, 70*day)
	fresh := cand("laptop", `C:\Users\me\fk-ims-wvs`, 3, 1, 1*day)
	if got := autoPick([]*v1.TargetCandidate{fresh, stale}); got != fresh {
		t.Errorf("the recent one should win, got %v", got)
	}

	// A better match always beats a busier folder.
	exact := cand("laptop", `C:\Users\me\tether`, 10, 1, 40*day)
	busy := cand("laptop", `C:\Users\me\other`, 3, 50, 0)
	if got := autoPick([]*v1.TargetCandidate{exact, busy}); got != exact {
		t.Errorf("score first, usage second, got %v", got)
	}
}

func TestFoldersThatAreNotProjects(t *testing.T) {
	for cwd, want := range map[string]bool{
		`C:\Users\me\AppData\Roaming\Claude\scratch-workspaces\x`: true,
		`/home/me/.tether/scratch/abc`:                            true,
		`C:\Users\me\projects\tether`:                             false,
		`/home/me/development/fk-ims-wvs`:                         false,
	} {
		if got := notAProject(cwd); got != want {
			t.Errorf("notAProject(%q) = %v", cwd, got)
		}
	}
	for cwd, want := range map[string]string{
		`C:\Users\me`:                   "Home folder",
		`C:\Users\me\`:                  "Home folder",
		"/home/me":                      "Home folder",
		"/Users/me":                     "Home folder",
		`C:\Users\me\projects\tether`:   "tether",
		"/home/me/development/fk-cn":    "fk-cn",
		`C:\Users\me\projects\personal`: "personal",
	} {
		if got := labelOf(cwd); got != want {
			t.Errorf("labelOf(%q) = %q, want %q", cwd, got, want)
		}
	}
}

func TestAPromptNamingARepoPicksIt(t *testing.T) {
	words := wordsOf("why do the router-traffic-fw tests fail on the wvs sync")
	text := " " + "why do the router traffic fw tests fail on the wvs sync" + " "
	for cwd, wantHit := range map[string]bool{
		`C:\Users\me\projects\work\GitHub\router-traffic-fw`: true,
		`C:\Users\me\projects\work\GitHub\fk-ims-wvs`:        true,
		`C:\Users\me\projects\personal\tether`:               false,
		`C:\Users\me`:                                        false,
	} {
		score, _ := matchScore(cwd, words, text)
		if (score >= scorePick) != wantHit {
			t.Errorf("%s scored %v", cwd, score)
		}
	}
}
