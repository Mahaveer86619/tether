package jobs

import (
	"bytes"
	"io"
	"os"
	"strings"
	"time"
)

const (
	maxReadPerTick = 1 << 20
	// A line longer than this is sent in pieces.
	maxLine = 64 << 10
)

// tailLoop sends new lines of every job's log, and keeps each log under
// LogCap.
func (s *Supervisor) tailLoop() {
	t := time.NewTicker(tailEvery)
	defer t.Stop()
	for {
		select {
		case <-s.quit:
			return
		case <-t.C:
		}
		s.mu.Lock()
		ids := make([]string, 0, len(s.jobs))
		for id := range s.jobs {
			ids = append(ids, id)
		}
		s.mu.Unlock()
		for _, id := range ids {
			s.follow(id)
		}
	}
}

// follow reads what was added to a job's log since last time.
func (s *Supervisor) follow(id string) {
	s.mu.Lock()
	j := s.jobs[id]
	if j == nil {
		s.mu.Unlock()
		return
	}
	offset, partial := j.offset, j.partial
	s.mu.Unlock()

	path := s.LogPath(id)
	f, err := os.Open(path)
	if err != nil {
		return
	}
	st, err := f.Stat()
	if err != nil {
		f.Close()
		return
	}
	size := st.Size()
	if size < offset {
		offset, partial = 0, nil
	}
	var lines []string
	if size > offset {
		buf := make([]byte, min(size-offset, maxReadPerTick))
		n, _ := f.ReadAt(buf, offset)
		offset += int64(n)
		lines, partial = splitLines(append(partial, buf[:n]...))
	}
	f.Close()
	if size > s.LogCap && offset >= size {
		if err := rotate(path, s.LogCap/2); err == nil {
			offset = 0
		}
	}

	s.mu.Lock()
	if s.jobs[id] != j {
		s.mu.Unlock()
		return
	}
	j.offset, j.partial = offset, partial
	s.mu.Unlock()
	if len(lines) > 0 && s.lines != nil {
		s.lines(id, lines)
	}
}

// splitLines returns the whole lines in b and what is left after the last.
func splitLines(b []byte) ([]string, []byte) {
	var lines []string
	for {
		i := bytes.IndexByte(b, '\n')
		if i < 0 {
			break
		}
		lines = append(lines, strings.TrimSuffix(string(b[:i]), "\r"))
		b = b[i+1:]
	}
	for len(b) > maxLine {
		lines = append(lines, string(b[:maxLine]))
		b = b[maxLine:]
	}
	return lines, append([]byte(nil), b...)
}

// rotate keeps the last keep bytes of the log in <log>.1 and empties the
// log. The job keeps writing to it: it was opened for appending, so its
// next write lands at the new end. Output written between the copy and
// the truncation is lost, which a log can afford.
func rotate(path string, keep int64) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	st, err := f.Stat()
	if err != nil {
		f.Close()
		return err
	}
	from := max(0, st.Size()-keep)
	old, err := os.Create(path + ".1")
	if err != nil {
		f.Close()
		return err
	}
	_, err = io.Copy(old, io.NewSectionReader(f, from, st.Size()-from))
	f.Close()
	if cerr := old.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return err
	}
	return os.Truncate(path, 0)
}

// Tail is the last n lines of a job's output, older log first.
func (s *Supervisor) Tail(id string, n int) []string {
	if n <= 0 {
		return nil
	}
	path := s.LogPath(id)
	lines := tailFile(path, n)
	if len(lines) < n {
		lines = append(tailFile(path+".1", n-len(lines)), lines...)
	}
	return lines
}

func tailFile(path string, n int) []string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return nil
	}
	const block = 64 << 10
	end := st.Size()
	var data []byte
	for start := end; start > 0 && bytes.Count(data, []byte{'\n'}) <= n; {
		start = max(0, start-block)
		buf := make([]byte, end-start-int64(len(data)))
		if _, err := f.ReadAt(buf, start); err != nil && err != io.EOF {
			return nil
		}
		data = append(buf, data...)
	}
	data = bytes.TrimSuffix(data, []byte{'\n'})
	if len(data) == 0 {
		return nil
	}
	parts := strings.Split(string(data), "\n")
	if len(parts) > n {
		parts = parts[len(parts)-n:]
	}
	for i, p := range parts {
		parts[i] = strings.TrimSuffix(p, "\r")
	}
	return parts
}
