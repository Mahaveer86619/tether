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
	"runtime"
	"strings"
	"syscall"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/agent"
	"github.com/Mahaveer86619/tether/server/internal/version"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "pair" {
		if err := pair(os.Args[2:]); err != nil {
			fmt.Fprintln(os.Stderr, "tether-agent pair:", err)
			os.Exit(1)
		}
		return
	}
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
	tokenFile := flag.String("token-file", "", "read the hub token from this file instead of TETHER_TOKEN")
	fingerprint := flag.String("fingerprint", os.Getenv("TETHER_HUB_FINGERPRINT"), "SHA-256 of the hub's self-signed certificate, from pairing")
	logFile := flag.String("log", "", "append logs to this file instead of stderr")
	mcp := flag.Bool("mcp", true, "register the hub's MCP server with Claude Code (undo with 'claude mcp remove tether -s user')")
	scratch := flag.String("scratch-dir", filepath.Join(home(), ".tether", "scratch"), "folder for hub sessions, one subfolder each")
	flag.Parse()

	out := os.Stderr
	if *logFile != "" {
		f, err := os.OpenFile(*logFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(2)
		}
		defer f.Close()
		out = f
	}
	log := slog.New(slog.NewTextHandler(out, nil))
	token := os.Getenv("TETHER_TOKEN")
	if *tokenFile != "" {
		b, err := os.ReadFile(*tokenFile)
		if err != nil {
			log.Error("read token file", "err", err)
			os.Exit(2)
		}
		token = strings.TrimSpace(string(b))
	}
	if *hubURL == "" {
		log.Error("-hub is required")
		os.Exit(2)
	}
	if token == "" {
		log.Info("no token: the hub must trust this machine through Tailscale (-trust-tailnet)")
	}
	settings := ""
	if *hooks && *hookAddr != "" {
		settings = settingsPath()
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	a, err := agent.New(agent.Config{
		HubURL: *hubURL, HubFingerprint: *fingerprint, Token: token, Node: *node, Claude: *claude, ProjectsDir: *projects,
		Host: *hostMode, HookAddr: *hookAddr, SettingsPath: settings, ScratchDir: *scratch, MCP: *mcp, Version: version.Version, Log: log,
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

// pair trades a pairing code (from the app's "Add a device" or
// `tetherctl pair`) for this node's own token and saves it to -token-file.
func pair(args []string) error {
	host, _ := os.Hostname()
	fs := flag.NewFlagSet("pair", flag.ExitOnError)
	hubURL := fs.String("hub", "", "hub WebSocket URL")
	node := fs.String("node", strings.ToLower(host), "name this machine shows up as")
	tokenFile := fs.String("token-file", "", "where to save the token")
	fingerprint := fs.String("fingerprint", "", "SHA-256 of the hub's self-signed certificate, if it uses one")
	_ = fs.Parse(args)
	if *hubURL == "" || *tokenFile == "" || fs.NArg() != 1 {
		return errors.New("usage: tether-agent pair -hub URL -token-file PATH [-node NAME] [-fingerprint SHA256] CODE")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	res, err := wire.Pair(ctx, *hubURL, *fingerprint, &v1.PairRequest{Code: fs.Arg(0), Kind: "node", Name: *node, Platform: runtime.GOOS})
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(*tokenFile), 0o700); err != nil {
		return err
	}
	if err := os.WriteFile(*tokenFile, []byte(res.Token), 0o600); err != nil {
		return err
	}
	fmt.Printf("paired as node %q; token saved to %s\n", res.Device.Name, *tokenFile)
	return nil
}

func home() string {
	h, _ := os.UserHomeDir()
	return h
}

func claudeDir(name string) string {
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		return filepath.Join(dir, name)
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude", name)
}

func settingsPath() string { return claudeDir("settings.json") }
