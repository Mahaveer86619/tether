// Command tether-hub is the central server the agents and apps connect to.
package main

import (
	"context"
	"crypto/tls"
	"errors"
	"flag"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/Mahaveer86619/tether/server/internal/hub"
	"github.com/Mahaveer86619/tether/server/internal/store"
	"github.com/Mahaveer86619/tether/server/internal/version"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:7420", "listen address; use the machine's Tailscale IP to reach it from other devices")
	dbPath := flag.String("db", "tether.db", "SQLite database path")
	useTLS := flag.Bool("tls", false, "serve HTTPS/WSS with a self-signed certificate kept next to the database; clients pin it when pairing")
	certFile := flag.String("tls-cert", "", "serve TLS with this certificate (e.g. from Let's Encrypt) instead of a self-signed one")
	keyFile := flag.String("tls-key", "", "private key for -tls-cert")
	insecure := flag.Bool("insecure", false, "allow plain HTTP on a public address (not recommended)")
	trustTailnet := flag.Bool("trust-tailnet", false, "let apps and agents on machines owned by this machine's Tailscale user connect without a token")
	updateFeed := flag.String("update-feed", "https://github.com/Mahaveer86619/tether/releases/latest/download/latest.json", "a published latest.json to poll for releases; empty turns polling off")
	updatesDir := flag.String("updates-dir", "", "where releases are kept and served from (default: updates next to the database)")
	autoAgents := flag.Bool("update-agents", true, "tell idle agents older than the newest release to update themselves")
	redact := flag.Bool("history-redact", true, "take tokens, keys and passwords out of the stored history")
	keepDays := flag.Int("history-keep-days", 0, "drop a session's history after this many days untouched (0 keeps it)")
	maxMB := flag.Int("history-max-mb", 0, "drop the oldest sessions' history beyond this many MB (0: no limit)")
	flag.Parse()

	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	token := os.Getenv("TETHER_TOKEN")
	if token == "" {
		log.Error("TETHER_TOKEN is not set")
		os.Exit(2)
	}

	host, _, err := net.SplitHostPort(*addr)
	if err != nil {
		log.Error("bad -addr", "err", err)
		os.Exit(2)
	}
	var tlsConf *tls.Config
	fp := ""
	switch {
	case *certFile != "":
		cert, err := tls.LoadX509KeyPair(*certFile, *keyFile)
		if err != nil {
			log.Error("load TLS certificate", "err", err)
			os.Exit(1)
		}
		tlsConf = &tls.Config{Certificates: []tls.Certificate{cert}}
	case *useTLS:
		dir := filepath.Dir(*dbPath)
		cert, err := selfSigned(filepath.Join(dir, "tls-cert.pem"), filepath.Join(dir, "tls-key.pem"), host)
		if err != nil {
			log.Error("self-signed certificate", "err", err)
			os.Exit(1)
		}
		tlsConf = &tls.Config{Certificates: []tls.Certificate{cert}}
		fp = fingerprint(cert)
		log.Info("serving TLS with a self-signed certificate", "sha256", fp)
	case !private(host) && !*insecure:
		log.Error("refusing plain HTTP on a public address; use -tls (or -tls-cert), or -insecure", "addr", *addr)
		os.Exit(2)
	}

	st, err := store.Open(*dbPath)
	if err != nil {
		log.Error("open database", "err", err)
		os.Exit(1)
	}
	defer st.Close()

	h, err := hub.New(hub.Config{Token: token, Version: version.Version, Log: log, CertFingerprint: fp, TrustTailnet: *trustTailnet, DataDir: filepath.Dir(*dbPath),
		UpdatesDir: *updatesDir, UpdateFeed: *updateFeed, AutoUpdateAgents: *autoAgents,
		HistoryRedact: *redact, HistoryKeepDays: *keepDays, HistoryMaxMB: *maxMB}, st)
	if err != nil {
		log.Error("start hub", "err", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go h.Run(ctx)

	// No ReadTimeout or WriteTimeout: they cap a whole request, and a file of
	// several GB over a phone's connection can take hours either way.
	srv := &http.Server{Addr: *addr, Handler: h.Handler(), ReadHeaderTimeout: 10 * time.Second, IdleTimeout: 2 * time.Minute, TLSConfig: tlsConf}
	go func() {
		<-ctx.Done()
		sctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = srv.Shutdown(sctx)
	}()
	log.Info("tether-hub listening", "addr", *addr, "tls", tlsConf != nil, "version", version.Version)
	serve := srv.ListenAndServe
	if tlsConf != nil {
		serve = func() error { return srv.ListenAndServeTLS("", "") }
	}
	if err := serve(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Error("serve", "err", err)
		os.Exit(1)
	}
}
