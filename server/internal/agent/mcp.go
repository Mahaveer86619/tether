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
		return
	}
	url := wire.HTTPBase(a.cfg.HubURL) + "/mcp"
	args := []string{"mcp", "add", "--transport", "http", "--scope", "user", "tether", url}
	// Only put the token in Claude Code's config if the hub needs it, i.e.
	// it doesn't already trust this machine through Tailscale.
	if a.cfg.Token != "" && !a.hubTrustsUs() {
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
		return
	}
	a.log.Info("registered the hub's MCP server with Claude Code", "url", url)
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
