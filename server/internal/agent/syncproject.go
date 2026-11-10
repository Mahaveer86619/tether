package agent

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/gitsync"
)

// syncProject pushes a remote chat's folder to the hub's repository, or
// pulls it from there, and says how it went.
func (a *Agent) syncProject(c *v1.AgentCommand_SyncProject) {
	res := &v1.SyncResult{Id: c.Id, Chat: c.Chat, Direction: c.Direction, Cwd: c.Cwd}
	if err := a.runSync(c, res); err != nil {
		res.Ok, res.Error = false, err.Error()
		a.cfg.Log.Warn("project sync", "chat", c.Chat, "direction", c.Direction, "err", err)
	} else {
		res.Ok = true
	}
	a.send(&v1.Frame{Body: &v1.Frame_SyncResult{SyncResult: res}})
}

func (a *Agent) runSync(c *v1.AgentCommand_SyncProject, res *v1.SyncResult) error {
	remote, err := a.repoRemote(c.Repo)
	if err != nil {
		return err
	}
	switch c.Direction {
	case "push":
		if c.Cwd == "" {
			return errors.New("no folder to push")
		}
		if err := gitsync.Exclude(c.Cwd, c.Exclude...); err != nil {
			return err
		}
		changed, err := gitsync.Snapshot(c.Cwd, c.Branch, "Tether: "+c.Chat)
		if err != nil {
			return err
		}
		res.Changed = changed
		if err := gitsync.Push(c.Cwd, remote, c.Branch); err != nil {
			return err
		}
		res.Head = gitsync.Tip(c.Cwd, c.Branch)
	case "pull":
		cwd := c.Cwd
		if cwd == "" {
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			cwd = filepath.Join(home, "tether-projects", c.Repo)
		}
		res.Cwd = cwd
		if err := gitsync.Exclude(cwd, c.Exclude...); err != nil {
			return err
		}
		if err := gitsync.Pull(cwd, remote, c.Branch); err != nil {
			return err
		}
		res.Head, _ = gitsync.Head(cwd)
		if err := a.writeProjectFiles(cwd, c.Repo); err != nil {
			return err
		}
	default:
		return errors.New("unknown direction " + c.Direction)
	}
	return nil
}

// repoRemote is the hub's repository for a project, reached with this
// agent's own token.
func (a *Agent) repoRemote(repo string) (gitsync.Remote, error) {
	if a.cfg.HubFingerprint != "" {
		return gitsync.Remote{}, errors.New("remote projects need the hub on http, or with a certificate that is not self-signed")
	}
	u, err := url.Parse(a.cfg.HubURL)
	if err != nil {
		return gitsync.Remote{}, err
	}
	scheme := "http"
	if u.Scheme == "wss" {
		scheme = "https"
	}
	base := scheme + "://" + u.Host
	return gitsync.Remote{URL: base + "/git/" + strings.TrimSuffix(repo, ".git") + ".git", Token: a.cfg.Token}, nil
}

// writeProjectFiles puts the project's vault files into the folder (mode 600,
// and kept out of git), if the owner has allowed this device. A device that
// is not allowed just gets the code.
func (a *Agent) writeProjectFiles(cwd, repo string) error {
	remote, err := a.repoRemote(repo)
	if err != nil {
		return err
	}
	base := strings.TrimSuffix(remote.URL, "/git/"+repo+".git")
	req, err := http.NewRequest(http.MethodGet, base+"/api/v1/projects/"+repo+"/files/content?node="+url.QueryEscape(a.cfg.Node), nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+a.cfg.Token)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode == http.StatusForbidden {
		return nil
	}
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("the hub's vault answered %d", res.StatusCode)
	}
	var body struct {
		Files []struct {
			Path    string `json:"path"`
			Content string `json:"content"`
		} `json:"files"`
	}
	if err := json.NewDecoder(res.Body).Decode(&body); err != nil {
		return err
	}
	var paths []string
	for _, f := range body.Files {
		rel := filepath.FromSlash(f.Path)
		if filepath.IsAbs(rel) || strings.HasPrefix(filepath.Clean(rel), "..") {
			continue
		}
		dest := filepath.Join(cwd, rel)
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(dest, []byte(f.Content), 0o600); err != nil {
			return err
		}
		paths = append(paths, f.Path)
	}
	if len(paths) == 0 {
		return nil
	}
	return gitsync.Exclude(cwd, paths...)
}
