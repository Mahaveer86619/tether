package wire

import (
	"bytes"
	"context"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// HTTPClient returns a client for the hub. With a fingerprint (the SHA-256
// of a self-signed hub certificate, from pairing) it trusts that certificate
// and no other; without one it uses the system's CAs.
func HTTPClient(fingerprint string) *http.Client {
	if fingerprint == "" {
		return &http.Client{Timeout: 30 * time.Second}
	}
	want := strings.ToLower(strings.ReplaceAll(fingerprint, ":", ""))
	tr := http.DefaultTransport.(*http.Transport).Clone()
	tr.TLSClientConfig = &tls.Config{
		// Verification happens below, against the pinned fingerprint.
		InsecureSkipVerify: true,
		VerifyPeerCertificate: func(raw [][]byte, _ [][]*x509.Certificate) error {
			if len(raw) == 0 {
				return errors.New("hub sent no certificate")
			}
			sum := sha256.Sum256(raw[0])
			if hex.EncodeToString(sum[:]) != want {
				return errors.New("hub certificate does not match the pinned fingerprint")
			}
			return nil
		},
	}
	return &http.Client{Transport: tr, Timeout: 30 * time.Second}
}

// HTTPBase turns a hub WebSocket URL into the base URL of its REST API.
func HTTPBase(wsURL string) string {
	u := strings.Replace(strings.Replace(wsURL, "wss://", "https://", 1), "ws://", "http://", 1)
	return strings.TrimSuffix(u, "/ws")
}

// Pair trades a one-time pairing code for a device token.
func Pair(ctx context.Context, hubURL, fingerprint string, req *v1.PairRequest) (*v1.PairResult, error) {
	body, err := marshal.Marshal(req)
	if err != nil {
		return nil, err
	}
	r, err := http.NewRequestWithContext(ctx, http.MethodPost, HTTPBase(hubURL)+"/api/v1/pair", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	r.Header.Set("Content-Type", "application/json")
	resp, err := HTTPClient(fingerprint).Do(r)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		e := &v1.Error{}
		if unmarshal.Unmarshal(b, e) == nil && e.Message != "" {
			return nil, errors.New(e.Message)
		}
		return nil, fmt.Errorf("pairing failed: %s", resp.Status)
	}
	res := &v1.PairResult{}
	return res, unmarshal.Unmarshal(b, res)
}
