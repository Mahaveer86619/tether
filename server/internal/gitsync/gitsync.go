// Package gitsync keeps a project folder in step with a repository on the
// hub, for remote chats (docs/plans/remote-projects.md). The writing device's
// folder is committed to a ref of its own without touching its branch or
// index, so a person's own work in the same folder is never rewritten; other
// devices fetch that ref and check it out into a folder they only read.
package gitsync

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Remote is a repository on the hub and the token that opens it.
type Remote struct {
	URL   string
	Token string
}

var (
	// ErrDirty means the folder has changes of its own that a pull would overwrite.
	ErrDirty = errors.New("the folder has changes that are not synced")
	// ErrDiverged means the hub's copy has commits this folder does not.
	ErrDiverged = errors.New("the hub's copy has changes this folder does not have")
)

func ref(branch string) string { return "refs/tether/" + branch }

func (r Remote) flags() []string {
	if r.Token == "" {
		return nil
	}
	return []string{"-c", "http.extraHeader=Authorization: Bearer " + r.Token}
}

func git(dir string, env []string, args ...string) (string, error) {
	// Never ask anybody for a password: a refused token is an error, not a dialog.
	args = append([]string{"-c", "credential.helper=", "-c", "core.askPass="}, args...)
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), append([]string{"GIT_TERMINAL_PROMPT=0", "GCM_INTERACTIVE=never", "LC_ALL=C"}, env...)...)
	var out, errb bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &errb
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("git %s: %s", strings.Join(args, " "), strings.TrimSpace(errb.String()+out.String()))
	}
	return strings.TrimSpace(out.String()), nil
}

func isRepo(dir string) bool {
	_, err := git(dir, nil, "rev-parse", "--git-dir")
	return err == nil
}

func ensureRepo(dir string) error {
	if isRepo(dir) {
		return nil
	}
	_, err := git(dir, nil, "init", "--initial-branch=main")
	return err
}

// Exclude keeps paths out of what is synced without editing the project's
// .gitignore: it adds them to .git/info/exclude.
func Exclude(dir string, paths ...string) error {
	if err := ensureRepo(dir); err != nil {
		return err
	}
	gd, err := git(dir, nil, "rev-parse", "--absolute-git-dir")
	if err != nil {
		return err
	}
	file := filepath.Join(gd, "info", "exclude")
	if err := os.MkdirAll(filepath.Dir(file), 0o755); err != nil {
		return err
	}
	have, _ := os.ReadFile(file)
	lines := map[string]bool{}
	for _, l := range strings.Split(string(have), "\n") {
		lines[strings.TrimSpace(l)] = true
	}
	add := ""
	for _, p := range paths {
		if !lines[p] {
			add += p + "\n"
		}
	}
	if add == "" {
		return nil
	}
	f, err := os.OpenFile(file, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	if len(have) > 0 && !bytes.HasSuffix(have, []byte("\n")) {
		_, _ = f.WriteString("\n")
	}
	_, err = f.WriteString(add)
	return err
}

// workTree is the tree of the folder as it is now (what git would add, so
// .gitignore and Exclude are respected), built in a private index on top of
// parent so the folder's own index is left alone.
func workTree(dir, parent string) (string, error) {
	gd, err := git(dir, nil, "rev-parse", "--absolute-git-dir")
	if err != nil {
		return "", err
	}
	index := filepath.Join(gd, "tether-index")
	defer os.Remove(index)
	env := []string{"GIT_INDEX_FILE=" + index}
	if parent != "" {
		if _, err := git(dir, env, "read-tree", parent); err != nil {
			return "", err
		}
	}
	if _, err := git(dir, env, "add", "-A"); err != nil {
		return "", err
	}
	return git(dir, env, "write-tree")
}

// Snapshot commits the folder as it is now to the sync ref for branch, on
// top of its last snapshot or, for the first, the folder's current commit.
// It reports whether anything changed.
func Snapshot(dir, branch, message string) (changed bool, err error) {
	if err := ensureRepo(dir); err != nil {
		return false, err
	}
	last, _ := git(dir, nil, "rev-parse", "-q", "--verify", ref(branch))
	parent := last
	if parent == "" {
		parent, _ = git(dir, nil, "rev-parse", "-q", "--verify", "HEAD")
	}
	tree, err := workTree(dir, parent)
	if err != nil {
		return false, err
	}
	if parent != "" {
		if old, _ := git(dir, nil, "rev-parse", parent+"^{tree}"); old == tree {
			if last == "" {
				_, err = git(dir, nil, "update-ref", ref(branch), parent)
			}
			return false, err
		}
	}
	args := []string{"commit-tree", tree, "-m", message}
	if parent != "" {
		args = append(args, "-p", parent)
	}
	who := []string{"GIT_AUTHOR_NAME=Tether", "GIT_AUTHOR_EMAIL=tether@localhost", "GIT_COMMITTER_NAME=Tether", "GIT_COMMITTER_EMAIL=tether@localhost"}
	commit, err := git(dir, who, args...)
	if err != nil {
		return false, err
	}
	_, err = git(dir, nil, "update-ref", ref(branch), commit)
	return err == nil, err
}

// Push sends the sync ref for branch to the hub. A refusal because the hub
// has newer work is ErrDiverged.
func Push(dir string, r Remote, branch string) error {
	args := append(r.flags(), "push", r.URL, ref(branch)+":refs/heads/tether/"+branch)
	if _, err := git(dir, nil, args...); err != nil {
		if strings.Contains(err.Error(), "non-fast-forward") || strings.Contains(err.Error(), "fetch first") || strings.Contains(err.Error(), "rejected") {
			return ErrDiverged
		}
		return err
	}
	return nil
}

// Pull makes dir match the hub's copy of branch: a folder with no
// repository gets one, then the branch is fetched and checked out. A folder
// that has changed since it was last synced is left alone (ErrDirty). The
// folder that was the writer until now counts as unchanged when it still
// matches what it last pushed, even though its own branch differs.
func Pull(dir string, r Remote, branch string) error {
	if !isRepo(dir) {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
		if _, err := git(dir, nil, "init", "--initial-branch=main"); err != nil {
			return err
		}
	}
	tip, _ := git(dir, nil, "rev-parse", "-q", "--verify", ref(branch))
	if tip != "" {
		tree, err := workTree(dir, tip)
		if err != nil {
			return err
		}
		if old, _ := git(dir, nil, "rev-parse", tip+"^{tree}"); old != tree {
			return ErrDirty
		}
	} else if st, err := git(dir, nil, "status", "--porcelain"); err != nil {
		return err
	} else if st != "" {
		return ErrDirty
	}
	remoteRef := "refs/remotes/tether/" + branch
	if _, err := git(dir, nil, append(r.flags(), "fetch", r.URL, "+refs/heads/tether/"+branch+":"+remoteRef)...); err != nil {
		return err
	}
	if tip != "" {
		// Files the last push had that the new copy does not stay behind
		// otherwise, being untracked in this folder's own branch.
		if gone, err := git(dir, nil, "diff", "--name-only", "--diff-filter=D", tip, remoteRef); err == nil {
			for _, f := range strings.Split(gone, "\n") {
				if f = strings.TrimSpace(f); f != "" {
					_ = os.Remove(filepath.Join(dir, filepath.FromSlash(f)))
				}
			}
		}
	}
	if _, err := git(dir, nil, "checkout", "-q", "-f", "-B", "tether/"+branch, remoteRef); err != nil {
		return err
	}
	_, err := git(dir, nil, "update-ref", ref(branch), remoteRef)
	return err
}

// Head is the commit the folder is at.
func Head(dir string) (string, error) { return git(dir, nil, "rev-parse", "HEAD") }

// Tip is the last snapshot of branch, empty if there is none.
func Tip(dir, branch string) string {
	sha, _ := git(dir, nil, "rev-parse", "-q", "--verify", ref(branch))
	return sha
}
