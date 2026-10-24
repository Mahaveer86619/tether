package hub

import (
	"context"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/tailnet"
)

// The hub's view of its tailnet, so the app can show every machine and
// whether a Tether agent or app runs there. See docs/plan.md#connecting-devices.

const prefsKey = "preferences"

// TailscaleStatus runs `tailscale status --json` on the hub's machine.
func TailscaleStatus(ctx context.Context) ([]byte, error) {
	return tailnet.StatusCLI(ctx)
}

// tailnet lists the machines on the tailnet and what of Tether each runs.
func (h *Hub) tailnet(ctx context.Context) *v1.Tailnet {
	status := h.cfg.TailscaleStatus
	if status == nil {
		status = TailscaleStatus
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	out, err := status(ctx)
	if err != nil {
		return &v1.Tailnet{Error: "couldn't read tailscale status on the hub: " + err.Error()}
	}
	st, err := tailnet.ParseStatus(out)
	if err != nil {
		return &v1.Tailnet{Error: "couldn't parse tailscale status: " + err.Error()}
	}

	res := &v1.Tailnet{
		Devices: st.Devices(),
	}

	h.mu.Lock()
	byIP := map[string]*v1.TailnetDevice{}
	for _, d := range res.Devices {
		for _, ip := range d.Ips {
			byIP[ip] = d
		}
	}
	for node, ip := range h.agentIPs {
		if d := byIP[ip]; d != nil && h.agents[node] != nil {
			d.Node = node
		}
	}
	for c := range h.clients {
		if d := byIP[c.ip]; d != nil && c.name != "" {
			d.Clients = append(d.Clients, c.name)
		}
	}
	h.mu.Unlock()

	return res
}

// ownDevice reports whether ip belongs to a machine on the tailnet owned by
// the same Tailscale user as the hub's machine, and that machine's name.
func (h *Hub) ownDevice(ip string) (string, bool) {
	h.tsMu.Lock()
	defer h.tsMu.Unlock()
	if h.tsStatus == nil || time.Since(h.tsAt) > 30*time.Second {
		status := h.cfg.TailscaleStatus
		if status == nil {
			status = TailscaleStatus
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		out, err := status(ctx)
		cancel()
		if err != nil {
			return "", false
		}
		st, err := tailnet.ParseStatus(out)
		if err != nil || st.Self == nil {
			return "", false
		}
		h.tsStatus, h.tsAt = st, time.Now()
	}
	return h.tsStatus.OwnDevice(ip)
}

// setPreferences stores the shared app settings and sends them to every
// client. Caller holds h.mu.
func (h *Hub) setPreferences(p *v1.Preferences) *opError {
	b, err := proto.Marshal(p)
	if err == nil {
		err = h.store.Put(prefsKey, b)
	}
	if err != nil {
		return &opError{"internal", err.Error(), 500}
	}
	h.prefs = p
	h.broadcast(&v1.Frame{Body: &v1.Frame_Preferences{Preferences: proto.Clone(p).(*v1.Preferences)}})
	return nil
}
