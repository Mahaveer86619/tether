package store

import (
	"database/sql"
	"errors"
	"fmt"
	"strconv"
	"strings"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// History: every session's transcript as events, searchable, with a
// global sequence for consumers to follow. The lines themselves are kept
// by the hub in files; see docs/history.md.

const historySchema = `CREATE TABLE history_files (
		session    TEXT NOT NULL,
		file       TEXT NOT NULL,
		node       TEXT NOT NULL,
		-- Bytes of the source file taken in so far.
		offset     INTEGER NOT NULL,
		-- The source file's first bytes, to tell when it was rewritten.
		head       BLOB NOT NULL,
		-- The newest timestamp seen, for lines that carry none.
		last_ts    INTEGER NOT NULL DEFAULT 0,
		raw_bytes  INTEGER NOT NULL DEFAULT 0,
		updated_ms INTEGER NOT NULL,
		PRIMARY KEY (session, file)
	);
	CREATE INDEX history_files_by_node ON history_files (node);
	CREATE TABLE history_events (
		seq      INTEGER PRIMARY KEY AUTOINCREMENT,
		session  TEXT NOT NULL,
		file     TEXT NOT NULL,
		offset   INTEGER NOT NULL,
		node     TEXT NOT NULL,
		event_id TEXT NOT NULL,
		ts_ms    INTEGER NOT NULL,
		kind     TEXT NOT NULL,
		text     TEXT NOT NULL,
		tool     TEXT NOT NULL,
		model    TEXT NOT NULL,
		cwd      TEXT NOT NULL,
		redacted INTEGER NOT NULL,
		UNIQUE (session, file, offset)
	);
	CREATE INDEX history_by_session_time ON history_events (session, ts_ms, seq);
	CREATE VIRTUAL TABLE history_fts USING fts5(text, content='history_events', content_rowid='seq');
	CREATE TRIGGER history_fts_insert AFTER INSERT ON history_events BEGIN
		INSERT INTO history_fts(rowid, text) VALUES (new.seq, new.text);
	END;
	CREATE TRIGGER history_fts_delete AFTER DELETE ON history_events BEGIN
		INSERT INTO history_fts(history_fts, rowid, text) VALUES ('delete', old.seq, old.text);
	END;
	CREATE TABLE history_resets (
		id      INTEGER PRIMARY KEY AUTOINCREMENT,
		session TEXT NOT NULL,
		file    TEXT NOT NULL,
		-- The newest seq when the file was started over.
		at_seq  INTEGER NOT NULL
	)`

// HistoryFile is how far the history has one transcript file.
type HistoryFile struct {
	Session, File, Node string
	Offset, LastTs      int64
	Head                []byte
	RawBytes            int64
	UpdatedMs           int64
}

func (s *Store) HistoryFile(session, file string) (*HistoryFile, error) {
	f := &HistoryFile{Session: session, File: file}
	err := s.db.QueryRow(`SELECT node, offset, head, last_ts, raw_bytes, updated_ms FROM history_files WHERE session = ? AND file = ?`, session, file).
		Scan(&f.Node, &f.Offset, &f.Head, &f.LastTs, &f.RawBytes, &f.UpdatedMs)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return f, err
}

// HistoryFiles lists the files of a node's sessions.
func (s *Store) HistoryFiles(node string) ([]*HistoryFile, error) {
	rows, err := s.db.Query(`SELECT session, file, node, offset, head, last_ts, raw_bytes, updated_ms FROM history_files WHERE node = ?`, node)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*HistoryFile
	for rows.Next() {
		f := &HistoryFile{}
		if err := rows.Scan(&f.Session, &f.File, &f.Node, &f.Offset, &f.Head, &f.LastTs, &f.RawBytes, &f.UpdatedMs); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// ResetHistoryFile forgets a file's events, to take it in again from the
// start, and records the reset for the changes feed.
func (s *Store) ResetHistoryFile(session, file string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM history_events WHERE session = ? AND file = ?`, session, file); err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM history_files WHERE session = ? AND file = ?`, session, file); err != nil {
		return err
	}
	if _, err := tx.Exec(`INSERT INTO history_resets (session, file, at_seq) VALUES (?, ?, (SELECT COALESCE(MAX(seq), 0) FROM history_events))`, session, file); err != nil {
		return err
	}
	return tx.Commit()
}

// AppendHistory stores the events of a chunk and moves the file's position
// to f.Offset, in one transaction. An event already stored (same session,
// file and offset) is skipped.
func (s *Store) AppendHistory(f *HistoryFile, events []*v1.HistoryEvent) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	stmt, err := tx.Prepare(`INSERT OR IGNORE INTO history_events
		(session, file, offset, node, event_id, ts_ms, kind, text, tool, model, cwd, redacted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, e := range events {
		if _, err := stmt.Exec(f.Session, f.File, e.Offset, f.Node, e.EventId, e.TsMs, e.Kind, e.Text, e.Tool, e.Model, e.Cwd, e.Redacted); err != nil {
			return err
		}
	}
	if _, err := tx.Exec(`INSERT INTO history_files (session, file, node, offset, head, last_ts, raw_bytes, updated_ms) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(session, file) DO UPDATE SET node = excluded.node, offset = excluded.offset, head = excluded.head,
			last_ts = excluded.last_ts, raw_bytes = excluded.raw_bytes, updated_ms = excluded.updated_ms`,
		f.Session, f.File, f.Node, f.Offset, f.Head, f.LastTs, f.RawBytes, f.UpdatedMs); err != nil {
		return err
	}
	return tx.Commit()
}

const eventCols = `seq, session, node, file, offset, event_id, ts_ms, kind, text, tool, model, cwd, redacted`

func scanEvent(row interface{ Scan(...any) error }) (*v1.HistoryEvent, error) {
	e := &v1.HistoryEvent{}
	err := row.Scan(&e.Seq, &e.Session, &e.Node, &e.File, &e.Offset, &e.EventId, &e.TsMs, &e.Kind, &e.Text, &e.Tool, &e.Model, &e.Cwd, &e.Redacted)
	return e, err
}

// Cursor marks a place in time order: "<ts_ms>_<seq>".
func Cursor(e *v1.HistoryEvent) string { return fmt.Sprintf("%d_%d", e.TsMs, e.Seq) }

func parseCursor(c string) (ts, seq int64, ok bool) {
	a, b, found := strings.Cut(c, "_")
	if !found {
		return 0, 0, false
	}
	ts, err1 := strconv.ParseInt(a, 10, 64)
	seq, err2 := strconv.ParseInt(b, 10, 64)
	return ts, seq, err1 == nil && err2 == nil
}

// HistoryQuery selects a page of history: the events of sessions, in time
// order, around a cursor.
type HistoryQuery struct {
	// Every session's history when All is set.
	Sessions []string
	All      bool
	// Include subagents' transcripts.
	Subagents bool
	// At most one of these; neither means the newest page.
	Before, After string
	Limit         int
}

// HistoryPage returns a page of events, oldest first.
func (s *Store) HistoryPage(q HistoryQuery) (*v1.HistoryPage, error) {
	page := &v1.HistoryPage{}
	if len(q.Sessions) == 0 && !q.All {
		return page, nil
	}
	limit := q.Limit
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	where := `1 = 1`
	args := make([]any, 0, len(q.Sessions)+4)
	if !q.All {
		where = `session IN (?` + strings.Repeat(`, ?`, len(q.Sessions)-1) + `)`
		for _, id := range q.Sessions {
			args = append(args, id)
		}
	}
	if !q.Subagents {
		where += ` AND file = ''`
	}
	order := `ts_ms DESC, seq DESC`
	newestFirst := true
	switch {
	case q.After != "":
		ts, seq, ok := parseCursor(q.After)
		if !ok {
			return nil, fmt.Errorf("bad cursor %q", q.After)
		}
		where += ` AND (ts_ms > ? OR ts_ms = ? AND seq > ?)`
		args = append(args, ts, ts, seq)
		order, newestFirst = `ts_ms ASC, seq ASC`, false
	case q.Before != "":
		ts, seq, ok := parseCursor(q.Before)
		if !ok {
			return nil, fmt.Errorf("bad cursor %q", q.Before)
		}
		where += ` AND (ts_ms < ? OR ts_ms = ? AND seq < ?)`
		args = append(args, ts, ts, seq)
	}
	args = append(args, limit+1)
	rows, err := s.db.Query(`SELECT `+eventCols+` FROM history_events WHERE `+where+` ORDER BY `+order+` LIMIT ?`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		e, err := scanEvent(rows)
		if err != nil {
			return nil, err
		}
		page.Events = append(page.Events, e)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	more := len(page.Events) > limit
	if more {
		page.Events = page.Events[:limit]
	}
	if newestFirst {
		for i, j := 0, len(page.Events)-1; i < j; i, j = i+1, j-1 {
			page.Events[i], page.Events[j] = page.Events[j], page.Events[i]
		}
		page.MoreBefore = more
		page.MoreAfter = q.Before != ""
	} else {
		page.MoreAfter = more
		page.MoreBefore = true
	}
	if n := len(page.Events); n > 0 {
		page.Before, page.After = Cursor(page.Events[0]), Cursor(page.Events[n-1])
	} else {
		page.Before, page.After = q.Before, q.After
	}
	return page, nil
}

// SearchHistory finds events whose text matches query (FTS5 syntax; plain
// words are ANDed), best matches first, optionally within sessions.
func (s *Store) SearchHistory(query string, sessions []string, limit int) ([]*v1.HistoryEvent, []string, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	where := `history_fts MATCH ?`
	args := []any{ftsQuery(query)}
	if len(sessions) > 0 {
		where += ` AND e.session IN (?` + strings.Repeat(`, ?`, len(sessions)-1) + `)`
		for _, id := range sessions {
			args = append(args, id)
		}
	}
	args = append(args, limit)
	rows, err := s.db.Query(`SELECT e.seq, e.session, e.node, e.file, e.offset, e.event_id, e.ts_ms, e.kind, e.text, e.tool, e.model, e.cwd, e.redacted,
			snippet(history_fts, 0, '[', ']', '…', 12)
		FROM history_fts JOIN history_events e ON e.seq = history_fts.rowid
		WHERE `+where+` ORDER BY rank LIMIT ?`, args...)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()
	var events []*v1.HistoryEvent
	var snippets []string
	for rows.Next() {
		e := &v1.HistoryEvent{}
		var snip string
		if err := rows.Scan(&e.Seq, &e.Session, &e.Node, &e.File, &e.Offset, &e.EventId, &e.TsMs, &e.Kind, &e.Text, &e.Tool, &e.Model, &e.Cwd, &e.Redacted, &snip); err != nil {
			return nil, nil, err
		}
		events = append(events, e)
		snippets = append(snippets, snip)
	}
	return events, snippets, rows.Err()
}

// ftsQuery quotes each word, so user input can't be read as FTS syntax.
func ftsQuery(q string) string {
	var words []string
	for _, w := range strings.Fields(q) {
		words = append(words, `"`+strings.ReplaceAll(w, `"`, `""`)+`"`)
	}
	return strings.Join(words, " ")
}

// HistoryChanges returns events stored after the cursor, and the files
// reset since then.
func (s *Store) HistoryChanges(since uint64, limit int) (*v1.HistoryChanges, error) {
	if limit <= 0 || limit > 5000 {
		limit = 1000
	}
	out := &v1.HistoryChanges{Cursor: since}
	rows, err := s.db.Query(`SELECT `+eventCols+` FROM history_events WHERE seq > ? ORDER BY seq LIMIT ?`, since, limit+1)
	if err != nil {
		return nil, err
	}
	for rows.Next() {
		e, err := scanEvent(rows)
		if err != nil {
			rows.Close()
			return nil, err
		}
		out.Events = append(out.Events, e)
	}
	rows.Close()
	if len(out.Events) > limit {
		out.Events, out.More = out.Events[:limit], true
	}
	if n := len(out.Events); n > 0 {
		out.Cursor = out.Events[n-1].Seq
	}
	resets, err := s.db.Query(`SELECT session, file FROM history_resets WHERE at_seq >= ? AND at_seq <= ? ORDER BY id`, since, out.Cursor)
	if err != nil {
		return nil, err
	}
	defer resets.Close()
	for resets.Next() {
		p := &v1.HistoryPosition{}
		if err := resets.Scan(&p.Session, &p.File); err != nil {
			return nil, err
		}
		out.Resets = append(out.Resets, p)
	}
	return out, resets.Err()
}

// HistoryStatus sums the history by node; synced times come from the hub.
func (s *Store) HistoryStatus() (*v1.HistoryStatus, error) {
	out := &v1.HistoryStatus{}
	rows, err := s.db.Query(`SELECT f.node, COUNT(*), SUM(f.raw_bytes), MAX(f.updated_ms),
			(SELECT COUNT(*) FROM history_events e WHERE e.node = f.node)
		FROM history_files f GROUP BY f.node ORDER BY f.node`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		n := &v1.HistoryNodeStatus{}
		if err := rows.Scan(&n.Node, &n.Files, &n.Bytes, &n.SyncedMs, &n.Events); err != nil {
			return nil, err
		}
		out.Nodes = append(out.Nodes, n)
		out.Events += n.Events
		out.Bytes += n.Bytes
	}
	return out, rows.Err()
}

// HistorySessionsByAge lists sessions with history, least recently updated
// first, with when each was last updated and the bytes its files take.
func (s *Store) HistorySessionsByAge() ([]string, []int64, []int64, error) {
	rows, err := s.db.Query(`SELECT session, MAX(updated_ms), SUM(raw_bytes) FROM history_files GROUP BY session ORDER BY MAX(updated_ms)`)
	if err != nil {
		return nil, nil, nil, err
	}
	defer rows.Close()
	var ids []string
	var updated, bytes []int64
	for rows.Next() {
		var id string
		var u, b int64
		if err := rows.Scan(&id, &u, &b); err != nil {
			return nil, nil, nil, err
		}
		ids, updated, bytes = append(ids, id), append(updated, u), append(bytes, b)
	}
	return ids, updated, bytes, rows.Err()
}

// DeleteHistory forgets a session's history.
func (s *Store) DeleteHistory(session string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM history_events WHERE session = ?`, session); err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM history_files WHERE session = ?`, session); err != nil {
		return err
	}
	return tx.Commit()
}
