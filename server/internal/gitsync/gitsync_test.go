package gitsync

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func write(t *testing.T, dir, name, text string) {
	t.Helper()
	p := filepath.Join(dir, name)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
}

func read(t *testing.T, dir, name string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(dir, name))
	if err != nil {
		return "<missing>"
	}
	return string(b)
}

func need(t *testing.T) {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git is not installed")
	}
}

// bareRemote is a bare repository on disk to push to and fetch from.
func bareRemote(t *testing.T) Remote {
	t.Helper()
	bare := filepath.Join(t.TempDir(), "p.git")
	if out, err := exec.Command("git", "init", "--bare", "--initial-branch=main", bare).CombinedOutput(); err != nil {
		t.Fatalf("%v: %s", err, out)
	}
	return Remote{URL: bare}
}

func TestSnapshotLeavesTheBranchAndIndexAlone(t *testing.T) {
	need(t)
	dir := t.TempDir()
	write(t, dir, "a.txt", "one")
	who := []string{"GIT_AUTHOR_NAME=x", "GIT_AUTHOR_EMAIL=x@x", "GIT_COMMITTER_NAME=x", "GIT_COMMITTER_EMAIL=x@x"}
	for _, a := range [][]string{{"init", "--initial-branch=main"}, {"add", "a.txt"}, {"commit", "-m", "mine"}} {
		if _, err := git(dir, who, a...); err != nil {
			t.Fatal(err)
		}
	}
	before, _ := Head(dir)

	write(t, dir, "a.txt", "two")
	write(t, dir, "new.txt", "n")
	changed, err := Snapshot(dir, "chat1", "turn 1")
	if err != nil || !changed {
		t.Fatalf("changed=%v err=%v", changed, err)
	}
	if after, _ := Head(dir); after != before {
		t.Fatal("the branch moved")
	}
	if st, _ := git(dir, nil, "status", "--porcelain"); st == "" {
		t.Fatal("the folder's changes were committed or staged away")
	}
	changed, err = Snapshot(dir, "chat1", "turn 2")
	if err != nil || changed {
		t.Fatalf("nothing changed, yet changed=%v err=%v", changed, err)
	}
}

func TestAFolderReachesAnotherDeviceWithoutItsSecrets(t *testing.T) {
	need(t)
	remote := bareRemote(t)
	a, b := t.TempDir(), t.TempDir()
	write(t, a, "main.go", "package main")
	write(t, a, ".env", "KEY=secret")
	if err := Exclude(a, ".env"); err != nil {
		t.Fatal(err)
	}
	if _, err := Snapshot(a, "c1", "first"); err != nil {
		t.Fatal(err)
	}
	if err := Push(a, remote, "c1"); err != nil {
		t.Fatal(err)
	}
	if err := Pull(b, remote, "c1"); err != nil {
		t.Fatal(err)
	}
	if read(t, b, "main.go") != "package main" {
		t.Fatal("the code did not arrive")
	}
	if read(t, b, ".env") != "<missing>" {
		t.Fatal("a secret was synced")
	}

	write(t, a, "main.go", "package main // v2")
	write(t, a, "pkg/x.go", "package pkg")
	if _, err := Snapshot(a, "c1", "second"); err != nil {
		t.Fatal(err)
	}
	if err := Push(a, remote, "c1"); err != nil {
		t.Fatal(err)
	}
	if err := Pull(b, remote, "c1"); err != nil {
		t.Fatal(err)
	}
	if read(t, b, "main.go") != "package main // v2" || read(t, b, "pkg/x.go") != "package pkg" {
		t.Fatal("the change did not arrive")
	}
}

func TestAPullDoesNotOverwriteWorkOfItsOwn(t *testing.T) {
	need(t)
	remote := bareRemote(t)
	a, b := t.TempDir(), t.TempDir()
	write(t, a, "f.txt", "1")
	_, _ = Snapshot(a, "c", "m")
	if err := Push(a, remote, "c"); err != nil {
		t.Fatal(err)
	}
	if err := Pull(b, remote, "c"); err != nil {
		t.Fatal(err)
	}
	write(t, b, "f.txt", "mine")
	write(t, a, "f.txt", "2")
	_, _ = Snapshot(a, "c", "m2")
	_ = Push(a, remote, "c")
	if err := Pull(b, remote, "c"); err != ErrDirty {
		t.Fatalf("got %v, want ErrDirty", err)
	}
	if read(t, b, "f.txt") != "mine" {
		t.Fatal("the folder's own change was lost")
	}
}

func TestASecondWriterIsToldItDiverged(t *testing.T) {
	need(t)
	remote := bareRemote(t)
	a, b := t.TempDir(), t.TempDir()
	write(t, a, "f.txt", "1")
	_, _ = Snapshot(a, "c", "m")
	_ = Push(a, remote, "c")
	write(t, b, "g.txt", "other")
	_, _ = Snapshot(b, "c", "theirs")
	if err := Push(b, remote, "c"); err != ErrDiverged {
		t.Fatalf("got %v, want ErrDiverged", err)
	}
}

func TestTheWriterCanHandTheWorkToTheOtherDeviceAndTakeItBack(t *testing.T) {
	need(t)
	remote := bareRemote(t)
	a, b := t.TempDir(), t.TempDir()
	who := []string{"GIT_AUTHOR_NAME=x", "GIT_AUTHOR_EMAIL=x@x", "GIT_COMMITTER_NAME=x", "GIT_COMMITTER_EMAIL=x@x"}
	// a is somebody's own repository, with a commit and work past it.
	write(t, a, "keep.txt", "k")
	write(t, a, "old.txt", "o")
	for _, args := range [][]string{{"init", "--initial-branch=main"}, {"add", "."}, {"commit", "-m", "mine"}} {
		if _, err := git(a, who, args...); err != nil {
			t.Fatal(err)
		}
	}
	write(t, a, "keep.txt", "k2")
	write(t, a, "scratch.txt", "s")
	if _, err := Snapshot(a, "c", "a1"); err != nil {
		t.Fatal(err)
	}
	if err := Push(a, remote, "c"); err != nil {
		t.Fatal(err)
	}
	if err := Pull(b, remote, "c"); err != nil {
		t.Fatal(err)
	}

	// b works: changes one file, deletes another, adds one.
	write(t, b, "keep.txt", "k3")
	if err := os.Remove(filepath.Join(b, "scratch.txt")); err != nil {
		t.Fatal(err)
	}
	write(t, b, "new.txt", "n")
	if _, err := Snapshot(b, "c", "b1"); err != nil {
		t.Fatal(err)
	}
	if err := Push(b, remote, "c"); err != nil {
		t.Fatalf("the new writer's push: %v", err)
	}

	// a, which was the writer, follows, though its own branch differs.
	if err := Pull(a, remote, "c"); err != nil {
		t.Fatalf("the old writer's pull: %v", err)
	}
	if read(t, a, "keep.txt") != "k3" || read(t, a, "new.txt") != "n" {
		t.Fatal("the new work did not arrive")
	}
	if read(t, a, "scratch.txt") != "<missing>" {
		t.Fatal("a file that was deleted is still there")
	}

	// And back: a writes again, on top of what it pulled.
	write(t, a, "keep.txt", "k4")
	if _, err := Snapshot(a, "c", "a2"); err != nil {
		t.Fatal(err)
	}
	if err := Push(a, remote, "c"); err != nil {
		t.Fatalf("taking the work back: %v", err)
	}
	if err := Pull(b, remote, "c"); err != nil {
		t.Fatal(err)
	}
	if read(t, b, "keep.txt") != "k4" {
		t.Fatal("the work did not come back")
	}
}
