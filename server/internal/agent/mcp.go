package agent

import (
	"context"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/Mahaveer86619/tether/server/internal/wire"
)

// registerMCP adds the hub's MCP server to Claude Code for this user (user
// scope, like the hooks), so every session here can reach the other nodes
// and the artifact store. Undo with `claude mcp remove tether -s user`.
func (a *Agent) registerMCP() {
	if a.cfg.HubFingerprint != "" {
		// Claude Code would reject the hub's self-signed certificate.
		a.log.Info("not registering the hub's MCP server: its certificate is self-signed")
		a.setMCP("not registered: the hub's certificate is self-signed, which Claude Code would reject")
		return
	}
	url := wire.HTTPBase(a.cfg.HubURL) + "/mcp"
	args := []string{"mcp", "add", "--transport", "http", "--scope", "user", "tether", url}
	// Only put the token in Claude Code's config if the hub needs it, i.e.
	// it doesn't already trust this machine through Tailscale.
	hubToken := a.cfg.Token != "" && !a.hubTrustsUs()
	if hubToken {
		args = append(args, "--header", "Authorization: Bearer "+a.cfg.Token)
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()
	claude := func(args ...string) ([]byte, error) {
		cmd := exec.CommandContext(ctx, a.cfg.Claude, args...)
		cmd.Dir = os.TempDir()
		hideWindow(cmd)
		return cmd.CombinedOutput()
	}
	_, _ = claude("mcp", "remove", "tether", "--scope", "user")
	if out, err := claude(args...); err != nil {
		a.log.Warn("register MCP server", "err", err, "output", strings.TrimSpace(string(out)))
		a.setMCP("registering failed: " + strings.TrimSpace(string(out)))
		return
	}
	a.log.Info("registered the hub's MCP server with Claude Code", "url", url)
	a.setMCP("ok")
	a.registerBrain(claude, hubToken)
}

// brainLoop looks again, now and then, for a second brain on the hub: it can be
// set up after this agent started, and nobody should have to restart agents for it.
func (a *Agent) brainLoop(ctx context.Context) {
	t := time.NewTicker(20 * time.Minute)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if a.cfg.HubFingerprint != "" {
				continue
			}
			cctx, cancel := context.WithTimeout(ctx, time.Minute)
			claude := func(args ...string) ([]byte, error) {
				cmd := exec.CommandContext(cctx, a.cfg.Claude, args...)
				cmd.Dir = os.TempDir()
				hideWindow(cmd)
				return cmd.CombinedOutput()
			}
			a.registerBrain(claude, a.cfg.Token != "" && !a.hubTrustsUs())
			cancel()
		}
	}
}

// registerBrain adds the second brain's MCP server (the hub forwards /brain/mcp
// to it) when the hub has one, and takes it away when it has not, so Claude
// Code never lists a server that cannot answer.
func (a *Agent) registerBrain(claude func(args ...string) ([]byte, error), hubToken bool) {
	base := wire.HTTPBase(a.cfg.HubURL)
	up := a.brainUp(base, hubToken)
	a.mu.Lock()
	same := a.brainState == map[bool]int{true: 1, false: 2}[up]
	a.brainState = map[bool]int{true: 1, false: 2}[up]
	a.mu.Unlock()
	if same {
		return // nothing has changed since the last look
	}
	if !up {
		_, _ = claude("mcp", "remove", "tether-brain", "--scope", "user")
		return
	}
	args := []string{"mcp", "add", "--transport", "http", "--scope", "user", "tether-brain", base + "/brain/mcp"}
	if hubToken {
		args = append(args, "--header", "Authorization: Bearer "+a.cfg.Token)
	}
	_, _ = claude("mcp", "remove", "tether-brain", "--scope", "user")
	if out, err := claude(args...); err != nil {
		a.log.Warn("register the brain's MCP server", "err", err, "output", strings.TrimSpace(string(out)))
		return
	}
	a.log.Info("registered the second brain's MCP server with Claude Code", "url", base+"/brain/mcp")
}

// brainUp asks the hub whether its second brain is there and answering.
func (a *Agent) brainUp(base string, hubToken bool) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, base+"/brain/healthz", nil)
	if err != nil {
		return false
	}
	if hubToken {
		req.Header.Set("Authorization", "Bearer "+a.cfg.Token)
	}
	res, err := wire.HTTPClient(a.cfg.HubFingerprint).Do(req)
	if err != nil {
		return false
	}
	res.Body.Close()
	return res.StatusCode == http.StatusOK
}

func (a *Agent) setMCP(state string) {
	a.mu.Lock()
	a.mcpState = state
	a.mu.Unlock()
}

func (a *Agent) hubTrustsUs() bool {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, wire.HTTPBase(a.cfg.HubURL)+"/api/v1/state", nil)
	if err != nil {
		return false
	}
	res, err := wire.HTTPClient(a.cfg.HubFingerprint).Do(req)
	if err != nil {
		return false
	}
	res.Body.Close()
	return res.StatusCode == http.StatusOK
}
