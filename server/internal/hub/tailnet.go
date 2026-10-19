package hub

import (
	"context"
	"encoding/json"
	"os/exec"
	"sort"
	"strings"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// The hub's view of its tailnet, so the app can show every machine and
// whether a Tether agent or app runs there. See docs/plan.md#connecting-devices.

const prefsKey = "preferences"

// TailscaleStatus runs `tailscale status --json` on the hub's machine.
func TailscaleStatus(ctx context.Context) ([]byte, error) {
	return exec.CommandContext(ctx, "tailscale", "status", "--json").Output()
}

type tsStatus struct {
	Self *tsPeer
	Peer map[string]*tsPeer
}

type tsPeer struct {
	UserID       int64
	HostName     string
	DNSName      string
	OS           string
	Online       bool
	TailscaleIPs []string
	LastSeen     time.Time
}

func (p *tsPeer) device(self bool) *v1.TailnetDevice {
	name, _, _ := strings.Cut(p.DNSName, ".")
	if name == "" {
		name = strings.ToLower(p.HostName)
	}
	d := &v1.TailnetDevice{Name: name, Hostname: p.HostName, Os: p.OS, Online: p.Online || self, Ips: p.TailscaleIPs, Self: self}
	if !p.LastSeen.IsZero() && p.LastSeen.Year() > 2000 {
		d.LastSeenMs = p.LastSeen.UnixMilli()
	}
	return d
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
	var st tsStatus
	if err := json.Unmarshal(out, &st); err != nil {
		return &v1.Tailnet{Error: "couldn't parse tailscale status: " + err.Error()}
	}

	res := &v1.Tailnet{}
	if st.Self != nil {
		res.Devices = append(res.Devices, st.Self.device(true))
	}
	for _, p := range st.Peer {
		res.Devices = append(res.Devices, p.device(false))
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

	sort.Slice(res.Devices, func(i, j int) bool {
		a, b := res.Devices[i], res.Devices[j]
		if a.Self != b.Self {
			return a.Self
		}
		if a.Online != b.Online {
			return a.Online
		}
		return a.Name < b.Name
	})
	return res
}

// ownDevice reports whether ip belongs to a machine on the tailnet owned by
// the same Tailscale user as the hub's machine, and that machine's name.
// Tailscale only delivers 100.x traffic from the tailnet interface, so the
// address can be trusted. The status is cached briefly; it costs a process.
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
		var st tsStatus
		if err != nil || json.Unmarshal(out, &st) != nil || st.Self == nil {
			return "", false
		}
		h.tsStatus, h.tsAt = &st, time.Now()
	}
	st := h.tsStatus
	for _, p := range append([]*tsPeer{st.Self}, mapValues(st.Peer)...) {
		for _, a := range p.TailscaleIPs {
			if a == ip && p.UserID == st.Self.UserID {
				return p.device(false).Name, true
			}
		}
	}
	return "", false
}

func mapValues[K comparable, V any](m map[K]V) []V {
	out := make([]V, 0, len(m))
	for _, v := range m {
		out = append(out, v)
	}
	return out
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
