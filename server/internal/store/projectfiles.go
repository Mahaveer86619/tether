package store

// SealedFile is one file of a project's vault as it is stored.
type SealedFile struct {
	Repo      string
	Path      string
	Nonce     []byte
	Sealed    []byte
	UpdatedMs int64
}

func (s *Store) PutProjectFile(f SealedFile) error {
	_, err := s.db.Exec(`INSERT INTO project_files (repo, path, nonce, sealed, updated_ms) VALUES (?, ?, ?, ?, ?)
		ON CONFLICT(repo, path) DO UPDATE SET nonce=excluded.nonce, sealed=excluded.sealed, updated_ms=excluded.updated_ms`,
		f.Repo, f.Path, f.Nonce, f.Sealed, f.UpdatedMs)
	return err
}

// ProjectFiles lists a project's files by path.
func (s *Store) ProjectFiles(repo string) ([]SealedFile, error) {
	rows, err := s.db.Query(`SELECT repo, path, nonce, sealed, updated_ms FROM project_files WHERE repo = ? ORDER BY path`, repo)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SealedFile
	for rows.Next() {
		var f SealedFile
		if err := rows.Scan(&f.Repo, &f.Path, &f.Nonce, &f.Sealed, &f.UpdatedMs); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

func (s *Store) DeleteProjectFile(repo, path string) error {
	_, err := s.db.Exec(`DELETE FROM project_files WHERE repo = ? AND path = ?`, repo, path)
	return err
}

// SetProjectNode allows a device to receive a project's files, or stops it.
func (s *Store) SetProjectNode(repo, node string, allow bool) error {
	if allow {
		_, err := s.db.Exec(`INSERT OR IGNORE INTO project_nodes (repo, node) VALUES (?, ?)`, repo, node)
		return err
	}
	_, err := s.db.Exec(`DELETE FROM project_nodes WHERE repo = ? AND node = ?`, repo, node)
	return err
}

// ProjectNodes lists the devices allowed a project's files.
func (s *Store) ProjectNodes(repo string) ([]string, error) {
	rows, err := s.db.Query(`SELECT node FROM project_nodes WHERE repo = ? ORDER BY node`, repo)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var n string
		if err := rows.Scan(&n); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}
