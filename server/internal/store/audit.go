package store

// AuditEntry is one line of the audit log.
type AuditEntry struct {
	ID      int64  `json:"id"`
	AtMs    int64  `json:"at_ms"`
	Actor   string `json:"actor"`
	Kind    string `json:"kind"`
	Subject string `json:"subject"`
	Detail  string `json:"detail"`
	OK      bool   `json:"ok"`
}

func (s *Store) AddAudit(e AuditEntry) error {
	_, err := s.db.Exec(`INSERT INTO audit (at_ms, actor, kind, subject, detail, ok) VALUES (?, ?, ?, ?, ?, ?)`,
		e.AtMs, e.Actor, e.Kind, e.Subject, e.Detail, e.OK)
	return err
}

// Audit lists entries newest first, older than id before (0 for the newest),
// of one kind unless it is "".
func (s *Store) Audit(kind string, before int64, limit int) ([]AuditEntry, error) {
	q := `SELECT id, at_ms, actor, kind, subject, detail, ok FROM audit WHERE 1 = 1`
	args := []any{}
	if kind != "" {
		q += ` AND kind = ?`
		args = append(args, kind)
	}
	if before > 0 {
		q += ` AND id < ?`
		args = append(args, before)
	}
	rows, err := s.db.Query(q+` ORDER BY id DESC LIMIT ?`, append(args, limit)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []AuditEntry{}
	for rows.Next() {
		var e AuditEntry
		if err := rows.Scan(&e.ID, &e.AtMs, &e.Actor, &e.Kind, &e.Subject, &e.Detail, &e.OK); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}
