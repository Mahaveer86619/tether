// Command tether-hub is the central server the agents and apps connect to.
package main

import (
	"context"
	"errors"
	"flag"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Mahaveer86619/tether/server/internal/hub"
	"github.com/Mahaveer86619/tether/server/internal/store"
	"github.com/Mahaveer86619/tether/server/internal/version"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:7420", "listen address; use the machine's Tailscale IP to reach it from other devices")
	dbPath := flag.String("db", "tether.db", "SQLite database path")
	flag.Parse()

	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	token := os.Getenv("TETHER_TOKEN")
	if token == "" {
		log.Error("TETHER_TOKEN is not set")
		os.Exit(2)
	}

	st, err := store.Open(*dbPath)
	if err != nil {
		log.Error("open database", "err", err)
		os.Exit(1)
	}
	defer st.Close()

	h, err := hub.New(hub.Config{Token: token, Version: version.Version, Log: log}, st)
	if err != nil {
		log.Error("start hub", "err", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go h.Run(ctx)

	srv := &http.Server{Addr: *addr, Handler: h.Handler(), ReadHeaderTimeout: 10 * time.Second}
	go func() {
		<-ctx.Done()
		sctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = srv.Shutdown(sctx)
	}()
	log.Info("tether-hub listening", "addr", *addr, "version", version.Version)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Error("serve", "err", err)
		os.Exit(1)
	}
}
