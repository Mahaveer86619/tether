package skills

import (
	"testing"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestTasksSplitAtEachUserMessage(t *testing.T) {
	b := &builder{}
	b.user("check the sync").bash("tmux ls", true).say().
		user("and the dashboard").bash("curl -s http://127.0.0.1:8790/api/state", true).bash("tail -n 5 app.log", true)
	tasks := Tasks(Meta{Session: "s1", Node: "minipc", Cwd: "/srv"}, b.items)
	if len(tasks) != 2 || len(tasks[0].Steps) != 1 || len(tasks[1].Steps) != 2 {
		t.Fatalf("tasks: %+v", tasks)
	}
	if tasks[0].Request != "check the sync" || tasks[0].Node != "minipc" || tasks[0].Cwd != "/srv" || tasks[0].Session != "s1" {
		t.Fatalf("first task: %+v", tasks[0])
	}
}

func TestTasksSkipWhatIsNotARequestOrARoutine(t *testing.T) {
	b := &builder{}
	b.user("This continues an earlier conversation from another Claude Code session. Here it is...").bash("ls", true)
	b.add(&v1.TimelineItem{Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "queued while busy", Queued: true}}})
	b.add(&v1.TimelineItem{Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "   "}}})
	b.user("what time is it").say()
	b.user("list the repo").
		add(&v1.TimelineItem{ParentToolUseId: "sub", Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{Name: "Bash", Detail: &v1.ToolCard_Shell{Shell: &v1.ShellCard{Command: "rm -rf x"}}}}}).
		add(&v1.TimelineItem{Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{Name: "TodoWrite", Detail: &v1.ToolCard_Todos{Todos: &v1.TodoCard{}}}}}).
		bash("ls", true)
	tasks := Tasks(Meta{}, b.items)
	if len(tasks) != 2 {
		t.Fatalf("want the question and the listing, got %+v", tasks)
	}
	if tasks[0].Routine() {
		t.Fatalf("a task answered in words has no routine: %+v", tasks[0])
	}
	if got := tasks[1].Steps; len(got) != 1 || got[0].Key != "Bash:ls" {
		t.Fatalf("sub-agent items and to-do updates stay out: %+v", got)
	}
}

func TestFailedStepsAreMarked(t *testing.T) {
	tasks := uploadDiagnosis(1)
	last := tasks[0].Steps[len(tasks[0].Steps)-1]
	if !last.Failed || last.Key != "Bash:go test" {
		t.Fatalf("last step: %+v", last)
	}
}
