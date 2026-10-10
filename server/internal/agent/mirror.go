package agent

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"os"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

var mirrorTypes = map[string]bool{"user": true, "assistant": true, "system": true, "ai-title": true, "custom-title": true}

func (a *Agent) startMirror(session string, from int64) {
	ctx, cancel := context.WithCancel(context.Background())
	a.mu.Lock()
	if stop := a.mirrors[session]; stop != nil {
		stop()
	}
	a.mirrors[session] = cancel
	a.mu.Unlock()
	go a.mirror(ctx, session, from)
}

// mirror streams a transcript from an offset and keeps tailing it, which is
// how terminal sessions show up live in the app.
func (a *Agent) mirror(ctx context.Context, session string, off int64) {
	t := time.NewTicker(tailInterval)
	defer t.Stop()
	for {
		if path := a.index.Path(session); path != "" {
			next, err := a.mirrorOnce(session, path, off)
			if err != nil {
				a.log.Warn("mirror", "session", session, "err", err)
			}
			off = next
		}
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

func (a *Agent) mirrorOnce(session, path string, off int64) (int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return off, err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return off, err
	}
	if st.Size() < off {
		off = 0
	}
	if st.Size() == off {
		return off, nil
	}
	if _, err := f.Seek(off, io.SeekStart); err != nil {
		return off, err
	}
	r := bufio.NewReaderSize(f, 1<<20)
	var lines []string
	size := 0
	flush := func() {
		a.send(&v1.Frame{Body: &v1.Frame_RawEvents{RawEvents: &v1.RawEvents{
			Session: session, Source: v1.RawEvents_SOURCE_TRANSCRIPT, Lines: lines, EndOffset: off,
		}}})
		lines, size = nil, 0
	}
	for {
		line, err := r.ReadBytes('\n')
		if err != nil {
			break
		}
		off += int64(len(line))
		var head struct {
			Type string `json:"type"`
		}
		if json.Unmarshal(line, &head) != nil || !mirrorTypes[head.Type] {
			continue
		}
		lines = append(lines, strings.TrimRight(string(line), "\r\n"))
		size += len(line)
		if size >= mirrorChunk {
			flush()
		}
	}
	flush()
	return off, nil
}
