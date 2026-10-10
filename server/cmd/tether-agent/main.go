// Command tether-agent connects one machine's Claude Code to the hub.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
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
	if len(os.Args) > 1 && os.Args[1] == "uninstall-hooks" {
		if err := agent.UninstallHooks(settingsPath()); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Println("removed Tether hooks from", settingsPath())
		return
	}

	host, _ := os.Hostname()
	hubURL := flag.String("hub", "", "hub WebSocket URL, e.g. ws://100.64.0.1:7420/ws")
	node := flag.String("node", strings.ToLower(host), "name this machine shows up as")
	claude := flag.String("claude", "claude", "Claude Code executable")
	projects := flag.String("projects", claudeDir("projects"), "Claude Code projects directory")
	hostMode := flag.String("host", "auto", "where new sessions run: auto (tmux if installed), tmux, or headless")
	hookAddr := flag.String("hook-addr", "127.0.0.1:7421", "local address for Claude Code hooks; empty disables them")
	hooks := flag.Bool("hooks", true, "install Tether's hooks into Claude Code's settings.json (undo with 'tether-agent uninstall-hooks')")
	flag.Parse()

	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	token := os.Getenv("TETHER_TOKEN")
	if *hubURL == "" || token == "" {
		log.Error("-hub and TETHER_TOKEN are required")
		os.Exit(2)
	}
	settings := ""
	if *hooks && *hookAddr != "" {
		settings = settingsPath()
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	a, err := agent.New(agent.Config{
		HubURL: *hubURL, Token: token, Node: *node, Claude: *claude, ProjectsDir: *projects,
		Host: *hostMode, HookAddr: *hookAddr, SettingsPath: settings, Version: version.Version, Log: log,
	})
	if err != nil {
		log.Error("start agent", "err", err)
		os.Exit(2)
	}
	if err := a.Run(ctx); err != nil && !errors.Is(err, context.Canceled) {
		log.Error("agent stopped", "err", err)
		os.Exit(1)
	}
}

func claudeDir(name string) string {
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		return filepath.Join(dir, name)
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude", name)
}

func settingsPath() string { return claudeDir("settings.json") }
