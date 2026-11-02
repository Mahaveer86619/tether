package tailnet

import (
	"testing"
)

func TestParseStatusAndOwnDevice(t *testing.T) {
	raw := []byte(`{
		"Self": {
			"UserID": 100,
			"HostName": "mini-pc",
			"DNSName": "mini-pc.tailnet.ts.net.",
			"OS": "linux",
			"Online": true,
			"TailscaleIPs": ["100.64.0.1"]
		},
		"Peer": {
			"peer1": {
				"UserID": 100,
				"HostName": "laptop",
				"DNSName": "laptop.tailnet.ts.net.",
				"OS": "windows",
				"Online": true,
				"TailscaleIPs": ["100.64.0.2"],
				"LastSeen": "2026-10-24T12:00:00Z"
			},
			"peer2": {
				"UserID": 200,
				"HostName": "other",
				"DNSName": "other.tailnet.ts.net.",
				"OS": "linux",
				"Online": false,
				"TailscaleIPs": ["100.64.0.3"]
			}
		}
	}`)

	st, err := ParseStatus(raw)
	if err != nil {
		t.Fatalf("ParseStatus failed: %v", err)
	}

	devices := st.Devices()
	if len(devices) != 3 {
		t.Fatalf("expected 3 devices, got %d", len(devices))
	}
	if !devices[0].Self || devices[0].Name != "mini-pc" {
		t.Errorf("expected self device first, got %+v", devices[0])
	}

	name, ok := st.OwnDevice("100.64.0.2")
	if !ok || name != "laptop" {
		t.Errorf("expected own device laptop for 100.64.0.2, got (%q, %v)", name, ok)
	}

	name, ok = st.OwnDevice("100.64.0.3")
	if ok {
		t.Errorf("expected false for other user's device, got (%q, %v)", name, ok)
	}
}
