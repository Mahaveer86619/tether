package agent

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"google.golang.org/protobuf/encoding/protojson"
)

// Background backups of every session to the hub, asked for by the hub
// while an app is in the foreground. Only transcripts that changed since the
// hub's copy go up, each with its subagents' transcripts and its details;
// see docs/plan.md#session-backups.

// backup uploads the sessions whose transcripts changed. One run at a time:
// a request arriving mid-run is skipped, and the next one catches up.
func (a *Agent) backup(stored map[string]int64) {
	if !a.backupMu.TryLock() {
		return
	}
	defer a.backupMu.Unlock()
	type due struct {
		id, path string
		size     int64
	}
	var todo []due
	for _, id := range a.index.IDs() {
		path := a.index.Path(id)
		st, err := os.Stat(path)
		if path == "" || err != nil || st.Size() == stored[id] || st.Size() > maxUpload {
			continue
		}
		todo = append(todo, due{id, path, st.Size()})
	}
	// Newest work first, in case the run is cut short.
	sort.Slice(todo, func(i, j int) bool {
		mi, _ := a.index.Modified(todo[i].id)
		mj, _ := a.index.Modified(todo[j].id)
		return mi.After(mj)
	})
	done := 0
	for _, d := range todo {
		if err := a.backupSession(d.id, d.path); err != nil {
			a.log.Warn("back up session", "session", d.id, "err", err)
			continue
		}
		done++
	}
	if len(todo) > 0 {
		a.log.Info("backed up sessions", "changed", len(todo), "uploaded", done)
	}
}

func (a *Agent) backupSession(id, path string) error {
	headers := func(p string) map[string]string {
		return map[string]string{"X-Session": id, "X-Origin": "backup", "X-Path": p}
	}
	// Details first, so a backup with a transcript always has them.
	if info := a.index.Info(id); info != nil {
		meta, err := protojson.MarshalOptions{Indent: "  "}.Marshal(info)
		if err == nil {
			if err := a.uploadBytes("meta.json", meta, headers("meta.json")); err != nil {
				return err
			}
		}
	}
	// Claude Code keeps a session's subagent transcripts in <session>/subagents/.
	subs, _ := filepath.Glob(filepath.Join(strings.TrimSuffix(path, ".jsonl"), "subagents", "*.jsonl"))
	for _, sub := range subs {
		if st, err := os.Stat(sub); err != nil || st.Size() > maxUpload {
			continue
		}
		if err := a.uploadFile(sub, headers("subagents/"+filepath.Base(sub))); err != nil {
			return err
		}
	}
	return a.uploadFile(path, headers("transcript"))
}

func (a *Agent) uploadBytes(name string, b []byte, headers map[string]string) error {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	req, err := a.hubRequest(ctx, http.MethodPost, "/api/v1/artifacts", watchdog(bytes.NewReader(b), cancel))
	if err != nil {
		return err
	}
	req.ContentLength = int64(len(b))
	req.Header.Set("X-Name", url.QueryEscape(name))
	req.Header.Set("X-Node", a.cfg.Node)
	req.Header.Set("Content-Type", "application/json")
	for k, v := range headers {
		req.Header.Set(k, url.QueryEscape(v))
	}
	res, err := a.hubClient().Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		msg, _ := io.ReadAll(io.LimitReader(res.Body, 512))
		return fmt.Errorf("hub said %s: %s", res.Status, msg)
	}
	return nil
}
