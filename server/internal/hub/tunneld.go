package hub

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// TunneldConfig points the hub at an on-demand-tunnel-cf server (tunneld),
// which owns the Cloudflare tunnel: the hub registers the notification
// listener with it and asks it, again and again, for the address.
type TunneldConfig struct {
	// URL is where tunneld's API answers, like http://127.0.0.1:7171.
	URL string
	// Token is tunneld's ADMIN_TOKEN, if it has one.
	Token string
	// Name is the tunnel's name in tunneld; its id is the same, lowercased.
	Name string
}

const tunneldPoll = 15 * time.Second

// runTunneld keeps one tunnel in tunneld pointed at the listener on port and
// publishes whatever address tunneld reports for it, until ctx ends.
func (h *Hub) runTunneld(ctx context.Context, cfg TunneldConfig, port int) {
	c := &tunneldClient{base: strings.TrimRight(cfg.URL, "/"), token: cfg.Token, name: cfg.Name, port: port, http: &http.Client{Timeout: 50 * time.Second}}
	backoff := 5 * time.Second
	registered := false
	for ctx.Err() == nil {
		wait := tunneldPoll
		if !registered {
			if err := c.ensure(ctx); err != nil {
				h.log.Warn("tunneld", "err", err)
				wait, backoff = backoff, min(backoff*2, time.Minute)
				sleep(ctx, wait)
				continue
			}
			registered = true
		}
		u, err := c.address(ctx)
		switch {
		case err == errTunnelGone:
			registered = false
			continue
		case err != nil:
			// tunneld may only be restarting: keep the last address meanwhile.
			h.log.Warn("tunneld", "err", err)
			wait, backoff = backoff, min(backoff*2, time.Minute)
		default:
			backoff = 5 * time.Second
			h.setNotifyURL(u)
			if u == "" {
				wait = 2 * time.Second
			}
		}
		sleep(ctx, wait)
	}
}

func sleep(ctx context.Context, d time.Duration) {
	select {
	case <-ctx.Done():
	case <-time.After(d):
	}
}

var errTunnelGone = fmt.Errorf("tunnel is not in tunneld")

type tunneldClient struct {
	base, token, name string
	port              int
	http              *http.Client
}

func (c *tunneldClient) id() string { return strings.ToLower(c.name) }

func (c *tunneldClient) do(ctx context.Context, method, path string, body any) (int, []byte, error) {
	var r io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		r = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.base+path, r)
	if err != nil {
		return 0, nil, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}
	res, err := c.http.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer res.Body.Close()
	b, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	return res.StatusCode, b, err
}

// ensure makes the tunnel exist, enabled, and aimed at this hub's listener.
func (c *tunneldClient) ensure(ctx context.Context) error {
	code, body, err := c.do(ctx, http.MethodPost, "/api/tunnels", map[string]any{"name": c.name, "port": c.port})
	if err != nil {
		return err
	}
	switch code {
	case http.StatusCreated, http.StatusOK:
		return nil
	case http.StatusConflict:
	default:
		return fmt.Errorf("tunneld refused the tunnel (%d): %s", code, strings.TrimSpace(string(body)))
	}
	code, body, err = c.do(ctx, http.MethodGet, "/api/tunnels/"+url.PathEscape(c.id()), nil)
	if err != nil {
		return err
	}
	if code != http.StatusOK {
		return fmt.Errorf("tunneld: reading the tunnel (%d)", code)
	}
	var t struct {
		Target  string `json:"target"`
		Enabled bool   `json:"enabled"`
	}
	if err := json.Unmarshal(body, &t); err != nil {
		return err
	}
	if _, p, err := net.SplitHostPort(strings.TrimPrefix(strings.TrimPrefix(t.Target, "http://"), "https://")); err == nil && p == strconv.Itoa(c.port) && t.Enabled {
		return nil
	}
	code, body, err = c.do(ctx, http.MethodPatch, "/api/tunnels/"+url.PathEscape(c.id()), map[string]any{"port": c.port, "enabled": true})
	if err != nil {
		return err
	}
	if code != http.StatusOK {
		return fmt.Errorf("tunneld: retargeting the tunnel (%d): %s", code, strings.TrimSpace(string(body)))
	}
	return nil
}

// address is the tunnel's public address, "" while it has none yet.
func (c *tunneldClient) address(ctx context.Context) (string, error) {
	code, body, err := c.do(ctx, http.MethodGet, "/api/tunnels/"+url.PathEscape(c.id())+"/url?format=text&wait=20s", nil)
	if err != nil {
		return "", err
	}
	switch code {
	case http.StatusOK:
		return strings.TrimSpace(string(body)), nil
	case http.StatusServiceUnavailable:
		return "", nil
	case http.StatusNotFound:
		return "", errTunnelGone
	}
	return "", fmt.Errorf("tunneld: asking for the address (%d)", code)
}
