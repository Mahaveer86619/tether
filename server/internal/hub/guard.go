package hub

import (
	"context"
	"net/http"
	"net/url"
	"strings"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// The guard sits in front of every route: it finds the route's policy and
// asks can before the handler runs. A route with no policy is refused to
// everyone but the admin token, so a new route is closed until it is listed
// here. Lists are filtered by their handlers, with the identity the guard
// puts on the request. See docs/architecture/security.md#users.

type routeCheck func(h *Hub, id identity, p params, r *http.Request) bool

type params map[string]string

// Routes with their own credential (a pairing code, a signature, a
// notification token) or none.
var publicRoutes = map[string]bool{
	"/healthz":          true,
	"GET /api/v1/hello": true,
	"POST /api/v1/pair": true,
	"/ws":               true,
	"/mcp":              true,
	"GET /n/ping":       true,
	"GET /n/poll":       true,
	"GET /p/{session}/{name}/{exp}/{sig}/{file...}": true,
}

func anyone(*Hub, identity, params, *http.Request) bool { return true }

func admin(h *Hub, id identity, _ params, _ *http.Request) bool {
	return h.can(id, actAdmin, objHub, "")
}

func on(kind objKind, param string, act action) routeCheck {
	return func(h *Hub, id identity, p params, _ *http.Request) bool {
		return h.can(id, act, kind, p[param])
	}
}

func both(a, b routeCheck) routeCheck {
	return func(h *Hub, id identity, p params, r *http.Request) bool {
		return a(h, id, p, r) && b(h, id, p, r)
	}
}

func either(a, b routeCheck) routeCheck {
	return func(h *Hub, id identity, p params, r *http.Request) bool {
		return a(h, id, p, r) || b(h, id, p, r)
	}
}

// node lets an agent's token through for its own machine's business; a
// member's agent only for its own node's codebases.
func node(h *Hub, id identity, p params, _ *http.Request) bool {
	if id.kind != kindNode || id.device == nil {
		return false
	}
	if h.users[id.userID()] != nil && h.users[id.userID()].Role == roleAdmin {
		return true
	}
	if c := p["codebase"]; c != "" {
		cb, err := h.codebase(c)
		return err == nil && cb.Node == id.device.Name
	}
	return false
}

// nodeCodebase is node for routes whose {id} is a codebase.
func nodeCodebase(h *Hub, id identity, p params, r *http.Request) bool {
	return node(h, id, params{"codebase": p["id"]}, r)
}

func sessionQuery(act action) routeCheck {
	return func(h *Hub, id identity, _ params, r *http.Request) bool {
		s := r.URL.Query().Get("session")
		return s == "" && h.can(id, actAdmin, objHub, "") || s != "" && h.can(id, act, objSession, s)
	}
}

// uploadFor: an artifact for a session needs the right to send into it; an
// agent may file artifacts only for sessions on its own machine.
func uploadFor(h *Hub, id identity, _ params, r *http.Request) bool {
	s, _ := url.QueryUnescape(r.Header.Get("X-Session"))
	s = strings.TrimSpace(s)
	if id.kind == kindNode {
		info := h.sessions[s]
		return s == "" || info != nil && id.device != nil && info.Node == id.device.Name
	}
	return s == "" || h.can(id, actUse, objSession, s)
}

func artifactRead(h *Hub, id identity, p params, r *http.Request) bool {
	if r.URL.Query().Get("sig") != "" {
		return true
	}
	if id.kind == kindNode && id.device != nil {
		a, err := h.store.Artifact(p["id"])
		if err == nil && a != nil && (a.Node == id.device.Name || h.sessions[a.Session] != nil && h.sessions[a.Session].Node == id.device.Name) {
			return true
		}
	}
	return h.can(id, actView, objArtifact, p["id"])
}

func ownUpload(h *Hub, id identity, p params, _ *http.Request) bool {
	_, pu, err := h.loadUpload(p["id"])
	if err != nil {
		return true // the handler says it is unknown
	}
	a := &v1.Artifact{}
	if proto.Unmarshal(pu.Artifact, a) != nil {
		return false
	}
	return id.root() || firstNonEmpty(a.Owner, h.ownerID) == id.userID()
}

func ownDevice(h *Hub, id identity, p params, _ *http.Request) bool {
	for _, d := range h.devices {
		if d.Id == p["id"] {
			return d.User == id.userID() || h.can(id, actAdmin, objHub, "")
		}
	}
	return h.can(id, actAdmin, objHub, "")
}

func self(h *Hub, id identity, p params, _ *http.Request) bool {
	return p["user"] == id.userID() || h.can(id, actAdmin, objHub, "")
}

func hubClaude(h *Hub, id identity, _ params, _ *http.Request) bool {
	return h.can(id, actRunClaude, objNode, h.hubNode())
}

// projectQuery checks the ?project= a new chat is filed under, if any.
func projectQuery(h *Hub, id identity, _ params, r *http.Request) bool {
	p := r.URL.Query().Get("project")
	return p == "" || h.can(id, actManage, objProject, p)
}

var routePolicy = map[string]routeCheck{
	"GET /api/v1/state":                         anyone,
	"GET /api/v1/me":                            anyone,
	"GET /api/v1/users":                         anyone,
	"POST /api/v1/invites":                      admin,
	"PUT /api/v1/users/{user}":                  self,
	"DELETE /api/v1/users/{user}":               admin,
	"PUT /api/v1/nodes/{node}/grants":           on(objNode, "node", actManage),
	"DELETE /api/v1/nodes/{node}/grants/{user}": on(objNode, "node", actManage),
	"GET /api/v1/nodes/{node}/slots":            on(objNode, "node", actView),
	"POST /api/v1/nodes/{node}/slots":           on(objNode, "node", actView),
	"DELETE /api/v1/nodes/{node}/slots/{slot}":  on(objNode, "node", actView),

	"POST /api/v1/sessions":                      anyone, // startSession checks the node
	"GET /api/v1/sessions/{id}/timeline":         on(objSession, "id", actView),
	"GET /api/v1/sessions/{id}/lineage":          on(objSession, "id", actView),
	"GET /api/v1/sessions/{id}/screen":           on(objSession, "id", actView),
	"POST /api/v1/sessions/{id}/messages":        on(objSession, "id", actUse),
	"POST /api/v1/sessions/{id}/keys":            on(objSession, "id", actUse),
	"POST /api/v1/sessions/{id}/mode":            on(objSession, "id", actUse),
	"POST /api/v1/sessions/{id}/archive":         on(objSession, "id", actUse),
	"POST /api/v1/sessions/{id}/interrupt":       on(objSession, "id", actStop),
	"POST /api/v1/sessions/{id}/stop":            on(objSession, "id", actStop),
	"POST /api/v1/sessions/{id}/global":          on(objSession, "id", actManage),
	"POST /api/v1/sessions/{id}/rebuild":         on(objSession, "id", actManage),
	"POST /api/v1/sessions/{id}/continue":        both(on(objSession, "id", actUse), hubClaude),
	"GET /api/v1/history/sessions/{id}":          on(objSession, "id", actView),
	"POST /api/v1/approvals/{id}":                on(objApproval, "id", actUse),
	"GET /api/v1/pages":                          sessionQuery(actView),
	"POST /api/v1/pairing-codes":                 anyone,
	"GET /api/v1/devices":                        anyone,
	"DELETE /api/v1/devices/{id}":                ownDevice,
	"GET /api/v1/notifications":                  anyone,
	"POST /api/v1/notifications/test":            anyone,
	"POST /api/v1/notify-token":                  anyone,
	"GET /api/v1/updates/latest":                 anyone,
	"GET /api/v1/updates/files/{version}/{name}": anyone,
	"GET /api/v1/targets":                        anyone,
	"GET /api/v1/rules":                          anyone,
	"GET /api/v1/skills":                         anyone,
	"GET /api/v1/skills/{name}":                  anyone,
	"GET /api/v1/desk":                           anyone,

	"POST /api/v1/artifacts":             uploadFor,
	"GET /api/v1/artifacts":              anyone,
	"GET /api/v1/artifacts/{id}/content": artifactRead,
	"POST /api/v1/artifacts/{id}/link":   on(objArtifact, "id", actView),
	"DELETE /api/v1/artifacts/{id}":      on(objArtifact, "id", actManage),
	"POST /api/v1/uploads":               uploadFor,
	"GET /api/v1/uploads/{id}":           ownUpload,
	"PATCH /api/v1/uploads/{id}":         ownUpload,
	"DELETE /api/v1/uploads/{id}":        ownUpload,

	"GET /api/v1/jobs":                   anyone,
	"POST /api/v1/jobs":                  anyone, // startJob checks the node
	"POST /api/v1/jobs/{id}/{action}":    on(objJob, "id", actStop),
	"DELETE /api/v1/jobs/{id}":           on(objJob, "id", actManage),
	"GET /api/v1/jobs/{id}/logs":         on(objJob, "id", actView),
	"GET /api/v1/chats":                  anyone,
	"POST /api/v1/chats":                 projectQuery,
	"PATCH /api/v1/chats/{id}":           on(objChat, "id", actManage),
	"DELETE /api/v1/chats/{id}":          on(objChat, "id", actManage),
	"POST /api/v1/chats/{id}/messages":   on(objChat, "id", actUse),
	"POST /api/v1/chats/{id}/target":     on(objChat, "id", actManage),
	"POST /api/v1/chats/{id}/links":      on(objChat, "id", actManage),
	"GET /api/v1/chats/{id}/context":     on(objChat, "id", actView),
	"GET /api/v1/chats/{id}/artifacts":   on(objChat, "id", actView),
	"GET /api/v1/chats/{id}/history":     on(objChat, "id", actView),
	"GET /api/v1/chats/{id}/desk":        on(objChat, "id", actView),
	"PUT /api/v1/chats/{id}/desk":        on(objChat, "id", actManage),
	"POST /api/v1/chats/{id}/rewind":     on(objChat, "id", actManage),
	"POST /api/v1/chats/{id}/handoff":    on(objChat, "id", actManage),
	"GET /api/v1/chats/{id}/remote":      on(objChat, "id", actView),
	"POST /api/v1/chats/{id}/remote":     both(on(objChat, "id", actManage), admin),
	"PUT /api/v1/chats/{id}/shares":      on(objChat, "id", actManage),
	"PUT /api/v1/chats/{id}/project":     on(objChat, "id", actManage),
	"GET /api/v1/projects":               anyone,
	"POST /api/v1/projects":              anyone,
	"GET /api/v1/chat-projects":          anyone,
	"PUT /api/v1/projects/{id}":          on(objProject, "id", actManage),
	"DELETE /api/v1/projects/{id}":       on(objProject, "id", actManage),
	"POST /api/v1/projects/{id}/folders": on(objProject, "id", actManage),

	// Hub-wide: the owner's settings, history, codebases and second brain.
	// Members get their own views of these with workspaces (step B2).
	"GET /api/v1/clients":                       admin,
	"GET /api/v1/workspaces":                    admin,
	"PUT /api/v1/workspaces":                    admin,
	"DELETE /api/v1/workspaces":                 admin,
	"GET /api/v1/usage":                         admin,
	"PUT /api/v1/preferences":                   admin,
	"GET /api/v1/tailnet":                       admin,
	"GET /api/v1/audit":                         admin,
	"PUT /api/v1/desk":                          admin,
	"GET /api/v1/history/status":                admin,
	"GET /api/v1/history/search":                admin,
	"GET /api/v1/history/changes":               admin,
	"GET /api/v1/history/export":                admin,
	"POST /api/v1/history/sync":                 admin,
	"GET /api/v1/insights":                      admin,
	"GET /api/v1/insights/stats":                admin,
	"POST /api/v1/insights/analyze":             admin,
	"POST /api/v1/rules":                        admin,
	"PUT /api/v1/rules/{id}":                    admin,
	"DELETE /api/v1/rules/{id}":                 admin,
	"GET /api/v1/skills/candidates":             admin,
	"POST /api/v1/skills/draft":                 admin,
	"POST /api/v1/skills/{name}/approve":        admin,
	"POST /api/v1/skills/{name}/dismiss":        admin,
	"POST /api/v1/skills/{name}/rollback":       admin,
	"POST /brain/mcp":                           admin,
	"GET /brain/healthz":                        admin,
	"GET /api/v1/codebases":                     admin,
	"POST /api/v1/codebases/{id}/snapshot":      admin,
	"GET /api/v1/codebases/{id}/snapshots":      admin,
	"POST /api/v1/codebases/found":              either(admin, node),
	"POST /api/v1/codebases/{id}/manifest":      either(admin, nodeCodebase),
	"POST /api/v1/codebases/{id}/snapshots":     either(admin, nodeCodebase),
	"POST /api/v1/codebases/{id}/error":         either(admin, nodeCodebase),
	"PUT /api/v1/codebases/{id}/env":            either(admin, nodeCodebase),
	"GET /api/v1/codebases/{id}/env/files":      either(admin, nodeCodebase),
	"GET /api/v1/snapshots/{id}/manifest":       either(admin, node),
	"PUT /api/v1/blobs/{sha}":                   either(admin, node),
	"GET /api/v1/blobs/{sha}":                   either(admin, node),
	"POST /api/v1/repos":                        either(admin, node),
	"/git/":                                     either(admin, node),
	"GET /api/v1/projects/{repo}/files":         admin,
	"PUT /api/v1/projects/{repo}/files":         admin,
	"DELETE /api/v1/projects/{repo}/files":      admin,
	"GET /api/v1/projects/{repo}/files/content": either(admin, node),
	"GET /api/v1/projects/{repo}/devices":       admin,
	"POST /api/v1/projects/{repo}/devices":      admin,
}

// guard wraps the mux with the route policies.
func (h *Hub) guard(mux *http.ServeMux) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, pattern := mux.Handler(r)
		if pattern == "" || publicRoutes[pattern] {
			mux.ServeHTTP(w, r)
			return
		}
		token, _ := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		id, ok := h.identifyFrom(token, remoteIP(r))
		if !ok {
			// The handler refuses it, counting the failure.
			mux.ServeHTTP(w, r)
			return
		}
		check := routePolicy[pattern]
		h.mu.Lock()
		allowed := id.root() || check != nil && check(h, id, pathParams(pattern, r.URL.Path), r)
		h.mu.Unlock()
		if !allowed {
			writeError(w, errForbidden)
			return
		}
		mux.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), identityKey{}, id)))
	})
}

// pathParams reads a pattern's {names} out of a path, as the mux will.
func pathParams(pattern, path string) params {
	if _, p, ok := strings.Cut(pattern, " "); ok {
		pattern = p
	}
	out := params{}
	segs := strings.Split(strings.Trim(path, "/"), "/")
	for i, s := range strings.Split(strings.Trim(pattern, "/"), "/") {
		if !strings.HasPrefix(s, "{") || i >= len(segs) {
			continue
		}
		name := strings.Trim(s, "{}")
		v := segs[i]
		if rest, ok := strings.CutSuffix(name, "..."); ok {
			name, v = rest, strings.Join(segs[i:], "/")
		}
		if u, err := url.PathUnescape(v); err == nil {
			v = u
		}
		out[name] = v
	}
	return out
}
