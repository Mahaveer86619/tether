package store

import (
	"path/filepath"
	"testing"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestChatsMigrateIntoAnOlderDatabase(t *testing.T) {
	path := filepath.Join(t.TempDir(), "hub.db")
	s, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	// Back to how a 0.15 hub left it: one migration run, no chat tables.
	for _, q := range []string{`DROP TABLE chats`, `DROP TABLE chat_sessions`, `DROP TABLE chat_messages`, `DROP TABLE chat_notes`, `PRAGMA user_version = 1`} {
		if _, err := s.db.Exec(q); err != nil {
			t.Fatal(q, err)
		}
	}
	s.Close()

	s, err = Open(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := s.PutChat(&v1.Chat{Id: "c1", Title: "first", UpdatedMs: 10, Sessions: []*v1.ChatLink{{Session: "ignored"}}}); err != nil {
		t.Fatal(err)
	}
	if err := s.PutChat(&v1.Chat{Id: "c2", Title: "second", UpdatedMs: 20}); err != nil {
		t.Fatal(err)
	}
	for _, l := range []*v1.ChatLink{{Session: "s1", Role: "main", LinkedMs: 1}, {Session: "s2", Role: "fork", LinkedMs: 2}, {Session: "s1", Role: "linked", LinkedMs: 3}} {
		if err := s.LinkSession("c1", l); err != nil {
			t.Fatal(err)
		}
	}
	if err := s.PutChatMessages("c1", []*v1.ChatMessage{{Session: "s1", ItemId: "a", Role: "user", Text: "hi", TsMs: 5}}); err != nil {
		t.Fatal(err)
	}
	if err := s.PutChatMessages("c1", []*v1.ChatMessage{{Session: "s1", ItemId: "a", Role: "user", Text: "hi there", TsMs: 5}}); err != nil {
		t.Fatal(err)
	}
	s.Close()

	s, err = Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	chats, err := s.Chats()
	if err != nil || len(chats) != 2 || chats[0].Id != "c2" {
		t.Fatalf("chats %v %v", chats, err)
	}
	c1 := chats[1]
	if len(c1.Sessions) != 2 || c1.Sessions[0].Role != "main" || c1.Sessions[1].Session != "s2" {
		t.Fatalf("links %v", c1.Sessions)
	}
	msgs, err := s.ChatMessages("c1")
	if err != nil || len(msgs) != 1 || msgs[0].Text != "hi there" {
		t.Fatalf("messages %v %v", msgs, err)
	}
	if err := s.UnlinkSession("c1", "s2"); err != nil {
		t.Fatal(err)
	}
	chats, _ = s.Chats()
	if len(chats[1].Sessions) != 1 {
		t.Fatalf("unlink %v", chats[1].Sessions)
	}
}
