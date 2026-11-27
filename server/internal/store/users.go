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

// DeleteUser removes a user and every grant made to them.
func (s *Store) DeleteUser(id string) error {
	if _, err := s.db.Exec(`DELETE FROM device_grants WHERE user = ?`, id); err != nil {
		return err
	}
	_, err := s.db.Exec(`DELETE FROM users WHERE id = ?`, id)
	return err
}

// Grants returns every device grant, by node and then user.
func (s *Store) Grants() (map[string]map[string]*v1.DeviceGrant, error) {
	rows, err := s.db.Query(`SELECT node, user, access, granted_ms FROM device_grants`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]map[string]*v1.DeviceGrant{}
	for rows.Next() {
		var node string
		g := &v1.DeviceGrant{}
		if err := rows.Scan(&node, &g.User, &g.Access, &g.GrantedMs); err != nil {
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
	_, err := s.db.Exec(`INSERT INTO device_grants (node, user, access, granted_ms) VALUES (?, ?, ?, ?)
		ON CONFLICT(node, user) DO UPDATE SET access = excluded.access, granted_ms = excluded.granted_ms`, node, g.User, g.Access, g.GrantedMs)
	return err
}

func (s *Store) DeleteGrant(node, user string) error {
	_, err := s.db.Exec(`DELETE FROM device_grants WHERE node = ? AND user = ?`, node, user)
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
