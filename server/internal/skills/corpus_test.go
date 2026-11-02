package skills

import (
	"fmt"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// The corpus is synthetic. It copies the shape of routines the owner repeats
// (checking a long sync, diagnosing a failed upload, copying a file between
// machines) with the parts that change from run to run changed. No real
// session is read.

type builder struct {
	items []*v1.TimelineItem
	ord   uint64
}

func (b *builder) add(it *v1.TimelineItem) *builder {
	b.ord++
	it.Ord, it.ItemId = b.ord, fmt.Sprintf("i%d", b.ord)
	b.items = append(b.items, it)
	return b
}

func (b *builder) user(text string) *builder {
	return b.add(&v1.TimelineItem{Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: text}}})
}

func (b *builder) say() *builder {
	return b.add(&v1.TimelineItem{Kind: &v1.TimelineItem_Markdown{Markdown: &v1.Markdown{}}})
}

func (b *builder) bash(cmd string, ok bool) *builder {
	status := v1.ToolCard_STATUS_SUCCEEDED
	if !ok {
		status = v1.ToolCard_STATUS_FAILED
	}
	return b.add(&v1.TimelineItem{Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{
		Name: "Bash", Status: status, Detail: &v1.ToolCard_Shell{Shell: &v1.ShellCard{Command: cmd}},
	}}})
}

func (b *builder) edit(path string) *builder {
	return b.add(&v1.TimelineItem{Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{
		Name: "Edit", Status: v1.ToolCard_STATUS_SUCCEEDED, Detail: &v1.ToolCard_Edit{Edit: &v1.EditCard{Path: path}},
	}}})
}

func (b *builder) read(path string) *builder {
	return b.add(&v1.TimelineItem{Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{
		Name: "Read", Status: v1.ToolCard_STATUS_SUCCEEDED, Detail: &v1.ToolCard_Read{Read: &v1.ReadCard{Path: path}},
	}}})
}

func (b *builder) grep(pattern string) *builder {
	return b.add(&v1.TimelineItem{Kind: &v1.TimelineItem_Tool{Tool: &v1.ToolCard{
		Name: "Grep", Status: v1.ToolCard_STATUS_SUCCEEDED, Detail: &v1.ToolCard_Search{Search: &v1.SearchCard{Pattern: pattern}},
	}}})
}

// syncProgress is the owner's most repeated question, asked five ways. Each
// run finds the same things: the tmux session and its log (dated), the
// per-machine table, the dashboard.
func syncProgress(run int) []Task {
	asks := []string{
		"check the v2 sync progress",
		"how far is the localops v2 sync?",
		"progress??",
		"what is the status of the wvs v2 sync",
		"is the v2 sync still running, how many rows are done",
	}
	day := 18 + run
	b := &builder{}
	b.user(asks[run%len(asks)]).
		bash("tmux ls", true).
		bash(fmt.Sprintf("tail -n 40 ~/logs/wvs-v2-run-202610%02d.log", day), true).
		bash("pgrep -af v2sync", true).
		bash(fmt.Sprintf(`psql -h 127.0.0.1 -c "select machine, count(*) from sync_rows where state = 'waiting' and updated > '2026-10-%02d 03:00:00' group by 1"`, day), true).
		bash("curl -s http://127.0.0.1:8790/api/state", true).
		say()
	return Tasks(Meta{Session: fmt.Sprintf("s-sync-%d", run), Node: "minipc", Cwd: "/home/synlabs/development/fk-ims-wvs"}, b.items)
}

// uploadDiagnosis reads the logs and the handler for a failed CSV upload;
// the file name and the numbers differ each time.
func uploadDiagnosis(run int) []Task {
	files := []string{"MPSMISJul26_ACME LIMITED.csv", "SPS_MIS_Oct25.csv", "MPS_MIS_Dec25.csv"}
	b := &builder{}
	b.user(fmt.Sprintf("the upload of %s failed, find out why", files[run%len(files)])).
		grep("upload failed").
		bash(fmt.Sprintf("grep -n 'row %d' logs/upload.log", 1000+run*337), true).
		read("server/handlers/upload.go").
		read("service/uploads/validate.go").
		bash("go test ./service/uploads/...", run != 1)
	return Tasks(Meta{Session: fmt.Sprintf("s-upload-%d", run), Node: "laptop", Cwd: `C:\work\fk-cn`}, b.items)
}

// copyFile moves a file between the laptop and the mini PC.
func copyFile(run int) []Task {
	names := []string{"backup.tar.gz", "export.csv", "model.bin"}
	b := &builder{}
	b.user(fmt.Sprintf("copy %s from the laptop to the minipc", names[run%len(names)])).
		bash("tailscale status", true).
		bash(fmt.Sprintf("scp C:/Users/pmaha/%s synlabs@100.%d.1.%d:~/inbox/", names[run%len(names)], 100+run, 20+run), true).
		bash(fmt.Sprintf("ssh synlabs@100.%d.1.%d ls -la ~/inbox", 100+run, 20+run), true)
	return Tasks(Meta{Session: fmt.Sprintf("s-copy-%d", run), Node: "laptop", Cwd: `C:\Users\pmaha`}, b.items)
}

// oneOff is a change nobody asks for twice.
func oneOff() []Task {
	b := &builder{}
	b.user("rename the Closure Amount field to Closure Value in the billing form").
		grep("Closure Amount").
		edit("web/src/billing/Form.tsx").
		edit("web/src/billing/Form.test.tsx")
	return Tasks(Meta{Session: "s-rename", Node: "laptop", Cwd: `C:\work\fk-cn`}, b.items)
}
