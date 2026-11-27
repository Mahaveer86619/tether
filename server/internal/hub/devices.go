package hub

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"net"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Pairing gives each app and agent its own revocable token in exchange for
// a one-time code, instead of everyone sharing the admin token. See
// docs/plans/plan.md#connecting-devices.

const (
	pairingTTL = 10 * time.Minute
	// No 0/O, 1/I/L: codes get read off a screen and typed.
	codeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
	codeLen      = 10
	// Failed pairings or token checks from one address before it is refused
	// until the window passes.
	failLimit  = 10
	failWindow = 10 * time.Minute
	// last_seen is written at most this often per device.
	seenEvery = time.Minute

	kindAdmin  = "admin"
	kindClient = "client"
	kindNode   = "node"
	// A machine of the hub owner's on the tailnet, trusted without a token
	// as an app or an agent of any name.
	kindTailnet = "tailnet"
)

var (
	errBadCode     = &opError{"invalid_code", "pairing code is wrong or has expired", http.StatusUnauthorized}
	errRateLimited = &opError{"rate_limited", "too many failed attempts; try again in a few minutes", http.StatusTooManyRequests}
)

// identity is who a token belongs to: the admin, or a paired device and
// the user it belongs to.
type identity struct {
	kind   string
	device *v1.Device
	user   *v1.User
}

// pairCode is a pairing code and the user whose device it pairs.
type pairCode struct {
	expires time.Time
	user    string
}

func (id identity) deviceID() string {
	if id.device == nil {
		return ""
	}
	return id.device.Id
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// identify checks a token against the admin token and paired devices.
func (h *Hub) identify(token string) (identity, bool) {
	if h.cfg.Token != "" && subtle.ConstantTimeCompare([]byte(token), []byte(h.cfg.Token)) == 1 {
		h.mu.Lock()
		defer h.mu.Unlock()
		return identity{kind: kindAdmin, user: h.users[h.ownerID]}, true
	}
	if token == "" {
		return identity{}, false
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	d := h.devices[hashToken(token)]
	if d == nil {
		return identity{}, false
	}
	u := h.users[firstNonEmpty(d.User, h.ownerID)]
	if u == nil {
		return identity{}, false
	}
	if now := time.Now().UnixMilli(); now-d.LastSeenMs > seenEvery.Milliseconds() {
		d.LastSeenMs = now
		if err := h.store.PutDevice(d, hashToken(token)); err != nil {
			h.log.Error("store device", "device", d.Id, "err", err)
		}
	}
	return identity{kind: d.Kind, device: d, user: u}, true
}

// identifyFrom also accepts the hub owner's own tailnet machines when the
// token doesn't check out, if the hub trusts its tailnet.
func (h *Hub) identifyFrom(token, ip string) (identity, bool) {
	if id, ok := h.identify(token); ok {
		return id, true
	}
	if h.cfg.TrustTailnet {
		if _, own := h.ownDevice(ip); own {
			h.mu.Lock()
			defer h.mu.Unlock()
			return identity{kind: kindTailnet, user: h.users[h.ownerID]}, true
		}
	}
	return identity{}, false
}

func remoteIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// limited reports whether ip has failed too often recently.
func (h *Hub) limited(ip string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	cutoff := time.Now().Add(-failWindow)
	recent := h.fails[ip][:0]
	for _, t := range h.fails[ip] {
		if t.After(cutoff) {
			recent = append(recent, t)
		}
	}
	if len(recent) == 0 {
		delete(h.fails, ip)
		return false
	}
	h.fails[ip] = recent
	return len(recent) >= failLimit
}

func (h *Hub) fail(ip string) {
	h.mu.Lock()
	h.fails[ip] = append(h.fails[ip], time.Now())
	h.mu.Unlock()
}

// newPairingCode creates a one-time code that pairs a device of user's.
// Caller holds h.mu.
func (h *Hub) newPairingCode(user string) (*v1.PairingCode, error) {
	now := time.Now()
	for c, pc := range h.codes {
		if now.After(pc.expires) {
			delete(h.codes, c)
		}
	}
	code, err := h.randomCode()
	if err != nil {
		return nil, err
	}
	exp := now.Add(pairingTTL)
	h.codes[code] = pairCode{expires: exp, user: firstNonEmpty(user, h.ownerID)}
	return &v1.PairingCode{
		Code:            code[:codeLen/2] + "-" + code[codeLen/2:],
		ExpiresMs:       exp.UnixMilli(),
		CertFingerprint: h.cfg.CertFingerprint,
	}, nil
}

func (h *Hub) randomCode() (string, error) {
	b := make([]byte, codeLen)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	for i := range b {
		b[i] = codeAlphabet[int(b[i])%len(codeAlphabet)]
	}
	return string(b), nil
}

// pair trades a pairing code, or an invite, for a device token. Caller
// holds h.mu.
func (h *Hub) pair(req *v1.PairRequest) (*v1.PairResult, *opError) {
	code := strings.ToUpper(strings.NewReplacer("-", "", " ", "").Replace(req.Code))
	pc, ok := h.codes[code]
	_, isInvite := h.invites[code]
	if isInvite && req.Kind != kindClient {
		return nil, invalid("an invite is entered in the app")
	}
	if !isInvite && (!ok || time.Now().After(pc.expires)) {
		return nil, errBadCode
	}
	if isInvite && strings.TrimSpace(req.UserName) == "" {
		return nil, invalid("an invite needs the name of the person joining")
	}
	name := strings.TrimSpace(req.Name)
	switch req.Kind {
	case kindClient:
		if name == "" {
			name = "device"
		}
	case kindNode:
		if name == "" {
			return nil, invalid("a node needs its name")
		}
	default:
		return nil, invalid(`kind must be "client" or "node"`)
	}
	user := pc.user
	if req.Kind == kindNode && h.nodes[name] != nil && h.nodeOwner(name) != user {
		return nil, errNameTaken
	}
	if isInvite {
		u, err := h.join(code, req.UserName)
		if err != nil {
			return nil, err
		}
		user = u.Id
	} else {
		delete(h.codes, code)
	}

	// Pairing a node again replaces its old token.
	if req.Kind == kindNode {
		for hash, d := range h.devices {
			if d.Kind == kindNode && d.Name == name {
				h.forgetDevice(hash, d)
			}
		}
	}
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	token := hex.EncodeToString(raw)
	now := time.Now().UnixMilli()
	d := &v1.Device{Id: uuid.NewString(), Kind: req.Kind, Name: name, Platform: req.Platform, CreatedMs: now, LastSeenMs: now, User: user}
	if err := h.store.PutDevice(d, hashToken(token)); err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	h.devices[hashToken(token)] = d
	h.log.Info("device paired", "device", d.Id, "kind", d.Kind, "name", d.Name, "platform", d.Platform, "user", user)
	return &v1.PairResult{Device: proto.Clone(d).(*v1.Device), Token: token, User: proto.Clone(h.users[user]).(*v1.User)}, nil
}

// deviceList is the devices id may see: their own, or all for an admin.
func (h *Hub) deviceList(id identity) *v1.DeviceList {
	out := &v1.DeviceList{}
	all := h.can(id, actAdmin, objHub, "")
	for _, d := range h.devices {
		if all || d.User == id.userID() {
			out.Devices = append(out.Devices, proto.Clone(d).(*v1.Device))
		}
	}
	sort.Slice(out.Devices, func(i, j int) bool { return out.Devices[i].CreatedMs < out.Devices[j].CreatedMs })
	return out
}

// revoke deletes a device and closes its live connections. Caller holds h.mu.
func (h *Hub) revoke(id string) (string, *opError) {
	for hash, d := range h.devices {
		if d.Id == id {
			h.forgetDevice(hash, d)
			return id, nil
		}
	}
	return "", &opError{"not_found", "unknown device", http.StatusNotFound}
}

func (h *Hub) forgetDevice(hash string, d *v1.Device) {
	delete(h.devices, hash)
	h.dropNotifyTokens(d.Id)
	if err := h.store.DeleteDevice(d.Id); err != nil {
		h.log.Error("delete device", "device", d.Id, "err", err)
	}
	for c := range h.clients {
		if c.device == d.Id {
			c.conn.Close(errors.New("device revoked"))
		}
	}
	if h.agentDevices[d.Name] == d.Id {
		if a := h.agents[d.Name]; a != nil {
			a.Close(errors.New("device revoked"))
		}
	}
	h.log.Info("device revoked", "device", d.Id, "name", d.Name)
}

// pairHandler serves POST /api/v1/pair, the one call that needs no token.
func (h *Hub) pairHandler(w http.ResponseWriter, r *http.Request) {
	ip := remoteIP(r)
	if h.limited(ip) {
		writeError(w, errRateLimited)
		return
	}
	req := &v1.PairRequest{}
	if err := decode(r, req); err != nil {
		writeError(w, err)
		return
	}
	h.mu.Lock()
	res, err := h.pair(req)
	h.mu.Unlock()
	if err != nil {
		if err == errBadCode {
			h.fail(ip)
		}
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, res)
}

// clientList is every app connected now, longest-connected first. Caller
// holds h.mu.
func (h *Hub) clientList() *v1.ClientList {
	out := &v1.ClientList{}
	for c := range h.clients {
		out.Clients = append(out.Clients, &v1.ConnectedClient{
			Name: c.name, Platform: c.platform, AppVersion: c.version, DeviceId: c.device, Ip: c.ip, ConnectedMs: c.since.UnixMilli(),
		})
	}
	sort.Slice(out.Clients, func(i, j int) bool { return out.Clients[i].ConnectedMs < out.Clients[j].ConnectedMs })
	return out
}
