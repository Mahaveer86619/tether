package hub

import (
	"testing"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

func TestASessionFolderBelongsToTheCodebaseUnderItsWorkspaceRoot(t *testing.T) {
	h, _ := newTestHubWith(t)
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, err := h.setWorkspaceRoot(&v1.WorkspaceRoot{Node: "laptop", Path: `C:\Users\me\projects\personal`}, false); err != nil {
		t.Fatal(err)
	}
	c := h.codebaseFor("laptop", `C:\Users\me\projects\personal\shop\server`)
	if c == nil || c.Name != "shop" || c.Path != `C:\Users\me\projects\personal\shop` {
		t.Fatalf("want the shop codebase, got %v", c)
	}
	// Server and web folders are parts of one codebase, and Windows paths ignore case.
	if again := h.codebaseFor("laptop", `c:\users\me\projects\personal\shop\web`); again == nil || again.Id != c.Id {
		t.Fatalf("want the same codebase, got %v", again)
	}
	if other := h.codebaseFor("minipc", `C:\Users\me\projects\personal\shop`); other != nil {
		t.Fatal("another node's folder is another codebase")
	}
	if outside := h.codebaseFor("laptop", `C:\Users\me\Downloads`); outside != nil {
		t.Fatal("folders outside workspace roots aren't codebases")
	}
	if rel, ok := relPath(c.Path, `C:\Users\me\projects\personal\shop\server\cmd`); !ok || rel != "server/cmd" {
		t.Fatalf("relPath: %q %v", rel, ok)
	}
}
