package store

import (
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// PutChat stores a chat. Its sessions live in chat_sessions, so the list on
// c is not stored here.
func (s *Store) PutChat(c *v1.Chat) error {
	stored := proto.Clone(c).(*v1.Chat)
	stored.Sessions = nil
	b, err := proto.Marshal(stored)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`INSERT INTO chats (id, info, updated_ms) VALUES (?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET info = excluded.info, updated_ms = excluded.updated_ms`, c.Id, b, c.UpdatedMs)
	return err
}

// Chats returns every chat with its sessions, oldest link first.
func (s *Store) Chats() ([]*v1.Chat, error) {
	rows, err := s.db.Query(`SELECT info FROM chats ORDER BY updated_ms DESC`)
	if err != nil {
		return nil, err
	}
	var out []*v1.Chat
	byID := map[string]*v1.Chat{}
	for rows.Next() {
		var b []byte
		if err := rows.Scan(&b); err != nil {
			rows.Close()
			return nil, err
		}
		c := &v1.Chat{}
		if err := proto.Unmarshal(b, c); err != nil {
			rows.Close()
			return nil, err
		}
		out = append(out, c)
		byID[c.Id] = c
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	links, err := s.db.Query(`SELECT chat, session, role, linked_ms FROM chat_sessions ORDER BY linked_ms, rowid`)
	if err != nil {
		return nil, err
	}
	defer links.Close()
	for links.Next() {
		var chat string
		l := &v1.ChatLink{}
		if err := links.Scan(&chat, &l.Session, &l.Role, &l.LinkedMs); err != nil {
			return nil, err
		}
		if c := byID[chat]; c != nil {
			c.Sessions = append(c.Sessions, l)
		}
	}
	return out, links.Err()
}

// LinkSession puts a session in a chat; linking it again keeps the first
// role and time.
func (s *Store) LinkSession(chat string, l *v1.ChatLink) error {
	_, err := s.db.Exec(`INSERT INTO chat_sessions (chat, session, role, linked_ms) VALUES (?, ?, ?, ?)
		ON CONFLICT(chat, session) DO NOTHING`, chat, l.Session, l.Role, l.LinkedMs)
	return err
}

func (s *Store) UnlinkSession(chat, session string) error {
	_, err := s.db.Exec(`DELETE FROM chat_sessions WHERE chat = ? AND session = ?`, chat, session)
	return err
}

// PutChatMessages keeps what was said in a chat, so its context outlives
// the sessions behind it. A message stored again is replaced.
func (s *Store) PutChatMessages(chat string, msgs []*v1.ChatMessage) error {
	if len(msgs) == 0 {
		return nil
	}
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	stmt, err := tx.Prepare(`INSERT INTO chat_messages (chat, session, item_id, role, text, ts_ms) VALUES (?, ?, ?, ?, ?, ?)
		ON CONFLICT(chat, session, item_id) DO UPDATE SET role = excluded.role, text = excluded.text`)
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, m := range msgs {
		if _, err := stmt.Exec(chat, m.Session, m.ItemId, m.Role, m.Text, m.TsMs); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// ChatMessages returns a chat's messages in the order they were said.
func (s *Store) ChatMessages(chat string) ([]*v1.ChatMessage, error) {
	rows, err := s.db.Query(`SELECT session, item_id, role, text, ts_ms FROM chat_messages WHERE chat = ? ORDER BY ts_ms, rowid`, chat)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.ChatMessage
	for rows.Next() {
		m := &v1.ChatMessage{}
		if err := rows.Scan(&m.Session, &m.ItemId, &m.Role, &m.Text, &m.TsMs); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (s *Store) PutChatNote(chat string, n *v1.ChatNote) error {
	_, err := s.db.Exec(`INSERT INTO chat_notes (chat, kind, value, updated_ms) VALUES (?, ?, ?, ?)
		ON CONFLICT(chat, kind) DO UPDATE SET value = excluded.value, updated_ms = excluded.updated_ms`, chat, n.Kind, n.Value, n.UpdatedMs)
	return err
}

func (s *Store) ChatNotes(chat string) ([]*v1.ChatNote, error) {
	rows, err := s.db.Query(`SELECT kind, value, updated_ms FROM chat_notes WHERE chat = ? ORDER BY kind`, chat)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.ChatNote
	for rows.Next() {
		n := &v1.ChatNote{}
		if err := rows.Scan(&n.Kind, &n.Value, &n.UpdatedMs); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}
