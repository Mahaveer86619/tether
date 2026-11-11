package agent

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestOutFiles(t *testing.T) {
	cwd := t.TempDir()
	out := filepath.Join(cwd, ".tether", "out")
	if err := os.MkdirAll(filepath.Join(out, "sub"), 0o755); err != nil {
		t.Fatal(err)
	}
	old := time.Now().Add(-time.Minute)
	write := func(rel string, age time.Time) {
		p := filepath.Join(out, rel)
		if err := os.WriteFile(p, []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(p, age, age); err != nil {
			t.Fatal(err)
		}
	}
	write("app.apk", old)
	write("sub/rows.csv", old)
	write("big.zip.part", old)
	write(".hidden", old)
	write("report~", old)
	write("still-writing.pdf", time.Now())

	got := map[string]bool{}
	for _, p := range outFiles(cwd, time.Now()) {
		rel, _ := filepath.Rel(out, p)
		got[filepath.ToSlash(rel)] = true
	}
	if len(got) != 2 || !got["app.apk"] || !got["sub/rows.csv"] {
		t.Errorf("delivered %v; want app.apk and sub/rows.csv only", got)
	}
}

func TestOutFilesWithNoFolder(t *testing.T) {
	if got := outFiles(t.TempDir(), time.Now()); len(got) != 0 {
		t.Errorf("got %v", got)
	}
}
