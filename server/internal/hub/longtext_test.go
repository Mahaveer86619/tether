package hub

import (
	"strings"
	"testing"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestLongMessageShowsInFullInTheChat(t *testing.T) {
	h, _ := newTestHubWith(t)
	long := strings.Repeat("a long line of the message\n", 100)
	h.mu.Lock()
	note, a, err := h.fileLongText("s1", long)
	h.mu.Unlock()
	if err != nil || a == nil {
		t.Fatalf("file long text: %v", err)
	}

	// The transcript has the note plus the list of files the agent appends.
	it := &v1.TimelineItem{ItemId: "u1", Kind: &v1.TimelineItem_User{User: &v1.UserText{
		Text: note + "\n\nAttached files (in this folder):\n- .tether/attachments/" + a.Name,
	}}}
	short := &v1.TimelineItem{ItemId: "u2", Kind: &v1.TimelineItem_User{User: &v1.UserText{Text: "hi"}}}
	h.mu.Lock()
	h.expandLongText("s1", []*v1.TimelineItem{it, short})
	h.mu.Unlock()

	if u := it.GetUser(); u.Text != long || u.AttachmentId != a.Id {
		t.Fatalf("want the full message and its file, got %q (%q)", u.Text[:min(len(u.Text), 60)], u.AttachmentId)
	}
	if u := short.GetUser(); u.Text != "hi" || u.AttachmentId != "" {
		t.Fatalf("a short message should be left alone, got %v", u)
	}
}
