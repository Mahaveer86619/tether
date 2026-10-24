package agent

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// History sync: the hub keeps every session's transcript. When it asks
// (on connect and every few minutes) it says how far it has each file; the
// agent sends the rest in chunks of whole lines and waits for each to be
// taken in. A file that no longer starts as the hub's copy does was
// rewritten, and goes again from the start. See docs/history.md.

const (
	historyChunk = 256 << 10
	// A single line larger than this is skipped, not sent.
	historyLineMax = 32 << 20
	historyAckWait = time.Minute
	// A pause between chunks, so a backfill leaves room for live traffic.
	historyPause = 20 * time.Millisecond
)

var errNoAck = errors.New("the hub didn't take the chunk in")

type historyKey struct{ session, file string }

// syncHistory runs one sync at a time; a request that comes in meanwhile
// is kept, and the newest one runs when the current run ends.
func (a *Agent) syncHistory(positions []*v1.HistoryPosition) {
	a.mu.Lock()
	a.historyNext = positions
	a.historyAsked = true
	a.mu.Unlock()
	if !a.historyMu.TryLock() {
		return
	}
	defer a.historyMu.Unlock()
	for {
		a.mu.Lock()
		asked, next := a.historyAsked, a.historyNext
		a.historyAsked, a.historyNext = false, nil
		a.mu.Unlock()
		if !asked {
			return
		}
		a.syncOnce(next)
	}
}

func (a *Agent) syncOnce(positions []*v1.HistoryPosition) {
	known := make(map[historyKey]*v1.HistoryPosition, len(positions))
	for _, p := range positions {
		known[historyKey{p.Session, p.File}] = p
	}
	ids := a.index.IDs()
	// Newest work first, so a backfill brings recent sessions quickly.
	sort.Slice(ids, func(i, j int) bool {
		mi, _ := a.index.Modified(ids[i])
		mj, _ := a.index.Modified(ids[j])
		return mi.After(mj)
	})
	sent := 0
	for _, id := range ids {
		path := a.index.Path(id)
		if path == "" {
			continue
		}
		files := []historyKey{{id, ""}}
		paths := []string{path}
		subs, _ := filepath.Glob(filepath.Join(strings.TrimSuffix(path, ".jsonl"), "subagents", "*.jsonl"))
		for _, sub := range subs {
			files = append(files, historyKey{id, "subagents/" + filepath.Base(sub)})
			paths = append(paths, sub)
		}
		for i, k := range files {
			n, err := a.syncFile(k, paths[i], known[k])
			sent += n
			if err != nil {
				a.log.Warn("history sync stopped", "session", id, "err", err)
				return
			}
		}
	}
	if sent > 0 {
		a.log.Info("history synced", "bytes", sent)
	}
	a.send(&v1.Frame{Body: &v1.Frame_HistorySynced{HistorySynced: &v1.HistorySynced{AtMs: time.Now().UnixMilli()}}})
}

// syncFile sends what the hub lacks of one file; it returns the bytes sent.
func (a *Agent) syncFile(k historyKey, path string, have *v1.HistoryPosition) (int, error) {
	st, err := os.Stat(path)
	if err != nil {
		return 0, nil
	}
	from, reset := int64(0), false
	if have != nil {
		from = have.Offset
		if st.Size() < from || !sameHead(path, have.Head, have.HeadLen) {
			from, reset = 0, true
		}
	}
	f, err := os.Open(path)
	if err != nil {
		return 0, nil
	}
	defer f.Close()
	sent, stuck := 0, 0
	for from < st.Size() {
		if _, err := f.Seek(from, io.SeekStart); err != nil {
			return sent, err
		}
		data, skip := readChunk(bufio.NewReaderSize(f, 64<<10))
		if len(data) == 0 && skip == 0 {
			return sent, nil // only a line still being written
		}
		next, err := a.sendChunk(&v1.HistoryChunk{Session: k.session, File: k.file, Offset: from, Data: data, Reset_: reset, Size: st.Size(), Skip: skip})
		if err != nil {
			return sent, err
		}
		sent += len(data)
		reset = false
		if want := from + int64(len(data)) + skip; next != want {
			// The hub has the file up to somewhere else; go from there,
			// unless it keeps not moving.
			if next <= from {
				if stuck++; stuck > 3 {
					return sent, fmt.Errorf("the hub keeps asking for %s from %d", k.file, next)
				}
			}
		}
		from = next
		time.Sleep(historyPause)
	}
	return sent, nil
}

// readChunk reads whole lines, up to historyChunk bytes or one longer line.
// A line too long to send comes back as skip, its length. A last line
// without its line break is left for later.
func readChunk(r *bufio.Reader) (data []byte, skip int64) {
	for len(data) < historyChunk {
		line, err := r.ReadBytes('\n')
		if err != nil {
			return data, 0
		}
		if len(line) > historyLineMax {
			if len(data) > 0 {
				return data, 0
			}
			return nil, int64(len(line))
		}
		if len(data) > 0 && len(data)+len(line) > historyChunk {
			return data, 0
		}
		data = append(data, line...)
	}
	return data, 0
}

// sendChunk sends a chunk and waits for the hub to say how far it has the
// file now.
func (a *Agent) sendChunk(c *v1.HistoryChunk) (int64, error) {
	// Drop an ack left over from a chunk that timed out.
	select {
	case <-a.historyAcks:
	default:
	}
	a.mu.Lock()
	conn := a.conn
	a.mu.Unlock()
	if conn == nil {
		return 0, errors.New("not connected")
	}
	conn.Send(&v1.Frame{Body: &v1.Frame_HistoryChunk{HistoryChunk: c}})
	timer := time.NewTimer(historyAckWait)
	defer timer.Stop()
	for {
		select {
		case ack := <-a.historyAcks:
			if ack.Session == c.Session && ack.File == c.File {
				return ack.Offset, nil
			}
		case <-conn.Done():
			return 0, errors.New("connection lost")
		case <-timer.C:
			return 0, errNoAck
		}
	}
}

// sameHead reports whether path starts with the bytes the hub hashed.
func sameHead(path, head string, n int64) bool {
	if n == 0 {
		return true
	}
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	h := sha256.New()
	if got, err := io.CopyN(h, f, n); err != nil || got != n {
		return false
	}
	return hex.EncodeToString(h.Sum(nil)) == head
}
