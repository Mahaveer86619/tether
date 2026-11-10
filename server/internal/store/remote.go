package store

import "database/sql"

// ChatRemote is a chat whose project folder is kept in step: the folder on
// the device that works on it (the source) is pushed to the hub's repository
// after each turn, and the other device's copy (the mirror) is pulled from it.
type ChatRemote struct {
	Chat       string `json:"chat"`
	Repo       string `json:"repo"`
	Branch     string `json:"branch"`
	SourceNode string `json:"source_node"`
	SourceCwd  string `json:"source_cwd"`
	MirrorNode string `json:"mirror_node"`
	MirrorCwd  string `json:"mirror_cwd"`
	// State is one of: pending, syncing, synced, failed.
	State    string `json:"state"`
	Error    string `json:"error,omitempty"`
	SyncedMs int64  `json:"synced_ms"`
}

func (s *Store) PutChatRemote(r ChatRemote) error {
	_, err := s.db.Exec(`INSERT INTO chat_remote (chat, repo, branch, source_node, source_cwd, mirror_node, mirror_cwd, state, error, synced_ms)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(chat) DO UPDATE SET repo=excluded.repo, branch=excluded.branch, source_node=excluded.source_node, source_cwd=excluded.source_cwd,
			mirror_node=excluded.mirror_node, mirror_cwd=excluded.mirror_cwd, state=excluded.state, error=excluded.error, synced_ms=excluded.synced_ms`,
		r.Chat, r.Repo, r.Branch, r.SourceNode, r.SourceCwd, r.MirrorNode, r.MirrorCwd, r.State, r.Error, r.SyncedMs)
	return err
}

// ChatRemote is a chat's remote setup, and false when it has none.
func (s *Store) ChatRemote(chat string) (ChatRemote, bool, error) {
	var r ChatRemote
	err := s.db.QueryRow(`SELECT chat, repo, branch, source_node, source_cwd, mirror_node, mirror_cwd, state, error, synced_ms FROM chat_remote WHERE chat = ?`, chat).
		Scan(&r.Chat, &r.Repo, &r.Branch, &r.SourceNode, &r.SourceCwd, &r.MirrorNode, &r.MirrorCwd, &r.State, &r.Error, &r.SyncedMs)
	if err == sql.ErrNoRows {
		return ChatRemote{}, false, nil
	}
	return r, err == nil, err
}

func (s *Store) DeleteChatRemote(chat string) error {
	_, err := s.db.Exec(`DELETE FROM chat_remote WHERE chat = ?`, chat)
	return err
}
