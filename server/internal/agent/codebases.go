package agent

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Codebases on the hub, the agent's half: finding codebases under workspace
// roots, snapshotting one into the hub (only files the hub lacks are sent),
// sending its .env files to the hub's vault, and restoring a snapshot on the
// hub's machine. See docs/plan.md#codebases-on-the-hub.

const (
	// A snapshot bigger than this is refused: add what's missing to .tetherignore.
	maxSnapshot   = 2 << 30
	maxEnvFile    = 1 << 20
	uploadsAtOnce = 4
	restoredFile  = ".tether/restored.json"
)

// codebasesDir holds the hub machine's working copies, next to scratch.
func (a *Agent) codebasesDir() string {
	return filepath.Join(filepath.Dir(a.cfg.ScratchDir), "codebases")
}

// scanCodebases reports every folder directly under the roots: each is one
// codebase, whatever folders it has inside.
func (a *Agent) scanCodebases(roots []string) {
	found := &v1.FoundCodebases{Node: a.cfg.Node}
	for _, root := range roots {
		entries, err := os.ReadDir(root)
		if err != nil {
			a.log.Warn("scan workspace root", "root", root, "err", err)
			continue
		}
		for _, e := range entries {
			if !e.IsDir() || strings.HasPrefix(e.Name(), ".") {
				continue
			}
			dir := filepath.Join(root, e.Name())
			c := &v1.Codebase{Path: dir, Name: e.Name()}
			c.GitRemote, c.GitBranch, c.GitHead = gitInfo(dir)
			found.Codebases = append(found.Codebases, c)
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()
	if err := a.hubJSON(ctx, http.MethodPost, "/api/v1/codebases/found", found, &v1.Ack{}); err != nil {
		a.log.Warn("report codebases", "err", err)
	}
}

// gitInfo reads a repository's origin, branch and commit straight from .git.
func gitInfo(dir string) (remote, branch, head string) {
	git := filepath.Join(dir, ".git")
	b, err := os.ReadFile(filepath.Join(git, "HEAD"))
	if err != nil {
		return "", "", ""
	}
	ref := strings.TrimSpace(string(b))
	if r, ok := strings.CutPrefix(ref, "ref: "); ok {
		branch = strings.TrimPrefix(r, "refs/heads/")
		if h, err := os.ReadFile(filepath.Join(git, filepath.FromSlash(r))); err == nil {
			head = strings.TrimSpace(string(h))
		} else if packed, err := os.ReadFile(filepath.Join(git, "packed-refs")); err == nil {
			for _, line := range strings.Split(string(packed), "\n") {
				if sha, name, ok := strings.Cut(strings.TrimSpace(line), " "); ok && name == r {
					head = sha
				}
			}
		}
	} else {
		head = ref
	}
	if cfg, err := os.Open(filepath.Join(git, "config")); err == nil {
		defer cfg.Close()
		inOrigin := false
		sc := bufio.NewScanner(cfg)
		for sc.Scan() {
			line := strings.TrimSpace(sc.Text())
			if strings.HasPrefix(line, "[") {
				inOrigin = line == `[remote "origin"]`
				continue
			}
			if k, v, ok := strings.Cut(line, "="); ok && inOrigin && strings.TrimSpace(k) == "url" {
				remote = strings.TrimSpace(v)
			}
		}
	}
	return remote, branch, head
}

// prepareCodebase gives a codebase its .tether/codebase.json and, if it has
// none, a default .tetherignore; .tether/ stays out of git via
// .git/info/exclude rather than the project's own .gitignore.
func (a *Agent) prepareCodebase(c *v1.Codebase) (ignoreRules, error) {
	dir := c.Path
	if err := os.MkdirAll(filepath.Join(dir, ".tether"), 0o755); err != nil {
		return nil, err
	}
	meta, _ := json.MarshalIndent(map[string]string{"id": c.Id, "name": c.Name, "node": c.Node, "hub": a.cfg.HubURL}, "", "  ")
	if err := os.WriteFile(filepath.Join(dir, ".tether", "codebase.json"), append(meta, '\n'), 0o644); err != nil {
		return nil, err
	}
	ignorePath := filepath.Join(dir, ".tetherignore")
	text, err := os.ReadFile(ignorePath)
	if errors.Is(err, fs.ErrNotExist) {
		text = []byte(defaultTetherignore)
		err = os.WriteFile(ignorePath, text, 0o644)
	}
	if err != nil {
		return nil, err
	}
	if st, err := os.Stat(filepath.Join(dir, ".git")); err == nil && st.IsDir() {
		exclude := filepath.Join(dir, ".git", "info", "exclude")
		b, _ := os.ReadFile(exclude)
		if !bytes.Contains(b, []byte("\n.tether/")) && !bytes.HasPrefix(b, []byte(".tether/")) {
			_ = os.MkdirAll(filepath.Dir(exclude), 0o755)
			if f, err := os.OpenFile(exclude, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644); err == nil {
				if len(b) > 0 && !bytes.HasSuffix(b, []byte("\n")) {
					_, _ = f.WriteString("\n")
				}
				_, _ = f.WriteString(".tether/\n")
				f.Close()
			}
		}
	}
	return parseIgnore(string(text)), nil
}

type hashKey struct {
	path  string
	size  int64
	mtime int64
}

// snapshotCodebase sends a snapshot of a codebase and its .env files to the
// hub. Failures are reported on the codebase, for the app to show.
func (a *Agent) snapshotCodebase(c *v1.Codebase, session string) {
	a.snapMu.Lock()
	defer a.snapMu.Unlock()
	err := a.snapshot(c, session)
	if err == nil {
		return
	}
	a.log.Warn("snapshot", "codebase", c.Name, "err", err)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	_ = a.hubJSON(ctx, http.MethodPost, "/api/v1/codebases/"+c.Id+"/error", &v1.Error{Message: err.Error()}, &v1.Ack{})
}

func (a *Agent) snapshot(c *v1.Codebase, session string) error {
	start := time.Now()
	if st, err := os.Stat(c.Path); err != nil || !st.IsDir() {
		return fmt.Errorf("%s isn't a folder on %s", c.Path, a.cfg.Node)
	}
	rules, err := a.prepareCodebase(c)
	if err != nil {
		return fmt.Errorf("prepare %s: %w", c.Path, err)
	}
	m := &v1.SnapshotManifest{Session: session}
	m.GitRemote, m.GitBranch, m.GitHead = gitInfo(c.Path)
	env := &v1.EnvFiles{}
	local := map[string]string{} // sha -> a file with that content
	var total int64
	err = filepath.WalkDir(c.Path, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		rel, rerr := filepath.Rel(c.Path, p)
		if rerr != nil || rel == "." {
			return nil
		}
		rel = filepath.ToSlash(rel)
		if d.Type()&fs.ModeSymlink != 0 {
			return nil
		}
		if d.IsDir() {
			if rules.ignored(rel, true) {
				return filepath.SkipDir
			}
			return nil
		}
		info, ierr := d.Info()
		if ierr != nil || !info.Mode().IsRegular() {
			return nil
		}
		if isEnvFile(d.Name()) {
			if info.Size() <= maxEnvFile {
				if b, rerr := os.ReadFile(p); rerr == nil {
					env.Files = append(env.Files, &v1.EnvFile{Path: rel, Content: string(b)})
				}
			}
			return nil
		}
		if rules.ignored(rel, false) {
			return nil
		}
		if info.Size() > maxUpload {
			m.Skipped = append(m.Skipped, rel)
			return nil
		}
		total += info.Size()
		if total > maxSnapshot {
			return fmt.Errorf("over %d GB to copy; add the big folders to .tetherignore", maxSnapshot>>30)
		}
		sha, herr := a.fileHash(p, info)
		if herr != nil {
			m.Skipped = append(m.Skipped, rel)
			return nil
		}
		local[sha] = p
		m.Files = append(m.Files, &v1.SnapshotFile{Path: rel, Sha256: sha, Size: info.Size(), Executable: executable(rel, info)})
		return nil
	})
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Hour)
	defer cancel()
	missing := &v1.MissingBlobs{}
	if err := a.hubJSON(ctx, http.MethodPost, "/api/v1/codebases/"+c.Id+"/manifest", m, missing); err != nil {
		return fmt.Errorf("send the file list: %w", err)
	}
	if err := a.uploadBlobs(ctx, missing.Sha256, local); err != nil {
		return err
	}
	if err := a.hubJSON(ctx, http.MethodPost, "/api/v1/codebases/"+c.Id+"/snapshots", m, &v1.Snapshot{}); err != nil {
		return fmt.Errorf("record the snapshot: %w", err)
	}
	if err := a.hubJSON(ctx, http.MethodPut, "/api/v1/codebases/"+c.Id+"/env", env, &v1.Ack{}); err != nil {
		return fmt.Errorf("store the .env files: %w", err)
	}
	a.log.Info("snapshot", "codebase", c.Name, "files", len(m.Files), "sent", len(missing.Sha256), "env", len(env.Files), "took", time.Since(start).Round(time.Millisecond))
	return nil
}

// fileHash hashes a file, reusing the hash while its size and time match.
func (a *Agent) fileHash(p string, info fs.FileInfo) (string, error) {
	key := hashKey{p, info.Size(), info.ModTime().UnixNano()}
	a.mu.Lock()
	sha, ok := a.hashes[key]
	a.mu.Unlock()
	if ok {
		return sha, nil
	}
	f, err := os.Open(p)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	sha = hex.EncodeToString(h.Sum(nil))
	a.mu.Lock()
	a.hashes[key] = sha
	a.mu.Unlock()
	return sha, nil
}

// executable keeps scripts runnable on the other side: Windows has no exec bit.
func executable(rel string, info fs.FileInfo) bool {
	if runtime.GOOS == "windows" {
		return strings.HasSuffix(rel, ".sh")
	}
	return info.Mode()&0o111 != 0
}

func (a *Agent) uploadBlobs(ctx context.Context, shas []string, local map[string]string) error {
	var (
		wg    sync.WaitGroup
		mu    sync.Mutex
		first error
	)
	sem := make(chan struct{}, uploadsAtOnce)
	for _, sha := range shas {
		p := local[sha]
		if p == "" {
			continue
		}
		wg.Add(1)
		sem <- struct{}{}
		go func(sha, p string) {
			defer wg.Done()
			defer func() { <-sem }()
			if err := a.putBlob(ctx, sha, p); err != nil {
				mu.Lock()
				if first == nil {
					first = fmt.Errorf("upload %s: %w", p, err)
				}
				mu.Unlock()
			}
		}(sha, p)
	}
	wg.Wait()
	return first
}

func (a *Agent) putBlob(ctx context.Context, sha, p string) error {
	f, err := os.Open(p)
	if err != nil {
		return err
	}
	defer f.Close()
	req, err := a.hubRequest(ctx, http.MethodPut, "/api/v1/blobs/"+sha, f)
	if err != nil {
		return err
	}
	return a.do(req, nil)
}

// restoreCodebase brings dir up to a snapshot, with the codebase's .env
// files from the vault. Files a previous restore put there and the snapshot
// no longer has are removed; files made in dir since are left alone.
func (a *Agent) restoreCodebase(codebase, snapshot, dir string) error {
	ctx, cancel := context.WithTimeout(context.Background(), time.Hour)
	defer cancel()
	m := &v1.SnapshotManifest{}
	if err := a.hubJSON(ctx, http.MethodGet, "/api/v1/snapshots/"+snapshot+"/manifest", nil, m); err != nil {
		return fmt.Errorf("get the snapshot: %w", err)
	}
	prev := map[string]string{}
	if b, err := os.ReadFile(filepath.Join(dir, filepath.FromSlash(restoredFile))); err == nil {
		_ = json.Unmarshal(b, &prev)
	}
	now := map[string]string{}
	for _, f := range m.Files {
		target, err := within(dir, f.Path)
		if err != nil {
			return err
		}
		now[f.Path] = f.Sha256
		if prev[f.Path] == f.Sha256 {
			if _, err := os.Stat(target); err == nil {
				continue
			}
		}
		if err := a.fetchBlob(ctx, f.Sha256, target, f.Executable); err != nil {
			return fmt.Errorf("restore %s: %w", f.Path, err)
		}
	}
	for p := range prev {
		if _, keep := now[p]; !keep {
			if target, err := within(dir, p); err == nil {
				_ = os.Remove(target)
			}
		}
	}
	env := &v1.EnvFiles{}
	if err := a.hubJSON(ctx, http.MethodGet, "/api/v1/codebases/"+codebase+"/env/files", nil, env); err != nil {
		return fmt.Errorf("get the .env files: %w", err)
	}
	for _, e := range env.Files {
		target, err := within(dir, e.Path)
		if err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(target, []byte(e.Content), 0o600); err != nil {
			return err
		}
	}
	b, _ := json.Marshal(now)
	_ = os.MkdirAll(filepath.Join(dir, ".tether"), 0o755)
	return os.WriteFile(filepath.Join(dir, filepath.FromSlash(restoredFile)), b, 0o644)
}

// within joins a codebase-relative path onto dir, refusing ones that escape it.
func within(dir, rel string) (string, error) {
	clean := path.Clean(rel)
	if rel == "" || strings.Contains(rel, `\`) || path.IsAbs(clean) || clean == "." || clean == ".." || strings.HasPrefix(clean, "../") {
		return "", fmt.Errorf("bad path %q in snapshot", rel)
	}
	return filepath.Join(dir, filepath.FromSlash(clean)), nil
}

func (a *Agent) fetchBlob(ctx context.Context, sha, target string, exec bool) error {
	req, err := a.hubRequest(ctx, http.MethodGet, "/api/v1/blobs/"+sha, nil)
	if err != nil {
		return err
	}
	res, err := a.hubClient().Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("hub said %s", res.Status)
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	mode := os.FileMode(0o644)
	if exec {
		mode = 0o755
	}
	tmp := target + ".tether-tmp"
	f, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	h := sha256.New()
	_, err = io.Copy(io.MultiWriter(f, h), res.Body)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil && hex.EncodeToString(h.Sum(nil)) != sha {
		err = errors.New("content doesn't match its hash")
	}
	if err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, target)
}

// hubJSON sends in (if any) as JSON and reads the answer into out.
func (a *Agent) hubJSON(ctx context.Context, method, apiPath string, in, out proto.Message) error {
	var body io.Reader
	if in != nil {
		b, err := protojson.Marshal(in)
		if err != nil {
			return err
		}
		body = bytes.NewReader(b)
	}
	req, err := a.hubRequest(ctx, method, apiPath, body)
	if err != nil {
		return err
	}
	if in != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	return a.do(req, out)
}

func (a *Agent) do(req *http.Request, out proto.Message) error {
	res, err := a.hubClient().Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	b, err := io.ReadAll(res.Body)
	if err != nil {
		return err
	}
	if res.StatusCode != http.StatusOK {
		e := &v1.Error{}
		if protojson.Unmarshal(b, e) == nil && e.Message != "" {
			return errors.New(e.Message)
		}
		return fmt.Errorf("hub said %s", res.Status)
	}
	if out == nil {
		return nil
	}
	return protojson.UnmarshalOptions{DiscardUnknown: true}.Unmarshal(b, out)
}
