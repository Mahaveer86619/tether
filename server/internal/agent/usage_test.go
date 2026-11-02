package agent

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestIndexReadsTokenUsage(t *testing.T) {
	dir := t.TempDir()
	project := filepath.Join(dir, "proj")
	if err := os.MkdirAll(project, 0o755); err != nil {
		t.Fatal(err)
	}
	lines := []string{
		`{"type":"user","timestamp":"2026-10-11T10:00:00Z","message":{"content":"hi"}}`,
		// One message over two lines: the second carries the final output count.
		`{"type":"assistant","timestamp":"2026-10-11T10:00:01Z","message":{"id":"m1","model":"claude-opus-5-5","content":[],"usage":{"input_tokens":10,"output_tokens":2,"cache_read_input_tokens":500}}}`,
		`{"type":"assistant","timestamp":"2026-10-11T10:00:02Z","message":{"id":"m1","model":"claude-opus-5-5","content":[],"usage":{"input_tokens":10,"output_tokens":40,"cache_read_input_tokens":500}}}`,
		`{"type":"assistant","isSidechain":true,"timestamp":"2026-10-11T10:00:03Z","message":{"id":"m2","model":"claude-haiku-5-5","content":[],"usage":{"input_tokens":3,"output_tokens":4}}}`,
		`{"type":"assistant","timestamp":"2026-10-11T10:00:04Z","message":{"id":"m3","model":"<synthetic>","content":[],"usage":{"input_tokens":0,"output_tokens":0}}}`,
	}
	if err := os.WriteFile(filepath.Join(project, "s1.jsonl"), []byte(strings.Join(lines, "\n")+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	ix := NewIndex(dir)
	if _, err := ix.Scan(); err != nil {
		t.Fatal(err)
	}
	got := map[string]int64{}
	for _, u := range ix.TakeUsage(false) {
		if u.Session != "s1" {
			t.Errorf("session %q", u.Session)
		}
		got[u.MessageId] = u.Output
	}
	if len(got) != 2 || got["m1"] != 40 || got["m2"] != 4 {
		t.Fatalf("usage: %v (want m1 once with its final count, the sub-agent's m2, no synthetic)", got)
	}
	if again := ix.TakeUsage(false); len(again) != 0 {
		t.Fatalf("new usage is handed over once, got %d again", len(again))
	}
	if all := ix.TakeUsage(true); len(all) != 2 {
		t.Fatalf("a new hub connection gets everything again, got %d", len(all))
	}
}
