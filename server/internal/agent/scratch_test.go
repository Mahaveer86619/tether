package agent

import (
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"testing"
)

func TestForgetOnlyDeletesInsideScratch(t *testing.T) {
	root := t.TempDir()
	projects := filepath.Join(root, "projects")
	scratch := filepath.Join(root, "scratch")
	outside := filepath.Join(root, "work")
	for _, d := range []string{filepath.Join(scratch, "s1"), outside} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	writeTranscript := func(id, cwd string) {
		dir := filepath.Join(projects, notAlnum.ReplaceAllString(cwd, "-"))
		_ = os.MkdirAll(dir, 0o755)
		line := `{"type":"user","cwd":` + quote(cwd) + `,"message":{"content":"hi"}}` + "\n"
		if err := os.WriteFile(filepath.Join(dir, id+".jsonl"), []byte(line), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	writeTranscript("s1", filepath.Join(scratch, "s1"))
	writeTranscript("s2", outside)

	a := &Agent{cfg: Config{ProjectsDir: projects, ScratchDir: scratch}, log: slog.New(slog.NewTextHandler(io.Discard, nil)), index: NewIndex(projects)}
	if _, err := a.index.Scan(); err != nil {
		t.Fatal(err)
	}
	a.forgetScratch("s2")
	if _, err := os.Stat(outside); err != nil {
		t.Fatal("a folder outside scratch was deleted")
	}
	a.forgetScratch("s1")
	if _, err := os.Stat(filepath.Join(scratch, "s1")); !os.IsNotExist(err) {
		t.Fatal("the scratch folder should be gone")
	}
	if a.index.Path("s1") != "" {
		if _, err := os.Stat(a.index.Path("s1")); !os.IsNotExist(err) {
			t.Fatal("the transcript should be gone")
		}
	}
}

func quote(s string) string {
	b := []byte{'"'}
	for _, r := range filepath.ToSlash(s) {
		b = append(b, string(r)...)
	}
	return string(append(b, '"'))
}
