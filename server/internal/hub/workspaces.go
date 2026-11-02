package hub

import (
	"net/http"
	"sort"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Workspace roots: folders on each node that new projects are created in.
// The projects themselves are the folders sessions ran in, which the
// sessions already carry.

const workspacesKey = "workspace_roots"

// workspaces returns the declared roots. Caller holds h.mu.
func (h *Hub) workspaces() *v1.Workspaces {
	w := &v1.Workspaces{}
	if b, err := h.store.Get(workspacesKey); err == nil && b != nil {
		_ = protojson.Unmarshal(b, w)
	}
	return w
}

// setWorkspaceRoot adds or removes a root. Caller holds h.mu.
func (h *Hub) setWorkspaceRoot(root *v1.WorkspaceRoot, remove bool) (*v1.Workspaces, *opError) {
	if root.Node == "" || root.Path == "" {
		return nil, invalid("node and path are required")
	}
	w := h.workspaces()
	kept := w.Roots[:0]
	for _, r := range w.Roots {
		if r.Node != root.Node || r.Path != root.Path {
			kept = append(kept, r)
		}
	}
	w.Roots = kept
	if !remove {
		w.Roots = append(w.Roots, root)
	}
	sort.Slice(w.Roots, func(i, j int) bool {
		if w.Roots[i].Node != w.Roots[j].Node {
			return w.Roots[i].Node < w.Roots[j].Node
		}
		return w.Roots[i].Path < w.Roots[j].Path
	})
	b, err := protojson.Marshal(w)
	if err == nil {
		err = h.store.Put(workspacesKey, b)
	}
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	if !remove {
		h.scanRoots(root.Node)
	}
	return w, nil
}
