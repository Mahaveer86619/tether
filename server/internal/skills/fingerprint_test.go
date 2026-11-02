package skills

import (
	"math"
	"testing"
)

func fp(ts []Task) []Fingerprint {
	var out []Fingerprint
	for _, t := range ts {
		out = append(out, FingerprintOf(t))
	}
	return out
}

func TestTheSameRoutineLooksTheSameWhateverChanged(t *testing.T) {
	var runs []Fingerprint
	for i := range 5 {
		runs = append(runs, fp(syncProgress(i))...)
	}
	for i := range runs {
		for j := i + 1; j < len(runs); j++ {
			if s := Similarity(runs[i], runs[j]); s < 0.4 {
				t.Errorf("sync run %d and %d: similarity %.2f, want at least 0.4", i, j, s)
			}
		}
	}
	// Different dates, ids and numbers mask away, so the steps are identical.
	for i := 1; i < len(runs); i++ {
		if j := jaccard(runs[0].Steps, runs[i].Steps); j != 1 {
			t.Errorf("sync run %d steps differ from run 0: %v vs %v", i, runs[i].Steps, runs[0].Steps)
		}
	}
}

func TestDifferentRoutinesStayApart(t *testing.T) {
	groups := map[string][]Fingerprint{
		"sync":   {fp(syncProgress(0))[0], fp(syncProgress(2))[0]},
		"upload": {fp(uploadDiagnosis(0))[0], fp(uploadDiagnosis(2))[0]},
		"copy":   {fp(copyFile(0))[0], fp(copyFile(1))[0]},
		"rename": {fp(oneOff())[0]},
	}
	for an, a := range groups {
		for bn, b := range groups {
			if an >= bn {
				continue
			}
			for _, x := range a {
				for _, y := range b {
					if s := Similarity(x, y); s > 0.3 {
						t.Errorf("%s vs %s: similarity %.2f, want at most 0.3", an, bn, s)
					}
				}
			}
		}
	}
	for name, g := range groups {
		for i := 0; i < len(g); i++ {
			for j := i + 1; j < len(g); j++ {
				if s := Similarity(g[i], g[j]); s < 0.4 {
					t.Errorf("%s: two runs only %.2f alike", name, s)
				}
			}
		}
	}
}

func TestWordVectorIsUnitLengthAndStable(t *testing.T) {
	a := FingerprintOf(Task{Request: "check the v2 sync progress for 2026-10-18"})
	b := FingerprintOf(Task{Request: "Check the v2 sync progress for 2026-11-02"})
	var norm float64
	for _, v := range a.Words {
		norm += float64(v) * float64(v)
	}
	if math.Abs(norm-1) > 1e-5 {
		t.Fatalf("norm %v", norm)
	}
	if a.Words != b.Words {
		t.Fatal("case and dates should not change the words")
	}
	empty := FingerprintOf(Task{Request: "the a of"})
	if s := Similarity(empty, a); s != 0 {
		t.Fatalf("nothing in common with an empty request: %v", s)
	}
}
