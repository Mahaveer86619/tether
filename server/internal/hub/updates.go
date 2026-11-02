package hub

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Releases reach the hub two ways: the deploy script puts a release's
// latest.json and files in <updates>/<version>/, or the hub polls the
// GitHub release feed and downloads them there. The hub serves them, tells
// apps, and moves idle agents to the new version. See docs/releasing.md.

const (
	feedEvery        = 30 * time.Minute
	localCheckEvery  = time.Minute
	agentRetryAfter  = 30 * time.Minute
	agentMaxAttempts = 3
	keepReleases     = 2
)

// Files the hub keeps so apps and agents can update without reaching
// GitHub; the rest stay links to the release.
var servedPlatforms = map[string]bool{"android": true, "windows": true, "agent-linux-amd64": true, "agent-windows-amd64": true}

var safeName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._+-]*$`)

type agentUpdate struct {
	version  string
	at       time.Time
	attempts int
}

func (h *Hub) updatesDir() string {
	if h.cfg.UpdatesDir != "" {
		return h.cfg.UpdatesDir
	}
	return filepath.Join(h.cfg.DataDir, "updates")
}

// loadLocalUpdate reads the newest release in the updates folder, if it's
// newer than the one known. Caller holds h.mu.
func (h *Hub) loadLocalUpdate() {
	entries, err := os.ReadDir(h.updatesDir())
	if err != nil {
		return
	}
	var best *v1.UpdateManifest
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		m, err := readManifest(filepath.Join(h.updatesDir(), e.Name(), "latest.json"))
		if err != nil || m.Version != e.Name() {
			continue
		}
		if best == nil || !versionAtLeast(best.Version, m.Version) {
			best = m
		}
	}
	if best != nil {
		h.setUpdate(best)
	}
}

func readManifest(path string) (*v1.UpdateManifest, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	m := &v1.UpdateManifest{}
	if err := jsonIn.Unmarshal(b, m); err != nil {
		return nil, err
	}
	if _, ok := parseVersion(m.Version); !ok {
		return nil, fmt.Errorf("bad version %q", m.Version)
	}
	return m, nil
}

// setUpdate makes m the known release if it's newer, tells every app and
// starts agent updates. Caller holds h.mu.
func (h *Hub) setUpdate(m *v1.UpdateManifest) {
	if covers(h.update, m) {
		return
	}
	h.update = m
	h.log.Info("release available", "version", m.Version)
	h.broadcast(&v1.Frame{Body: &v1.Frame_UpdateAvailable{UpdateAvailable: h.servedManifest()}})
	for node := range h.agents {
		h.maybeUpdateAgent(node)
	}
}

// servedManifest is the known release with links to the hub for the files
// it has. Caller holds h.mu.
func (h *Hub) servedManifest() *v1.UpdateManifest {
	if h.update == nil {
		return nil
	}
	m := proto.Clone(h.update).(*v1.UpdateManifest)
	for _, a := range m.Platforms {
		if _, err := os.Stat(filepath.Join(h.updatesDir(), m.Version, a.Name)); err == nil && safeName.MatchString(a.Name) {
			a.Url = "/api/v1/updates/files/" + m.Version + "/" + url.PathEscape(a.Name)
		}
	}
	return m
}

// maybeUpdateAgent asks an idle agent older than the known release to
// update itself, a few times at most. Caller holds h.mu.
func (h *Hub) maybeUpdateAgent(node string) {
	if !h.cfg.AutoUpdateAgents || h.update == nil {
		return
	}
	conn, st := h.agents[node], h.nodes[node]
	if conn == nil || st == nil || st.RunningSessions > 0 || versionAtLeast(st.AgentVersion, h.update.Version) {
		return
	}
	if _, ok := parseVersion(st.AgentVersion); !ok {
		return // a dev build
	}
	// Agents from before self-update ignore the command; they're updated by hand.
	if !versionAtLeast(st.AgentVersion, selfUpdateVersion) {
		return
	}
	m := h.servedManifest()
	asset := m.Platforms["agent-"+st.Os+"-amd64"]
	if asset == nil || !strings.HasPrefix(asset.Url, "/") {
		return
	}
	prev := h.agentUpdates[node]
	if prev.version == m.Version && (prev.attempts >= agentMaxAttempts || time.Since(prev.at) < agentRetryAfter) {
		return
	}
	if prev.version != m.Version {
		prev = agentUpdate{version: m.Version}
	}
	prev.at, prev.attempts = time.Now(), prev.attempts+1
	h.agentUpdates[node] = prev
	h.log.Info("asking agent to update", "node", node, "from", st.AgentVersion, "to", m.Version, "attempt", prev.attempts)
	conn.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_SelfUpdate_{SelfUpdate: &v1.AgentCommand_SelfUpdate{Version: m.Version, Asset: asset}}}))
}

// The first agent that updates itself.
const selfUpdateVersion = "0.17.0"

// updateLoop picks up releases from the updates folder and the feed.
func (h *Hub) updateLoop(ctx context.Context) {
	local := time.NewTicker(localCheckEvery)
	defer local.Stop()
	var feed <-chan time.Time
	if h.cfg.UpdateFeed != "" {
		t := time.NewTicker(feedEvery)
		defer t.Stop()
		feed = t.C
		go h.pollFeed(ctx)
	}
	for {
		select {
		case <-ctx.Done():
			return
		case <-local.C:
			h.mu.Lock()
			h.loadLocalUpdate()
			for node := range h.agents {
				h.maybeUpdateAgent(node)
			}
			h.mu.Unlock()
		case <-feed:
			h.pollFeed(ctx)
		}
	}
}

// pollFeed fetches the published latest.json and, when it's newer, the
// files the hub serves, checking each against its sha256.
func (h *Hub) pollFeed(ctx context.Context) {
	m, err := fetchManifest(ctx, h.cfg.UpdateFeed)
	if err != nil {
		h.log.Warn("update feed", "err", err)
		return
	}
	h.mu.Lock()
	known := covers(h.update, m)
	h.mu.Unlock()
	if known {
		return
	}
	dir := filepath.Join(h.updatesDir(), m.Version)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		h.log.Error("updates folder", "err", err)
		return
	}
	for key, a := range m.Platforms {
		if !servedPlatforms[key] || !safeName.MatchString(a.Name) {
			continue
		}
		if err := fetchAsset(ctx, a, filepath.Join(dir, a.Name)); err != nil {
			h.log.Warn("update file", "name", a.Name, "err", err)
			return
		}
	}
	b, _ := protojson.MarshalOptions{UseProtoNames: true, Multiline: true}.Marshal(m)
	if err := writeAtomic(filepath.Join(dir, "latest.json"), b); err != nil {
		h.log.Error("save latest.json", "err", err)
		return
	}
	h.pruneReleases(m.Version)
	h.mu.Lock()
	h.setUpdate(m)
	h.mu.Unlock()
}

var feedClient = &http.Client{Timeout: 30 * time.Minute}

func fetchManifest(ctx context.Context, feed string) (*v1.UpdateManifest, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, feed, nil)
	if err != nil {
		return nil, err
	}
	res, err := feedClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("feed said %s", res.Status)
	}
	b, err := io.ReadAll(io.LimitReader(res.Body, maxBody))
	if err != nil {
		return nil, err
	}
	m := &v1.UpdateManifest{}
	if err := jsonIn.Unmarshal(b, m); err != nil {
		return nil, err
	}
	if _, ok := parseVersion(m.Version); !ok {
		return nil, fmt.Errorf("feed has a bad version %q", m.Version)
	}
	return m, nil
}

func fetchAsset(ctx context.Context, a *v1.UpdateAsset, dst string) error {
	if sum, err := fileSum(dst); err == nil && sum == a.Sha256 {
		return nil
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.Url, nil)
	if err != nil {
		return err
	}
	res, err := feedClient.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("%s said %s", a.Url, res.Status)
	}
	tmp := dst + ".part"
	f, err := os.Create(tmp)
	if err != nil {
		return err
	}
	sum := sha256.New()
	_, err = io.Copy(io.MultiWriter(f, sum), res.Body)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		os.Remove(tmp)
		return err
	}
	if got := hex.EncodeToString(sum.Sum(nil)); !strings.EqualFold(got, a.Sha256) {
		os.Remove(tmp)
		return fmt.Errorf("sha256 is %s, want %s", got, a.Sha256)
	}
	return os.Rename(tmp, dst)
}

func fileSum(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func writeAtomic(path string, b []byte) error {
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// pruneReleases keeps the newest few release folders.
func (h *Hub) pruneReleases(current string) {
	entries, err := os.ReadDir(h.updatesDir())
	if err != nil {
		return
	}
	var versions []string
	for _, e := range entries {
		if _, ok := parseVersion(e.Name()); ok && e.IsDir() {
			versions = append(versions, e.Name())
		}
	}
	sort.Slice(versions, func(i, j int) bool { return !versionAtLeast(versions[i], versions[j]) })
	for len(versions) > keepReleases {
		if versions[0] != current {
			_ = os.RemoveAll(filepath.Join(h.updatesDir(), versions[0]))
		}
		versions = versions[1:]
	}
}

func (h *Hub) updateRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/updates/latest", h.api(func(r *http.Request) (proto.Message, *opError) {
		if m := h.servedManifest(); m != nil {
			return m, nil
		}
		return &v1.UpdateManifest{}, nil
	}))
	// Agents fetch their own update here, so node tokens are let in.
	mux.HandleFunc("GET /api/v1/updates/files/{version}/{name}", func(w http.ResponseWriter, r *http.Request) {
		if _, err := h.auth(r, true); err != nil {
			writeError(w, err)
			return
		}
		v, name := r.PathValue("version"), r.PathValue("name")
		if _, ok := parseVersion(v); !ok || !safeName.MatchString(name) {
			writeError(w, errNotFound)
			return
		}
		w.Header().Set("Content-Disposition", `attachment; filename="`+name+`"`)
		http.ServeFile(w, r, filepath.Join(h.updatesDir(), v, name))
	})
}

// covers reports whether release a makes b redundant: newer, or the same
// version with at least its files. The hub deploys a release before CI has
// built the Windows app, then takes the published one with it.
func covers(a, b *v1.UpdateManifest) bool {
	if a == nil {
		return false
	}
	if a.Version != b.Version {
		return versionAtLeast(a.Version, b.Version)
	}
	return len(a.Platforms) >= len(b.Platforms)
}
