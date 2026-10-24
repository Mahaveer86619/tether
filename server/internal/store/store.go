// Package store persists sessions and their timelines in SQLite.
package store

import (
	"database/sql"
	"errors"
	"fmt"
	"os"
	"strings"

	"google.golang.org/protobuf/proto"
	_ "modernc.org/sqlite"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

const schema = `
CREATE TABLE IF NOT EXISTS sessions (
	id                TEXT PRIMARY KEY,
	node              TEXT NOT NULL,
	info              BLOB NOT NULL,
	next_seq          INTEGER NOT NULL DEFAULT 1,
	next_ord          INTEGER NOT NULL DEFAULT 1,
	transcript_offset INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS items (
	session TEXT NOT NULL,
	item_id TEXT NOT NULL,
	ord     INTEGER NOT NULL,
	seq     INTEGER NOT NULL,
	payload BLOB NOT NULL,
	PRIMARY KEY (session, item_id)
);
CREATE INDEX IF NOT EXISTS items_by_seq ON items (session, seq);
CREATE TABLE IF NOT EXISTS nodes (
	name   TEXT PRIMARY KEY,
	status BLOB NOT NULL
);
CREATE TABLE IF NOT EXISTS lineage_events (
	id         INTEGER PRIMARY KEY AUTOINCREMENT,
	session    TEXT NOT NULL,
	parent     TEXT NOT NULL,
	kind       TEXT NOT NULL,
	fork_point TEXT NOT NULL DEFAULT '',
	by_client  TEXT NOT NULL DEFAULT '',
	at_ms      INTEGER NOT NULL,
	detail     TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS lineage_by_session ON lineage_events (session);
CREATE INDEX IF NOT EXISTS lineage_by_parent ON lineage_events (parent);
CREATE TABLE IF NOT EXISTS usage (
	session     TEXT NOT NULL,
	message_id  TEXT NOT NULL,
	node        TEXT NOT NULL,
	model       TEXT NOT NULL DEFAULT '',
	ts_ms       INTEGER NOT NULL,
	input       INTEGER NOT NULL,
	output      INTEGER NOT NULL,
	cache_write INTEGER NOT NULL,
	cache_read  INTEGER NOT NULL,
	PRIMARY KEY (session, message_id)
);
CREATE INDEX IF NOT EXISTS usage_by_time ON usage (ts_ms);
CREATE TABLE IF NOT EXISTS artifacts (
	id          TEXT PRIMARY KEY,
	sha256      TEXT NOT NULL,
	name        TEXT NOT NULL,
	mime        TEXT NOT NULL,
	size        INTEGER NOT NULL,
	session     TEXT NOT NULL DEFAULT '',
	node        TEXT NOT NULL DEFAULT '',
	origin      TEXT NOT NULL DEFAULT '',
	path        TEXT NOT NULL DEFAULT '',
	tool_use_id TEXT NOT NULL DEFAULT '',
	created_ms  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS artifacts_by_session ON artifacts (session);
CREATE INDEX IF NOT EXISTS artifacts_by_sha ON artifacts (sha256);
CREATE TABLE IF NOT EXISTS kv (
	key   TEXT PRIMARY KEY,
	value BLOB NOT NULL
);
CREATE TABLE IF NOT EXISTS codebases (
	id   TEXT PRIMARY KEY,
	node TEXT NOT NULL,
	path TEXT NOT NULL,
	info BLOB NOT NULL,
	UNIQUE (node, path)
);
CREATE TABLE IF NOT EXISTS snapshots (
	id         TEXT PRIMARY KEY,
	codebase   TEXT NOT NULL,
	created_ms INTEGER NOT NULL,
	info       BLOB NOT NULL
);
CREATE INDEX IF NOT EXISTS snapshots_by_codebase ON snapshots (codebase, created_ms);
CREATE TABLE IF NOT EXISTS codebase_env (
	codebase   TEXT NOT NULL,
	path       TEXT NOT NULL,
	-- The keys and fingerprints, readable; the file itself is sealed.
	info       BLOB NOT NULL,
	nonce      BLOB NOT NULL,
	sealed     BLOB NOT NULL,
	PRIMARY KEY (codebase, path)
);
CREATE TABLE IF NOT EXISTS devices (
	id         TEXT PRIMARY KEY,
	token_hash TEXT NOT NULL UNIQUE,
	info       BLOB NOT NULL
);
`

// migrations change tables made by an older schema, in order; PRAGMA
// user_version counts how many have run. Append only.
var migrations = []string{
	`ALTER TABLE artifacts ADD COLUMN note TEXT NOT NULL DEFAULT ''`,
	// Chats: the conversations, the sessions behind each, what was said in
	// them, and what post-processing jobs made of it.
	`CREATE TABLE chats (
		id         TEXT PRIMARY KEY,
		info       BLOB NOT NULL,
		updated_ms INTEGER NOT NULL
	);
	CREATE TABLE chat_sessions (
		chat      TEXT NOT NULL,
		session   TEXT NOT NULL,
		role      TEXT NOT NULL,
		linked_ms INTEGER NOT NULL,
		PRIMARY KEY (chat, session)
	);
	CREATE INDEX chat_sessions_by_session ON chat_sessions (session);
	CREATE TABLE chat_messages (
		chat    TEXT NOT NULL,
		session TEXT NOT NULL,
		item_id TEXT NOT NULL,
		role    TEXT NOT NULL,
		text    TEXT NOT NULL,
		ts_ms   INTEGER NOT NULL,
		PRIMARY KEY (chat, session, item_id)
	);
	CREATE TABLE chat_notes (
		chat       TEXT NOT NULL,
		kind       TEXT NOT NULL,
		value      TEXT NOT NULL,
		updated_ms INTEGER NOT NULL,
		PRIMARY KEY (chat, kind)
	)`,
	historySchema,
}

type Store struct {
	db *sql.DB
}

func Open(path string) (*Store, error) {
	db, err := sql.Open("sqlite", fmt.Sprintf("file:%s?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=synchronous(NORMAL)", path))
	if err != nil {
		return nil, err
	}
	// One writer keeps SQLite simple; the hub serialises access anyway.
	db.SetMaxOpenConns(1)
	if _, err := db.Exec(schema); err != nil {
		db.Close()
		return nil, err
	}
	if err := migrate(db, path); err != nil {
		db.Close()
		return nil, err
	}
	return &Store{db: db}, nil
}

func migrate(db *sql.DB, path string) error {
	var done int
	if err := db.QueryRow(`PRAGMA user_version`).Scan(&done); err != nil {
		return err
	}
	// A copy from before the first migration this run makes, next to the
	// database. A fresh database (only the schema, no sessions) needs none.
	var sessions int
	if err := db.QueryRow(`SELECT COUNT(*) FROM sessions`).Scan(&sessions); err != nil {
		return err
	}
	if done < len(migrations) && sessions > 0 {
		backup := fmt.Sprintf("%s.pre-migration-%d", path, done+1)
		_ = os.Remove(backup)
		// VACUUM INTO takes the path as a string literal; quotes are doubled.
		if _, err := db.Exec(`VACUUM INTO '` + strings.ReplaceAll(backup, "'", "''") + `'`); err != nil {
			return fmt.Errorf("back up before migrating: %w", err)
		}
	}
	for i := done; i < len(migrations); i++ {
		tx, err := db.Begin()
		if err != nil {
			return err
		}
		if _, err := tx.Exec(migrations[i]); err != nil {
			tx.Rollback()
			return fmt.Errorf("migration %d: %w", i+1, err)
		}
		// PRAGMA takes no parameters; i is ours.
		if _, err := tx.Exec(fmt.Sprintf(`PRAGMA user_version = %d`, i+1)); err != nil {
			tx.Rollback()
			return err
		}
		if err := tx.Commit(); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) PutSession(info *v1.SessionInfo) error {
	b, err := proto.Marshal(info)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`INSERT INTO sessions (id, node, info) VALUES (?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET node = excluded.node, info = excluded.info`, info.Id, info.Node, b)
	return err
}

func (s *Store) Sessions() ([]*v1.SessionInfo, error) {
	rows, err := s.db.Query(`SELECT info FROM sessions`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.SessionInfo
	for rows.Next() {
		var b []byte
		if err := rows.Scan(&b); err != nil {
			return nil, err
		}
		info := &v1.SessionInfo{}
		if err := proto.Unmarshal(b, info); err != nil {
			return nil, err
		}
		out = append(out, info)
	}
	return out, rows.Err()
}

// PutItems upserts timeline items, assigning ord on first insert and a new
// seq to every item that changed. It returns the stored items and the
// highest seq assigned. Unchanged items are skipped.
func (s *Store) PutItems(session string, items []*v1.TimelineItem) ([]*v1.TimelineItem, uint64, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, 0, err
	}
	defer tx.Rollback()

	var nextSeq, nextOrd uint64
	err = tx.QueryRow(`SELECT next_seq, next_ord FROM sessions WHERE id = ?`, session).Scan(&nextSeq, &nextOrd)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, 0, fmt.Errorf("unknown session %s", session)
	}
	if err != nil {
		return nil, 0, err
	}

	var stored []*v1.TimelineItem
	var maxSeq uint64
	for _, it := range items {
		var ord uint64
		var prev []byte
		err := tx.QueryRow(`SELECT ord, payload FROM items WHERE session = ? AND item_id = ?`, session, it.ItemId).Scan(&ord, &prev)
		switch {
		case errors.Is(err, sql.ErrNoRows):
			ord = nextOrd
			nextOrd++
		case err != nil:
			return nil, 0, err
		}
		it = proto.Clone(it).(*v1.TimelineItem)
		it.Ord = ord
		// Stream and transcript stamp the same item differently; keep the first.
		if prev != nil {
			old := &v1.TimelineItem{}
			if proto.Unmarshal(prev, old) == nil {
				it.TsMs = old.TsMs
			}
		}
		b, err := proto.MarshalOptions{Deterministic: true}.Marshal(it)
		if err != nil {
			return nil, 0, err
		}
		if prev != nil && string(prev) == string(b) {
			continue
		}
		seq := nextSeq
		nextSeq++
		if _, err := tx.Exec(`INSERT INTO items (session, item_id, ord, seq, payload) VALUES (?, ?, ?, ?, ?)
			ON CONFLICT(session, item_id) DO UPDATE SET seq = excluded.seq, payload = excluded.payload`,
			session, it.ItemId, ord, seq, b); err != nil {
			return nil, 0, err
		}
		stored = append(stored, it)
		maxSeq = seq
	}
	if _, err := tx.Exec(`UPDATE sessions SET next_seq = ?, next_ord = ? WHERE id = ?`, nextSeq, nextOrd, session); err != nil {
		return nil, 0, err
	}
	return stored, maxSeq, tx.Commit()
}

// ItemsAfter returns items changed after seq, oldest change first.
func (s *Store) ItemsAfter(session string, after uint64) ([]*v1.TimelineItem, uint64, error) {
	rows, err := s.db.Query(`SELECT seq, payload FROM items WHERE session = ? AND seq > ? ORDER BY seq`, session, after)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	var out []*v1.TimelineItem
	var maxSeq uint64
	for rows.Next() {
		var seq uint64
		var b []byte
		if err := rows.Scan(&seq, &b); err != nil {
			return nil, 0, err
		}
		it := &v1.TimelineItem{}
		if err := proto.Unmarshal(b, it); err != nil {
			return nil, 0, err
		}
		out = append(out, it)
		maxSeq = seq
	}
	return out, maxSeq, rows.Err()
}

// DeleteSession forgets a session and its timeline.
func (s *Store) DeleteSession(id string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM items WHERE session = ?`, id); err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM sessions WHERE id = ?`, id); err != nil {
		return err
	}
	return tx.Commit()
}

// ResetTimeline drops a session's items so they can be rebuilt from its
// transcript. next_seq keeps counting, so clients see every rebuilt item as
// new and merge it by id.
func (s *Store) ResetTimeline(id string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM items WHERE session = ?`, id); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE sessions SET next_ord = 1, transcript_offset = 0 WHERE id = ?`, id); err != nil {
		return err
	}
	return tx.Commit()
}

// LatestSeq is the highest seq assigned in a session so far.
func (s *Store) LatestSeq(session string) (uint64, error) {
	var next uint64
	err := s.db.QueryRow(`SELECT next_seq FROM sessions WHERE id = ?`, session).Scan(&next)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}
	return next - 1, nil
}

func (s *Store) Item(session, itemID string) (*v1.TimelineItem, error) {
	var b []byte
	err := s.db.QueryRow(`SELECT payload FROM items WHERE session = ? AND item_id = ?`, session, itemID).Scan(&b)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	it := &v1.TimelineItem{}
	return it, proto.Unmarshal(b, it)
}

func (s *Store) TranscriptOffset(session string) (int64, error) {
	var off int64
	err := s.db.QueryRow(`SELECT transcript_offset FROM sessions WHERE id = ?`, session).Scan(&off)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, nil
	}
	return off, err
}

func (s *Store) SetTranscriptOffset(session string, off int64) error {
	_, err := s.db.Exec(`UPDATE sessions SET transcript_offset = ? WHERE id = ?`, off, session)
	return err
}

func (s *Store) PutNode(st *v1.NodeStatus) error {
	b, err := proto.Marshal(st)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`INSERT INTO nodes (name, status) VALUES (?, ?) ON CONFLICT(name) DO UPDATE SET status = excluded.status`, st.Node, b)
	return err
}

func (s *Store) Nodes() ([]*v1.NodeStatus, error) {
	rows, err := s.db.Query(`SELECT status FROM nodes`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.NodeStatus
	for rows.Next() {
		var b []byte
		if err := rows.Scan(&b); err != nil {
			return nil, err
		}
		st := &v1.NodeStatus{}
		if err := proto.Unmarshal(b, st); err != nil {
			return nil, err
		}
		out = append(out, st)
	}
	return out, rows.Err()
}

// PutDevice stores a paired device with the hash of its token.
func (s *Store) PutDevice(d *v1.Device, tokenHash string) error {
	b, err := proto.Marshal(d)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`INSERT INTO devices (id, token_hash, info) VALUES (?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET token_hash = excluded.token_hash, info = excluded.info`, d.Id, tokenHash, b)
	return err
}

// Devices returns every paired device, keyed by its token hash.
func (s *Store) Devices() (map[string]*v1.Device, error) {
	rows, err := s.db.Query(`SELECT token_hash, info FROM devices`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]*v1.Device{}
	for rows.Next() {
		var hash string
		var b []byte
		if err := rows.Scan(&hash, &b); err != nil {
			return nil, err
		}
		d := &v1.Device{}
		if err := proto.Unmarshal(b, d); err != nil {
			return nil, err
		}
		out[hash] = d
	}
	return out, rows.Err()
}

func (s *Store) DeleteDevice(id string) error {
	_, err := s.db.Exec(`DELETE FROM devices WHERE id = ?`, id)
	return err
}

// Get reads a small named value, such as the shared app preferences; nil
// when it was never set.
func (s *Store) Get(key string) ([]byte, error) {
	var b []byte
	err := s.db.QueryRow(`SELECT value FROM kv WHERE key = ?`, key).Scan(&b)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return b, err
}

func (s *Store) Put(key string, value []byte) error {
	_, err := s.db.Exec(`INSERT INTO kv (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value`, key, value)
	return err
}

// LastItemID is the item with the highest ord in a session, or "".
func (s *Store) LastItemID(session string) (string, error) {
	var id string
	err := s.db.QueryRow(`SELECT item_id FROM items WHERE session = ? ORDER BY ord DESC LIMIT 1`, session).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	return id, err
}

// AddLineageEvent records a fork, branch, merge or abandon. They are kept
// for the second brain to analyse, so nothing deletes them.
func (s *Store) AddLineageEvent(e *v1.LineageEvent) error {
	res, err := s.db.Exec(`INSERT INTO lineage_events (session, parent, kind, fork_point, by_client, at_ms, detail) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		e.Session, e.Parent, e.Kind, e.ForkPoint, e.By, e.AtMs, e.Detail)
	if err != nil {
		return err
	}
	e.Id, err = res.LastInsertId()
	return err
}

// LineageEvents returns the events where session is the child or the parent,
// oldest first.
func (s *Store) LineageEvents(session string) ([]*v1.LineageEvent, error) {
	rows, err := s.db.Query(`SELECT id, session, parent, kind, fork_point, by_client, at_ms, detail FROM lineage_events
		WHERE session = ? OR parent = ? ORDER BY id`, session, session)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.LineageEvent
	for rows.Next() {
		e := &v1.LineageEvent{}
		if err := rows.Scan(&e.Id, &e.Session, &e.Parent, &e.Kind, &e.ForkPoint, &e.By, &e.AtMs, &e.Detail); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// PutUsage records token usage per assistant message. A message reported
// again keeps the largest count seen for each field.
func (s *Store) PutUsage(node string, entries []*v1.UsageEntry) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	stmt, err := tx.Prepare(`INSERT INTO usage (session, message_id, node, model, ts_ms, input, output, cache_write, cache_read)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(session, message_id) DO UPDATE SET
			input = MAX(input, excluded.input), output = MAX(output, excluded.output),
			cache_write = MAX(cache_write, excluded.cache_write), cache_read = MAX(cache_read, excluded.cache_read)`)
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, e := range entries {
		if _, err := stmt.Exec(e.Session, e.MessageId, node, e.Model, e.TsMs, e.Input, e.Output, e.CacheWrite, e.CacheRead); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// UsageByNode totals usage per node since sinceMs.
func (s *Store) UsageByNode(sinceMs int64) (map[string]*v1.UsageTotals, error) {
	rows, err := s.db.Query(`SELECT node, SUM(input), SUM(output), SUM(cache_write), SUM(cache_read), COUNT(*)
		FROM usage WHERE ts_ms >= ? GROUP BY node`, sinceMs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]*v1.UsageTotals{}
	for rows.Next() {
		var node string
		t := &v1.UsageTotals{}
		if err := rows.Scan(&node, &t.Input, &t.Output, &t.CacheWrite, &t.CacheRead, &t.Messages); err != nil {
			return nil, err
		}
		out[node] = t
	}
	return out, rows.Err()
}

// UsageBySession totals usage per session since sinceMs, most tokens first.
func (s *Store) UsageBySession(sinceMs int64, limit int) ([]*v1.SessionUsage, error) {
	rows, err := s.db.Query(`SELECT session, SUM(input), SUM(output), SUM(cache_write), SUM(cache_read), COUNT(*), MAX(ts_ms)
		FROM usage WHERE ts_ms >= ? GROUP BY session
		ORDER BY SUM(input) + SUM(output) + SUM(cache_write) DESC LIMIT ?`, sinceMs, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.SessionUsage
	for rows.Next() {
		u := &v1.SessionUsage{Total: &v1.UsageTotals{}}
		if err := rows.Scan(&u.Session, &u.Total.Input, &u.Total.Output, &u.Total.CacheWrite, &u.Total.CacheRead, &u.Total.Messages, &u.LastMs); err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

const artifactCols = `id, sha256, name, mime, size, session, node, origin, path, tool_use_id, created_ms, note`

func scanArtifact(row interface{ Scan(...any) error }) (*v1.Artifact, error) {
	a := &v1.Artifact{}
	return a, row.Scan(&a.Id, &a.Sha256, &a.Name, &a.Mime, &a.Size, &a.Session, &a.Node, &a.Origin, &a.Path, &a.ToolUseId, &a.CreatedMs, &a.Note)
}

func (s *Store) PutArtifact(a *v1.Artifact) error {
	_, err := s.db.Exec(`INSERT INTO artifacts (`+artifactCols+`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		a.Id, a.Sha256, a.Name, a.Mime, a.Size, a.Session, a.Node, a.Origin, a.Path, a.ToolUseId, a.CreatedMs, a.Note)
	return err
}

// Artifact returns one artifact, or nil.
func (s *Store) Artifact(id string) (*v1.Artifact, error) {
	a, err := scanArtifact(s.db.QueryRow(`SELECT `+artifactCols+` FROM artifacts WHERE id = ?`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return a, err
}

// Artifacts lists newest first; session "" means all of them.
func (s *Store) Artifacts(session string, limit int) ([]*v1.Artifact, error) {
	q := `SELECT ` + artifactCols + ` FROM artifacts`
	args := []any{}
	if session != "" {
		q += ` WHERE session = ?`
		args = append(args, session)
	}
	q += ` ORDER BY created_ms DESC LIMIT ?`
	rows, err := s.db.Query(q, append(args, limit)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.Artifact
	for rows.Next() {
		a, err := scanArtifact(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// DeleteArtifact removes one artifact and reports whether others still use
// its content.
func (s *Store) DeleteArtifact(id, sha string) (shared bool, err error) {
	if _, err := s.db.Exec(`DELETE FROM artifacts WHERE id = ?`, id); err != nil {
		return false, err
	}
	var n int
	err = s.db.QueryRow(`SELECT COUNT(*) FROM artifacts WHERE sha256 = ?`, sha).Scan(&n)
	return n > 0, err
}

// HasArtifact reports whether an artifact with this content is already
// linked to ref (a tool call or message) in session.
func (s *Store) HasArtifact(session, ref, sha string) (bool, error) {
	var n int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM artifacts WHERE session = ? AND tool_use_id = ? AND sha256 = ?`, session, ref, sha).Scan(&n)
	return n > 0, err
}

// PageFile returns the newest version of a page's file, or nil.
func (s *Store) PageFile(session, path string) (*v1.Artifact, error) {
	a, err := scanArtifact(s.db.QueryRow(`SELECT `+artifactCols+` FROM artifacts
		WHERE origin = 'page' AND session = ? AND path = ? ORDER BY created_ms DESC LIMIT 1`, session, path))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return a, err
}

// BackupFile returns a session's backed-up file at path, or nil.
// BackupFiles lists the newest backup of every session's files.
func (s *Store) BackupFiles() ([]*v1.Artifact, error) {
	rows, err := s.db.Query(`SELECT ` + artifactCols + ` FROM artifacts a WHERE origin = 'backup'
		AND created_ms = (SELECT MAX(created_ms) FROM artifacts b WHERE b.origin = 'backup' AND b.session = a.session AND b.path = a.path)`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.Artifact
	for rows.Next() {
		a, err := scanArtifact(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (s *Store) BackupFile(session, path string) (*v1.Artifact, error) {
	a, err := scanArtifact(s.db.QueryRow(`SELECT `+artifactCols+` FROM artifacts
		WHERE origin = 'backup' AND session = ? AND path = ? ORDER BY created_ms DESC LIMIT 1`, session, path))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return a, err
}

// PageFiles lists the newest version of every page file, newest first;
// session "" means all sessions.
func (s *Store) PageFiles(session string) ([]*v1.Artifact, error) {
	q := `SELECT ` + artifactCols + ` FROM artifacts a WHERE origin = 'page'
		AND created_ms = (SELECT MAX(created_ms) FROM artifacts b WHERE b.origin = 'page' AND b.session = a.session AND b.path = a.path)`
	args := []any{}
	if session != "" {
		q += ` AND session = ?`
		args = append(args, session)
	}
	rows, err := s.db.Query(q+` ORDER BY created_ms DESC`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.Artifact
	for rows.Next() {
		a, err := scanArtifact(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}
