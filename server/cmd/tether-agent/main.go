// Command tether-agent connects one machine's Claude Code to the hub.
package main

import (
	"context"
	"errors"
	"flag"
	"log/slog"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/Mahaveer86619/tether/server/internal/agent"
	"github.com/Mahaveer86619/tether/server/internal/version"
)

func main() {
	host, _ := os.Hostname()
	hubURL := flag.String("hub", "", "hub WebSocket URL, e.g. ws://100.64.0.1:7420/ws")
	node := flag.String("node", strings.ToLower(host), "name this machine shows up as")
	claude := flag.String("claude", "claude", "Claude Code executable")
	projects := flag.String("projects", defaultProjectsDir(), "Claude Code projects directory")
	flag.Parse()

	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	token := os.Getenv("TETHER_TOKEN")
	if *hubURL == "" || token == "" {
		log.Error("-hub and TETHER_TOKEN are required")
		os.Exit(2)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	a := agent.New(agent.Config{
		HubURL: *hubURL, Token: token, Node: *node, Claude: *claude,
		ProjectsDir: *projects, Version: version.Version, Log: log,
	})
	if err := a.Run(ctx); err != nil && !errors.Is(err, context.Canceled) {
		log.Error("agent stopped", "err", err)
		os.Exit(1)
	}
}

func defaultProjectsDir() string {
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		return filepath.Join(dir, "projects")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude", "projects")
}
