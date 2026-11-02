package hub

import (
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func shell(id, cmd string) *v1.TimelineItem {
	return &v1.TimelineItem{ItemId: id, Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{
		Name: "Bash", Status: v1.ToolCard_STATUS_SUCCEEDED, Detail: &v1.ToolCard_Shell{Shell: &v1.ShellCard{Command: cmd}},
	}}}
}

func TestSkillCandidatesAreListedFromStoredSessions(t *testing.T) {
	h, srv := newTestHubWith(t)
	now := time.Now().UnixMilli()
	asks := []string{"check the v2 sync progress", "what is the progress of the v2 sync??", "progress of sync"}
	for i, ask := range asks {
		id := fmt.Sprintf("sync%d", i)
		h.putSession(&v1.SessionInfo{Id: id, Node: "minipc", Cwd: "/srv/wvs", UpdatedMs: now})
		if _, _, err := h.store.PutItems(id, []*v1.TimelineItem{
			{ItemId: "u", Ord: 1, TsMs: now - int64(i)*3600_000, Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: ask}}},
			shell("a", "tmux ls"),
			shell("b", fmt.Sprintf("tail -n 40 ~/logs/run-202610%02d.log", 10+i)),
		}); err != nil {
			t.Fatal(err)
		}
	}
	res, body := request(t, "GET", srv.URL+"/api/v1/skills/candidates?days=30&runs=3", nil, nil)
	if res.StatusCode != http.StatusOK {
		t.Fatalf("status %d: %s", res.StatusCode, body)
	}
	var rep struct {
		Sessions   int
		Tasks      int
		Candidates []struct {
			Example  string
			Runs     int
			Sessions int
			Mutating bool
			Steps    []struct{ Key, Detail string }
		}
	}
	if err := json.Unmarshal(body, &rep); err != nil {
		t.Fatalf("%v: %s", err, body)
	}
	if len(rep.Candidates) != 1 {
		t.Fatalf("want the one routine: %s", body)
	}
	c := rep.Candidates[0]
	if c.Runs != 3 || c.Sessions != 3 || c.Mutating || len(c.Steps) != 2 || c.Steps[1].Detail != "tail -n 40 ~/logs/run-<date>.log" {
		t.Fatalf("candidate: %s", body)
	}
	if res, _ := request(t, "GET", srv.URL+"/api/v1/skills/candidates", nil, map[string]string{"Authorization": "Bearer nope"}); res.StatusCode != http.StatusUnauthorized {
		t.Fatalf("needs a token: %d", res.StatusCode)
	}
}
