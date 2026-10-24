// Package tailnet checks Tailscale network status and maps connected peers.
package tailnet

import (
	"context"
	"encoding/json"
	"os/exec"
	"sort"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// StatusFunc is a function that returns the output of `tailscale status --json`.
type StatusFunc func(context.Context) ([]byte, error)

// StatusCLI runs `tailscale status --json` on the current machine.
func StatusCLI(ctx context.Context) ([]byte, error) {
	return exec.CommandContext(ctx, "tailscale", "status", "--json").Output()
}

// Status represents the parsed output of `tailscale status --json`.
type Status struct {
	Self *Peer            `json:"Self"`
	Peer map[string]*Peer `json:"Peer"`
}

// Peer represents one node in the Tailscale status output.
type Peer struct {
	UserID       int64     `json:"UserID"`
	HostName     string    `json:"HostName"`
	DNSName      string    `json:"DNSName"`
	OS           string    `json:"OS"`
	Online       bool      `json:"Online"`
	TailscaleIPs []string  `json:"TailscaleIPs"`
	LastSeen     time.Time `json:"LastSeen"`
}

// Device formats a peer as a Protobuf TailnetDevice.
func (p *Peer) Device(self bool) *v1.TailnetDevice {
	name, _, _ := strings.Cut(p.DNSName, ".")
	if name == "" {
		name = strings.ToLower(p.HostName)
	}
	d := &v1.TailnetDevice{
		Name:     name,
		Hostname: p.HostName,
		Os:       p.OS,
		Online:   p.Online || self,
		Ips:      p.TailscaleIPs,
		Self:     self,
	}
	if !p.LastSeen.IsZero() && p.LastSeen.Year() > 2000 {
		d.LastSeenMs = p.LastSeen.UnixMilli()
	}
	return d
}

// ParseStatus parses raw JSON output from `tailscale status --json`.
func ParseStatus(data []byte) (*Status, error) {
	var st Status
	if err := json.Unmarshal(data, &st); err != nil {
		return nil, err
	}
	return &st, nil
}

// Devices returns all tailnet devices sorted with Self first, then online status, then name.
func (st *Status) Devices() []*v1.TailnetDevice {
	if st == nil {
		return nil
	}
	var devices []*v1.TailnetDevice
	if st.Self != nil {
		devices = append(devices, st.Self.Device(true))
	}
	for _, p := range st.Peer {
		devices = append(devices, p.Device(false))
	}
	sort.Slice(devices, func(i, j int) bool {
		a, b := devices[i], devices[j]
		if a.Self != b.Self {
			return a.Self
		}
		if a.Online != b.Online {
			return a.Online
		}
		return a.Name < b.Name
	})
	return devices
}

// OwnDevice reports whether ip belongs to a machine on the tailnet owned by
// the same Tailscale user as the Self machine, returning the device name and true.
func (st *Status) OwnDevice(ip string) (string, bool) {
	if st == nil || st.Self == nil {
		return "", false
	}
	peers := make([]*Peer, 0, len(st.Peer)+1)
	peers = append(peers, st.Self)
	for _, p := range st.Peer {
		peers = append(peers, p)
	}
	for _, p := range peers {
		for _, a := range p.TailscaleIPs {
			if a == ip && p.UserID == st.Self.UserID {
				return p.Device(false).Name, true
			}
		}
	}
	return "", false
}
