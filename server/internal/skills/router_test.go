package skills

import "testing"

func TestRankPicksTheSkillThatFitsAndNothingForStrangers(t *testing.T) {
	list := []Skill{
		{Name: "v2-sync-progress", Description: "Use when asked how far the v2 sync is", Source: "how far is the v2 sync"},
		{Name: "build-android-apk", Description: "Build the Android app and report the APK path", Source: "build the apk for the phone"},
		{Name: "weekly-report", Description: "Summarise the week's commits into a report", Source: "write the weekly commit report"},
	}
	cases := []struct{ request, want string }{
		{"how far along is the v2 sync now?", "v2-sync-progress"},
		{"please build a new apk", "build-android-apk"},
		{"write me this week's commit report", "weekly-report"},
	}
	for _, c := range cases {
		got := Rank(c.request, list, 3)
		if len(got) == 0 || got[0].Skill.Name != c.want {
			t.Errorf("%q: got %v, want %s first", c.request, got, c.want)
		}
	}
	if got := Rank("what is the capital of France", list, 3); len(got) != 0 {
		t.Errorf("an unrelated request matched %v", got)
	}
	if got := Rank("build report", list, 1); len(got) != 1 {
		t.Errorf("k=1 gave %d", len(got))
	}
	if got := Rank("", list, 3); got != nil {
		t.Errorf("empty request matched %v", got)
	}
}
