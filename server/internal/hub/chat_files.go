package hub

import (
	"net/http"
	"strconv"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"google.golang.org/protobuf/proto"
)

const chatFilesPage = 50

// What the chat's Files panel calls "sent" and "made".
var fileOrigins = map[string][]string{
	"sent": {"attachment", "upload"},
	"made": {"result", "write", "page"},
}

// chatFiles serves GET /api/v1/chats/{id}/artifacts: the files of every
// session in the chat, newest first. Query: origin=sent|made, q (name
// contains), before (created_ms of the last row of the previous page),
// limit. Caller holds h.mu. See docs/deliverables.md.
func (h *Hub) chatFiles(id string, r *http.Request) (proto.Message, *opError) {
	c := h.chats[id]
	if c == nil {
		return nil, errChatNotFound
	}
	q := r.URL.Query()
	origins, ok := fileOrigins[q.Get("origin")]
	if q.Get("origin") != "" && !ok {
		return nil, invalid("origin is sent or made")
	}
	limit := chatFilesPage
	if n, err := strconv.Atoi(q.Get("limit")); err == nil && n > 0 {
		limit = min(n, 200)
	}
	before, _ := strconv.ParseInt(q.Get("before"), 10, 64)
	var sessions []string
	for _, l := range c.Sessions {
		sessions = append(sessions, l.Session)
	}
	list, err := h.store.ArtifactsOf(sessions, origins, q.Get("q"), before, limit)
	if err != nil {
		return nil, internalError(err)
	}
	return &v1.ArtifactList{Artifacts: hideBackups(r, list)}, nil
}
