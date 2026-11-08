package hub

import (
	"bufio"
	"context"
	"net"
	"net/http"
	"os/exec"
	"regexp"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// The notification tunnel: a Cloudflare quick tunnel to a separate local
// listener that serves only /n/ping and /n/poll. The tunnel's address changes
// whenever cloudflared restarts, so the hub tells every connected app the new
// one, and an app that is on Tailscale keeps it for when it is not. Nothing
// else of the hub is reachable through it, and the notification text is
// left out unless Config.NotifyBodiesOnTunnel is set.

// TunnelConfig says how notifications are reached from outside the tailnet.
type TunnelConfig struct {
	// Cloudflared is the program that opens a quick tunnel; empty runs none.
	Cloudflared string
	// PublicURL is an address the owner already routes to the listener (a
	// named tunnel or a reverse proxy); it is published as it is.
	PublicURL string
	// Addr is where the scoped listener binds; empty picks a free local port.
	Addr string
}

var quickTunnelURL = regexp.MustCompile(`https://[a-z0-9-]+\.trycloudflare\.com`)

// tunnelURLIn finds a quick tunnel's address in a line cloudflared printed.
func tunnelURLIn(line string) string { return quickTunnelURL.FindString(line) }

// StartNotifyTunnel serves the scoped listener and publishes where it can be
// reached, until ctx ends.
func (h *Hub) StartNotifyTunnel(ctx context.Context, cfg TunnelConfig) error {
	addr := cfg.Addr
	if addr == "" {
		addr = "127.0.0.1:0"
	}
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	srv := &http.Server{Handler: h.scopedHandler(true), ReadHeaderTimeout: 10 * time.Second, IdleTimeout: 2 * time.Minute}
	go func() { _ = srv.Serve(ln) }()
	go func() {
		<-ctx.Done()
		_ = srv.Close()
	}()
	h.log.Info("notification listener", "addr", ln.Addr().String())

	switch {
	case cfg.PublicURL != "":
		h.setNotifyURL(cfg.PublicURL)
	case cfg.Cloudflared != "":
		go h.runTunnel(ctx, cfg.Cloudflared, ln.Addr().String())
	}
	return nil
}

// runTunnel keeps a quick tunnel to addr open, publishing each address it
// gets and trying again, slower each time, when it ends.
func (h *Hub) runTunnel(ctx context.Context, program, addr string) {
	backoff := 5 * time.Second
	for ctx.Err() == nil {
		started := time.Now()
		h.runTunnelOnce(ctx, program, addr)
		h.setNotifyURL("")
		if time.Since(started) > time.Minute {
			backoff = 5 * time.Second
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(backoff):
		}
		backoff = min(backoff*2, 5*time.Minute)
	}
}

func (h *Hub) runTunnelOnce(ctx context.Context, program, addr string) {
	cmd := exec.CommandContext(ctx, program, "tunnel", "--no-autoupdate", "--url", "http://"+addr)
	stderr, err := cmd.StderrPipe()
	if err != nil {
		h.log.Warn("notification tunnel", "err", err)
		return
	}
	if err := cmd.Start(); err != nil {
		h.log.Warn("notification tunnel: could not start cloudflared", "program", program, "err", err)
		return
	}
	sc := bufio.NewScanner(stderr)
	for sc.Scan() {
		if u := tunnelURLIn(sc.Text()); u != "" {
			h.setNotifyURL(u)
		}
	}
	err = cmd.Wait()
	h.log.Warn("notification tunnel ended", "err", err)
}

// setNotifyURL records the tunnel's address and tells every client.
func (h *Hub) setNotifyURL(url string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.notifyURL == url {
		return
	}
	h.notifyURL = url
	h.log.Info("notification address", "url", url)
	h.broadcast(&v1.Frame{Body: &v1.Frame_NotifyEndpoint{NotifyEndpoint: &v1.NotifyEndpoint{Url: url}}})
}
