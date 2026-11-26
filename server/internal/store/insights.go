package store

import (
	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// UsageRow is one assistant message's token counts.
type UsageRow struct {
	Session    string
	Model      string
	TsMs       int64
	Input      int64
	Output     int64
	CacheWrite int64
	CacheRead  int64
}

// UsageSince returns every usage row from sinceMs on, oldest first.
func (s *Store) UsageSince(sinceMs int64) ([]UsageRow, error) {
	rows, err := s.db.Query(`SELECT session, model, ts_ms, input, output, cache_write, cache_read FROM usage WHERE ts_ms >= ? ORDER BY ts_ms`, sinceMs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []UsageRow
	for rows.Next() {
		var u UsageRow
		if err := rows.Scan(&u.Session, &u.Model, &u.TsMs, &u.Input, &u.Output, &u.CacheWrite, &u.CacheRead); err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

// LineageSince returns every lineage event from sinceMs on.
func (s *Store) LineageSince(sinceMs int64) ([]*v1.LineageEvent, error) {
	rows, err := s.db.Query(`SELECT id, session, parent, kind, fork_point, by_client, at_ms, detail FROM lineage_events WHERE at_ms >= ? ORDER BY id`, sinceMs)
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

// AuditSince returns the entries of one kind from sinceMs on, oldest first.
func (s *Store) AuditSince(kind string, sinceMs int64) ([]AuditEntry, error) {
	rows, err := s.db.Query(`SELECT id, at_ms, actor, kind, subject, detail, ok FROM audit WHERE kind = ? AND at_ms >= ? ORDER BY id`, kind, sinceMs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []AuditEntry
	for rows.Next() {
		var e AuditEntry
		if err := rows.Scan(&e.ID, &e.AtMs, &e.Actor, &e.Kind, &e.Subject, &e.Detail, &e.OK); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// LimitSample is one reading of a plan limit, as /usage reported it.
type LimitSample struct {
	Account string
	// "session5h", "week" or "other"; Label keeps Claude's own words.
	Span    string
	Label   string
	Percent int32
	Resets  string
	AtMs    int64
}

func (s *Store) AddLimitSamples(samples []LimitSample) error {
	for _, l := range samples {
		if _, err := s.db.Exec(`INSERT INTO limit_samples (account, span, label, percent, resets, at_ms) VALUES (?, ?, ?, ?, ?, ?)`,
			l.Account, l.Span, l.Label, l.Percent, l.Resets, l.AtMs); err != nil {
			return err
		}
	}
	return nil
}

// LimitSamplesSince returns the readings from sinceMs on, oldest first.
func (s *Store) LimitSamplesSince(sinceMs int64) ([]LimitSample, error) {
	rows, err := s.db.Query(`SELECT account, span, label, percent, resets, at_ms FROM limit_samples WHERE at_ms >= ? ORDER BY id`, sinceMs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []LimitSample
	for rows.Next() {
		var l LimitSample
		if err := rows.Scan(&l.Account, &l.Span, &l.Label, &l.Percent, &l.Resets, &l.AtMs); err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, rows.Err()
}

// LimitEvent is a session stopping at a usage limit.
type LimitEvent struct {
	Account string
	Span    string
	ResetMs int64
	Session string
	AtMs    int64
}

func (s *Store) AddLimitEvent(e LimitEvent) error {
	_, err := s.db.Exec(`INSERT INTO limit_events (account, span, reset_ms, session, at_ms) VALUES (?, ?, ?, ?, ?)`, e.Account, e.Span, e.ResetMs, e.Session, e.AtMs)
	return err
}

func (s *Store) LimitEventsSince(sinceMs int64) ([]LimitEvent, error) {
	rows, err := s.db.Query(`SELECT account, span, reset_ms, session, at_ms FROM limit_events WHERE at_ms >= ? ORDER BY id`, sinceMs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []LimitEvent
	for rows.Next() {
		var e LimitEvent
		if err := rows.Scan(&e.Account, &e.Span, &e.ResetMs, &e.Session, &e.AtMs); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}
