// Package store persists sessions and their timelines in SQLite.
package store

import (
	"database/sql"
	"errors"
	"fmt"

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
`

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
	return &Store{db: db}, nil
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
