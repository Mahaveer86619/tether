package store

import (
	"database/sql"
	"path/filepath"
	"testing"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// An artifacts table as hubs before the note column made it.
const oldArtifacts = `
CREATE TABLE artifacts (
	id          TEXT PRIMARY KEY,
	sha256      TEXT NOT NULL,
	name        TEXT NOT NULL,
	mime        TEXT NOT NULL,
	size        INTEGER NOT NULL,
	session     TEXT NOT NULL DEFAULT '',
	node        TEXT NOT NULL DEFAULT '',
	origin      TEXT NOT NULL DEFAULT '',
	path        TEXT NOT NULL DEFAULT '',
	tool_use_id TEXT NOT NULL DEFAULT '',
	created_ms  INTEGER NOT NULL
);
INSERT INTO artifacts VALUES ('a1', 'abc', 'shot.png', 'image/png', 7, 's1', 'laptop', 'read', '/x/shot.png', 'toolu_1', 1000);
`

func TestMigrationKeepsOldArtifacts(t *testing.T) {
	path := filepath.Join(t.TempDir(), "hub.db")
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(oldArtifacts); err != nil {
		t.Fatal(err)
	}
	db.Close()

	for range 2 {
		s, err := Open(path)
		if err != nil {
			t.Fatal("open (migrations must run once and then be skipped): ", err)
		}
		a, err := s.Artifact("a1")
		if err != nil || a == nil {
			t.Fatal("old row lost: ", err)
		}
		if a.Name != "shot.png" || a.Size != 7 || a.Session != "s1" || a.ToolUseId != "toolu_1" || a.CreatedMs != 1000 || a.Note != "" {
			t.Fatalf("old row changed: %v", a)
		}
		var version int
		if err := s.db.QueryRow(`PRAGMA user_version`).Scan(&version); err != nil || version != len(migrations) {
			t.Fatalf("user_version %d, want %d", version, len(migrations))
		}
		s.Close()
	}

	s, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if err := s.PutArtifact(&v1.Artifact{Id: "a2", Sha256: "def", Name: "data.csv", Mime: "text/csv", Size: 9, Session: "s1", Origin: "attachment", Note: "for the report", CreatedMs: 2000}); err != nil {
		t.Fatal(err)
	}
	list, err := s.Artifacts("s1", 10)
	if err != nil || len(list) != 2 || list[0].Note != "for the report" {
		t.Fatalf("list: %v %v", list, err)
	}
}

func TestFreshDatabaseHasNoteColumn(t *testing.T) {
	s, err := Open(filepath.Join(t.TempDir(), "hub.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if err := s.PutArtifact(&v1.Artifact{Id: "a", Sha256: "x", Name: "n", Mime: "text/plain", Note: "hi", CreatedMs: 1}); err != nil {
		t.Fatal(err)
	}
	if a, err := s.Artifact("a"); err != nil || a.Note != "hi" {
		t.Fatalf("%v %v", a, err)
	}
}
