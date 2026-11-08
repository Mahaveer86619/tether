package agent

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// The drop folder: anything a session leaves in <cwd>/.tether/out/ is
// delivered to the chat as a result file. See docs/plans/deliverables.md.

const (
	outDir = ".tether/out"
	// A file touched more recently than this may still be being written.
	outSettle   = 2 * time.Second
	outMaxFiles = 50
)

var outIgnored = []string{".part", ".tmp", ".temp", ".crdownload", ".swp", "~"}

func isOutTemp(name string) bool {
	if strings.HasPrefix(name, ".") {
		return true
	}
	lower := strings.ToLower(name)
	for _, suffix := range outIgnored {
		if strings.HasSuffix(lower, suffix) {
			return true
		}
	}
	return false
}

// outFiles lists the settled files under the drop folder of cwd.
func outFiles(cwd string, now time.Time) []string {
	root := filepath.Join(cwd, filepath.FromSlash(outDir))
	var found []string
	_ = filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil || len(found) >= outMaxFiles {
			return nil
		}
		if d.IsDir() {
			return nil
		}
		if isOutTemp(d.Name()) {
			return nil
		}
		info, err := d.Info()
		if err != nil || !info.Mode().IsRegular() || now.Sub(info.ModTime()) < outSettle {
			return nil
		}
		found = append(found, p)
		return nil
	})
	return found
}

// noteOutbox delivers new files from the session's drop folder. It runs
// after every tool call, so a file a command made shows up when that
// command ends.
func (a *Agent) noteOutbox(in hookInput) {
	if in.Event != "PostToolUse" && in.Event != "Stop" || in.Cwd == "" {
		return
	}
	for _, path := range outFiles(in.Cwd, time.Now()) {
		st, err := os.Stat(path)
		if err != nil {
			continue
		}
		if st.Size() > maxUpload {
			a.log.Info("not delivering a large file", "path", path, "bytes", st.Size())
			continue
		}
		key := fmt.Sprintf("%s|%s|%d|%d", in.SessionID, path, st.Size(), st.ModTime().UnixNano())
		a.mu.Lock()
		seen := a.uploaded[key]
		a.uploaded[key] = true
		a.mu.Unlock()
		if seen {
			continue
		}
		go func(path string) {
			if err := a.uploadFile(path, map[string]string{
				"X-Session": in.SessionID, "X-Origin": "result", "X-Path": path, "X-Tool-Use-Id": in.ToolUseID,
			}); err != nil {
				a.log.Warn("deliver result file", "path", path, "err", err)
			}
		}(path)
	}
}
