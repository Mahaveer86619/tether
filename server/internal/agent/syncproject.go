package agent

import (
	"errors"
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
