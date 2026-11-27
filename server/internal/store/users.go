package store

import (
	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Users lists everyone, oldest first: the first is the hub's owner.
func (s *Store) Users() ([]*v1.User, error) {
	rows, err := s.db.Query(`SELECT id, name, role, created_ms FROM users ORDER BY created_ms, rowid`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.User
	for rows.Next() {
		u := &v1.User{}
		if err := rows.Scan(&u.Id, &u.Name, &u.Role, &u.CreatedMs); err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

func (s *Store) PutUser(u *v1.User) error {
	_, err := s.db.Exec(`INSERT INTO users (id, name, role, created_ms) VALUES (?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET name = excluded.name, role = excluded.role`, u.Id, u.Name, u.Role, u.CreatedMs)
	return err
}

// DeleteUser removes a user and every grant and slot made to them.
func (s *Store) DeleteUser(id string) error {
	if _, err := s.db.Exec(`DELETE FROM device_slots WHERE user = ?`, id); err != nil {
		return err
	}
	if _, err := s.db.Exec(`DELETE FROM device_grants WHERE user = ?`, id); err != nil {
		return err
	}
	_, err := s.db.Exec(`DELETE FROM users WHERE id = ?`, id)
	return err
}

// Grants returns every device grant, by node and then user.
func (s *Store) Grants() (map[string]map[string]*v1.DeviceGrant, error) {
	rows, err := s.db.Query(`SELECT node, user, access, granted_ms, start_hour, end_hour, days, timezone FROM device_grants`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]map[string]*v1.DeviceGrant{}
	for rows.Next() {
		var node string
		g := &v1.DeviceGrant{}
		if err := rows.Scan(&node, &g.User, &g.Access, &g.GrantedMs, &g.StartHour, &g.EndHour, &g.Days, &g.Timezone); err != nil {
			return nil, err
		}
		if out[node] == nil {
			out[node] = map[string]*v1.DeviceGrant{}
		}
		out[node][g.User] = g
	}
	return out, rows.Err()
}

func (s *Store) PutGrant(node string, g *v1.DeviceGrant) error {
	_, err := s.db.Exec(`INSERT INTO device_grants (node, user, access, granted_ms, start_hour, end_hour, days, timezone) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(node, user) DO UPDATE SET access = excluded.access, granted_ms = excluded.granted_ms,
			start_hour = excluded.start_hour, end_hour = excluded.end_hour, days = excluded.days, timezone = excluded.timezone`,
		node, g.User, g.Access, g.GrantedMs, g.StartHour, g.EndHour, g.Days, g.Timezone)
	return err
}

func (s *Store) DeleteGrant(node, user string) error {
	_, err := s.db.Exec(`DELETE FROM device_grants WHERE node = ? AND user = ?`, node, user)
	return err
}

// Slots returns every slot booked on node (or all nodes when node == "").
func (s *Store) Slots(node string) ([]*v1.DeviceSlot, error) {
	var query string
	var args []any
	if node != "" {
		query = `SELECT id, node, user, start_ms, end_ms, notes, created_ms FROM device_slots WHERE node = ? ORDER BY start_ms`
		args = append(args, node)
	} else {
		query = `SELECT id, node, user, start_ms, end_ms, notes, created_ms FROM device_slots ORDER BY start_ms`
	}
	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.DeviceSlot
	for rows.Next() {
		slot := &v1.DeviceSlot{}
		if err := rows.Scan(&slot.Id, &slot.Node, &slot.User, &slot.StartMs, &slot.EndMs, &slot.Notes, &slot.CreatedMs); err != nil {
			return nil, err
		}
		out = append(out, slot)
	}
	return out, rows.Err()
}

func (s *Store) PutSlot(slot *v1.DeviceSlot) error {
	_, err := s.db.Exec(`INSERT INTO device_slots (id, node, user, start_ms, end_ms, notes, created_ms) VALUES (?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET node = excluded.node, user = excluded.user, start_ms = excluded.start_ms, end_ms = excluded.end_ms, notes = excluded.notes`,
		slot.Id, slot.Node, slot.User, slot.StartMs, slot.EndMs, slot.Notes, slot.CreatedMs)
	return err
}

func (s *Store) DeleteSlot(id string) error {
	_, err := s.db.Exec(`DELETE FROM device_slots WHERE id = ?`, id)
	return err
}

// GiveUnowned makes user the owner of the notifications and artifacts that
// have none: everything from before users existed.
func (s *Store) GiveUnowned(user string) error {
	if _, err := s.db.Exec(`UPDATE notifications SET user = ? WHERE user = ''`, user); err != nil {
		return err
	}
	_, err := s.db.Exec(`UPDATE artifacts SET owner = ? WHERE owner = ''`, user)
	return err
}
