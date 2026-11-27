package store

import (
	"path/filepath"
	"testing"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestGrantsAndSlotsStorage(t *testing.T) {
	path := filepath.Join(t.TempDir(), "hub.db")
	s, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()

	// Grant with time window (8pm to 10am)
	g := &v1.DeviceGrant{
		User:      "u1",
		Access:    "full",
		GrantedMs: 1000,
		StartHour: 20,
		EndHour:   10,
		Days:      "mon,tue,wed,thu,fri",
		Timezone:  "America/New_York",
	}
	if err := s.PutGrant("node-gpu", g); err != nil {
		t.Fatal(err)
	}

	grants, err := s.Grants()
	if err != nil {
		t.Fatal(err)
	}
	gotG := grants["node-gpu"]["u1"]
	if gotG == nil {
		t.Fatal("expected grant not found")
	}
	if gotG.StartHour != 20 || gotG.EndHour != 10 || gotG.Days != "mon,tue,wed,thu,fri" || gotG.Timezone != "America/New_York" {
		t.Fatalf("grant fields mismatch: %+v", gotG)
	}

	// Slot booking
	slot := &v1.DeviceSlot{
		Id:        "slot-1",
		Node:      "node-gpu",
		User:      "u1",
		StartMs:   20000,
		EndMs:     30000,
		Notes:     "LLM finetuning",
		CreatedMs: 15000,
	}
	if err := s.PutSlot(slot); err != nil {
		t.Fatal(err)
	}

	slots, err := s.Slots("node-gpu")
	if err != nil {
		t.Fatal(err)
	}
	if len(slots) != 1 || slots[0].Id != "slot-1" || slots[0].Notes != "LLM finetuning" {
		t.Fatalf("unexpected slots: %+v", slots)
	}

	// Delete slot
	if err := s.DeleteSlot("slot-1"); err != nil {
		t.Fatal(err)
	}
	slots, err = s.Slots("node-gpu")
	if err != nil {
		t.Fatal(err)
	}
	if len(slots) != 0 {
		t.Fatalf("expected 0 slots after delete, got %d", len(slots))
	}

	// Delete user cleans up grants and slots
	if err := s.PutSlot(slot); err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteUser("u1"); err != nil {
		t.Fatal(err)
	}
	grants, err = s.Grants()
	if err != nil {
		t.Fatal(err)
	}
	if len(grants["node-gpu"]) != 0 {
		t.Fatalf("expected grants to be cleaned up, got %v", grants["node-gpu"])
	}
	slots, err = s.Slots("node-gpu")
	if err != nil {
		t.Fatal(err)
	}
	if len(slots) != 0 {
		t.Fatalf("expected slots to be cleaned up, got %v", slots)
	}
}
