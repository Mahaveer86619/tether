package store

// Notification is something the owner is told about.
type Notification struct {
	ID      int64  `json:"id"`
	AtMs    int64  `json:"at"`
	Kind    string `json:"kind"`
	Title   string `json:"title"`
	Body    string `json:"body"`
	Chat    string `json:"chat,omitempty"`
	Session string `json:"session,omitempty"`
}

// AddNotification stores n and returns its id, keeping only the newest keep.
func (s *Store) AddNotification(n Notification, keep int) (int64, error) {
	res, err := s.db.Exec(`INSERT INTO notifications (at_ms, kind, title, body, chat, session) VALUES (?, ?, ?, ?, ?, ?)`,
		n.AtMs, n.Kind, n.Title, n.Body, n.Chat, n.Session)
	if err != nil {
		return 0, err
	}
	id, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}
	_, err = s.db.Exec(`DELETE FROM notifications WHERE id <= ?`, id-int64(keep))
	return id, err
}

// NotificationsAfter lists notifications newer than id, oldest first.
func (s *Store) NotificationsAfter(id int64, limit int) ([]Notification, error) {
	rows, err := s.db.Query(`SELECT id, at_ms, kind, title, body, chat, session FROM notifications WHERE id > ? ORDER BY id LIMIT ?`, id, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Notification{}
	for rows.Next() {
		var n Notification
		if err := rows.Scan(&n.ID, &n.AtMs, &n.Kind, &n.Title, &n.Body, &n.Chat, &n.Session); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

// LastNotificationID is the newest notification's id, 0 when there are none.
func (s *Store) LastNotificationID() (int64, error) {
	var id int64
	err := s.db.QueryRow(`SELECT COALESCE(MAX(id), 0) FROM notifications`).Scan(&id)
	return id, err
}
