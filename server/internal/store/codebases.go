package store

import (
	"database/sql"
	"errors"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func (s *Store) PutCodebase(c *v1.Codebase) error {
	b, err := proto.Marshal(c)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`INSERT INTO codebases (id, node, path, info) VALUES (?, ?, ?, ?)
		ON CONFLICT (id) DO UPDATE SET node = excluded.node, path = excluded.path, info = excluded.info`, c.Id, c.Node, c.Path, b)
	return err
}

func (s *Store) Codebases() ([]*v1.Codebase, error) {
	rows, err := s.db.Query(`SELECT info FROM codebases ORDER BY node, path`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.Codebase
	for rows.Next() {
		var b []byte
		if err := rows.Scan(&b); err != nil {
			return nil, err
		}
		c := &v1.Codebase{}
		if err := proto.Unmarshal(b, c); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) PutSnapshot(sn *v1.Snapshot) error {
	b, err := proto.Marshal(sn)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`INSERT INTO snapshots (id, codebase, created_ms, info) VALUES (?, ?, ?, ?)`, sn.Id, sn.Codebase, sn.CreatedMs, b)
	return err
}

// Snapshot returns one snapshot, or nil.
func (s *Store) Snapshot(id string) (*v1.Snapshot, error) {
	var b []byte
	err := s.db.QueryRow(`SELECT info FROM snapshots WHERE id = ?`, id).Scan(&b)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	sn := &v1.Snapshot{}
	return sn, proto.Unmarshal(b, sn)
}

// Snapshots lists a codebase's snapshots, newest first.
func (s *Store) Snapshots(codebase string, limit int) ([]*v1.Snapshot, error) {
	rows, err := s.db.Query(`SELECT info FROM snapshots WHERE codebase = ? ORDER BY created_ms DESC LIMIT ?`, codebase, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.Snapshot
	for rows.Next() {
		var b []byte
		if err := rows.Scan(&b); err != nil {
			return nil, err
		}
		sn := &v1.Snapshot{}
		if err := proto.Unmarshal(b, sn); err != nil {
			return nil, err
		}
		out = append(out, sn)
	}
	return out, rows.Err()
}

// SealedEnv is one .env file in the vault: its keys in the clear, the file
// itself encrypted by the hub.
type SealedEnv struct {
	Info          *v1.EnvFile
	Nonce, Sealed []byte
}

func (s *Store) PutEnv(codebase string, e SealedEnv) error {
	b, err := proto.Marshal(e.Info)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`INSERT INTO codebase_env (codebase, path, info, nonce, sealed) VALUES (?, ?, ?, ?, ?)
		ON CONFLICT (codebase, path) DO UPDATE SET info = excluded.info, nonce = excluded.nonce, sealed = excluded.sealed`,
		codebase, e.Info.Path, b, e.Nonce, e.Sealed)
	return err
}

// DeleteEnvExcept drops a codebase's .env files that are no longer there.
func (s *Store) DeleteEnvExcept(codebase string, keep []string) error {
	have, err := s.Env(codebase)
	if err != nil {
		return err
	}
	kept := map[string]bool{}
	for _, p := range keep {
		kept[p] = true
	}
	for _, e := range have {
		if !kept[e.Info.Path] {
			if _, err := s.db.Exec(`DELETE FROM codebase_env WHERE codebase = ? AND path = ?`, codebase, e.Info.Path); err != nil {
				return err
			}
		}
	}
	return nil
}

func (s *Store) Env(codebase string) ([]SealedEnv, error) {
	rows, err := s.db.Query(`SELECT info, nonce, sealed FROM codebase_env WHERE codebase = ? ORDER BY path`, codebase)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SealedEnv
	for rows.Next() {
		var b []byte
		e := SealedEnv{Info: &v1.EnvFile{}}
		if err := rows.Scan(&b, &e.Nonce, &e.Sealed); err != nil {
			return nil, err
		}
		if err := proto.Unmarshal(b, e.Info); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}
