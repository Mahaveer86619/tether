// Command tether-herdr exposes Tether's hub tools to an agent running in a
// Herdr pane and mirrors Tether session state back into that pane. Herdr is an
// optional external harness; this command only calls its public CLI.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"
)

const usage = `usage: tether-herdr [flags]

A stdio MCP server for a Herdr pane. It forwards tools to Tether's hub and
reports Tether chat/session state through herdr pane report-agent and
report-metadata. TETHER_HUB and TETHER_TOKEN are required.

flags:
`

type options struct {
	hub         string
	token       string
	fingerprint string
	herdrBin    string
	hcBin       string
	watchBin    string
	pane        string
	source      string
	agent       string
	chat        string
	session     string
	poll        time.Duration
	watch       bool
	verbose     bool
}

func main() {
	var o options
	flag.StringVar(&o.hub, "hub", os.Getenv("TETHER_HUB"), "hub WebSocket URL (default $TETHER_HUB)")
	flag.StringVar(&o.token, "token", os.Getenv("TETHER_TOKEN"), "hub token (default $TETHER_TOKEN)")
	flag.StringVar(&o.fingerprint, "fingerprint", os.Getenv("TETHER_HUB_FINGERPRINT"), "hub certificate SHA-256 (default $TETHER_HUB_FINGERPRINT)")
	flag.StringVar(&o.herdrBin, "herdr-bin", firstEnv("TETHER_HERDR_BIN", "herdr"), "Herdr CLI for pane state reports")
	flag.StringVar(&o.hcBin, "hc-bin", firstEnv("TETHER_HC_BIN", "hc"), "herdr-core CLI, for optional terminal mapping")
	flag.StringVar(&o.watchBin, "watch-bin", firstEnv("TETHER_WATCH_BIN", "tetherctl"), "CLI used for optional watch terminals")
	flag.StringVar(&o.pane, "pane", os.Getenv("HERDR_PANE_ID"), "Herdr pane to update (default $HERDR_PANE_ID)")
	flag.StringVar(&o.source, "source", "tether", "source id for Herdr reports")
	flag.StringVar(&o.agent, "agent", "tether", "agent label for Herdr reports")
	flag.StringVar(&o.chat, "chat", os.Getenv("TETHER_CHAT"), "Tether chat this pane represents")
	flag.StringVar(&o.session, "session", os.Getenv("TETHER_SESSION"), "Tether session this pane represents")
	flag.DurationVar(&o.poll, "poll", 5*time.Second, "hub state poll interval; 0 disables state mirroring")
	flag.BoolVar(&o.watch, "watch", false, "open a herdr-core terminal that follows new chats and tasks")
	flag.BoolVar(&o.verbose, "verbose", false, "log bridge activity to stderr")
	flag.Usage = func() { fmt.Fprint(os.Stderr, usage); flag.PrintDefaults() }
	flag.Parse()

	if o.hub == "" || o.token == "" {
		flag.Usage()
		os.Exit(2)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	hub := newHubClient(o.hub, o.token, o.fingerprint)
	herdr := &herdrAdapter{
		runner:  &execRunner{bin: o.herdrBin},
		pane:    o.pane,
		source:  o.source,
		agent:   o.agent,
		verbose: o.verbose,
	}
	b := newBridge(hub, herdr, o)

	if o.poll > 0 {
		go b.pollLoop(ctx)
	}
	if err := b.serve(os.Stdin, os.Stdout); err != nil && !errors.Is(err, context.Canceled) {
		fmt.Fprintln(os.Stderr, "tether-herdr:", err)
		os.Exit(1)
	}
}

func firstEnv(names ...string) string {
	for _, n := range names {
		if v := os.Getenv(n); v != "" {
			return v
		}
	}
	return ""
}
