package hub

import (
	"context"
	"io"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// opError is a failed operation, with the code both APIs report and the
// HTTP status the REST API uses.
type opError struct {
	Code    string
	Message string
	Status  int
}

func (e *opError) Error() string { return e.Message }

var (
	errUnauthorized   = &opError{"unauthorized", "missing or wrong token", http.StatusUnauthorized}
	errNotFound       = &opError{"not_found", "unknown session", http.StatusNotFound}
	errNodeOffline    = &opError{"node_offline", "node is not connected", http.StatusServiceUnavailable}
	errTerminalActive = &opError{"terminal_active", "session is open in a terminal; fork it instead", http.StatusConflict}
	errUnsupported    = &opError{"unsupported", "unsupported request", http.StatusBadRequest}
	errTerminalOwned  = &opError{"terminal_active", "session is open in your terminal; interrupt it or close it there", http.StatusConflict}
)

func invalid(msg string) *opError { return &opError{"invalid", msg, http.StatusBadRequest} }

const maxBody = 1 << 20

var (
	jsonOut = protojson.MarshalOptions{EmitUnpopulated: false}
	jsonIn  = protojson.UnmarshalOptions{DiscardUnknown: true}
)

// routes registers the REST API. It mirrors the WebSocket commands for
// clients that prefer request/response; live updates stay on /ws.
func (h *Hub) routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/state", h.api(func(r *http.Request) (proto.Message, *opError) {
		id, _ := r.Context().Value(identityKey{}).(identity)
		return h.welcome(id.deviceID(), remoteIP(r)), nil
	}))
	mux.HandleFunc("GET /api/v1/sessions/{id}/timeline", h.api(h.apiTimeline))
	mux.HandleFunc("POST /api/v1/sessions", h.api(func(r *http.Request) (proto.Message, *opError) {
		cs := &v1.CreateSession{}
		if err := decode(r, cs); err != nil {
			return nil, err
		}
		return ackOf(h.createSession(cs, clientName(r)))
	}))
	mux.HandleFunc("POST /api/v1/sessions/{id}/messages", h.api(func(r *http.Request) (proto.Message, *opError) {
		m := &v1.SendMessage{}
		if err := decode(r, m); err != nil {
			return nil, err
		}
		m.Session = r.PathValue("id")
		return ackOf(h.sendMessage(m, clientName(r)))
	}))
	mux.HandleFunc("POST /api/v1/sessions/{id}/interrupt", h.api(func(r *http.Request) (proto.Message, *opError) {
		return ackOf(h.interrupt(r.PathValue("id")))
	}))
	mux.HandleFunc("POST /api/v1/sessions/{id}/stop", h.api(func(r *http.Request) (proto.Message, *opError) {
		return ackOf(h.stop(r.PathValue("id")))
	}))
	mux.HandleFunc("POST /api/v1/sessions/{id}/archive", h.api(func(r *http.Request) (proto.Message, *opError) {
		a := &v1.ArchiveSession{}
		if err := decode(r, a); err != nil {
			return nil, err
		}
		return ackOf(h.archive(r.PathValue("id"), a.Archived))
	}))
	mux.HandleFunc("GET /api/v1/sessions/{id}/lineage", h.api(func(r *http.Request) (proto.Message, *opError) {
		id := r.PathValue("id")
		if h.sessions[id] == nil {
			return nil, errNotFound
		}
		events, err := h.store.LineageEvents(id)
		if err != nil {
			return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
		return &v1.LineageEvents{Events: events}, nil
	}))
	mux.HandleFunc("POST /api/v1/sessions/{id}/global", h.api(func(r *http.Request) (proto.Message, *opError) {
		g := &v1.SetGlobal{}
		if err := decode(r, g); err != nil {
			return nil, err
		}
		return ackOf(h.setGlobal(r.PathValue("id"), g.Global, clientName(r)))
	}))
	mux.HandleFunc("POST /api/v1/sessions/{id}/continue", h.api(func(r *http.Request) (proto.Message, *opError) {
		m := &v1.SendMessage{}
		if err := decode(r, m); err != nil {
			return nil, err
		}
		return ackOf(h.continueOnHub(r.PathValue("id"), m.Text, clientName(r)))
	}))
	mux.HandleFunc("POST /api/v1/sessions/{id}/rebuild", h.api(func(r *http.Request) (proto.Message, *opError) {
		return ackOf(h.rebuild(r.PathValue("id")))
	}))
	h.chatRoutes(mux)
	h.updateRoutes(mux)
	h.historyRoutes(mux)
	mux.HandleFunc("POST /api/v1/pairing-codes", h.api(func(r *http.Request) (proto.Message, *opError) {
		code, err := h.newPairingCode()
		if err != nil {
			return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
		return code, nil
	}))
	mux.HandleFunc("POST /api/v1/pair", h.pairHandler)
	mux.HandleFunc("/mcp", h.serveMCP)
	mux.HandleFunc("POST /api/v1/artifacts", func(w http.ResponseWriter, r *http.Request) {
		id, err := h.auth(r, true)
		if err != nil {
			writeError(w, err)
			return
		}
		h.uploadArtifact(w, r, id)
	})
	mux.HandleFunc("GET /api/v1/artifacts", h.api(func(r *http.Request) (proto.Message, *opError) {
		limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
		if limit <= 0 || limit > 500 {
			limit = 200
		}
		list, err := h.store.Artifacts(r.URL.Query().Get("session"), limit)
		if err != nil {
			return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
		return &v1.ArtifactList{Artifacts: hideBackups(r, list)}, nil
	}))
	mux.HandleFunc("GET /api/v1/artifacts/{id}/content", h.artifactContent)
	h.uploadRoutes(mux)
	h.screenRoutes(mux)
	h.modeRoutes(mux)
	mux.HandleFunc("GET /api/v1/clients", h.api(func(r *http.Request) (proto.Message, *opError) { return h.clientList(), nil }))
	h.codebaseRoutes(mux)
	mux.HandleFunc("GET /api/v1/pages", h.api(func(r *http.Request) (proto.Message, *opError) {
		return h.pages(r.URL.Query().Get("session"))
	}))
	// The signature in the path is the credential, as with artifact links.
	mux.HandleFunc("GET /p/{session}/{name}/{exp}/{sig}/{file...}", h.servePage)
	mux.HandleFunc("POST /api/v1/artifacts/{id}/link", h.api(func(r *http.Request) (proto.Message, *opError) {
		secs, _ := strconv.Atoi(r.URL.Query().Get("ttl"))
		return h.artifactLink(r.PathValue("id"), time.Duration(secs)*time.Second)
	}))
	mux.HandleFunc("DELETE /api/v1/artifacts/{id}", h.api(func(r *http.Request) (proto.Message, *opError) {
		return ackOf("", h.deleteArtifact(r.PathValue("id")))
	}))
	mux.HandleFunc("GET /api/v1/workspaces", h.api(func(r *http.Request) (proto.Message, *opError) {
		return h.workspaces(), nil
	}))
	workspaceRoot := func(remove bool) http.HandlerFunc {
		return h.api(func(r *http.Request) (proto.Message, *opError) {
			root := &v1.WorkspaceRoot{}
			if err := decode(r, root); err != nil {
				return nil, err
			}
			return h.setWorkspaceRoot(root, remove)
		})
	}
	mux.HandleFunc("PUT /api/v1/workspaces", workspaceRoot(false))
	mux.HandleFunc("DELETE /api/v1/workspaces", workspaceRoot(true))
	mux.HandleFunc("GET /api/v1/usage", h.api(func(r *http.Request) (proto.Message, *opError) {
		return h.usageSummary(time.Now())
	}))
	mux.HandleFunc("PUT /api/v1/preferences", h.api(func(r *http.Request) (proto.Message, *opError) {
		p := &v1.Preferences{}
		if err := decode(r, p); err != nil {
			return nil, err
		}
		return ackOf("", h.setPreferences(p))
	}))
	// Reading tailscale status takes a moment, so this runs outside the hub lock.
	mux.HandleFunc("GET /api/v1/tailnet", h.authed(func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, h.tailnet(r.Context()))
	}))
	mux.HandleFunc("GET /api/v1/devices", h.api(func(r *http.Request) (proto.Message, *opError) {
		return h.deviceList(), nil
	}))
	mux.HandleFunc("DELETE /api/v1/devices/{id}", h.api(func(r *http.Request) (proto.Message, *opError) {
		_, err := h.revoke(r.PathValue("id"))
		return ackOf("", err)
	}))
	mux.HandleFunc("POST /api/v1/approvals/{id}", h.api(func(r *http.Request) (proto.Message, *opError) {
		d := &v1.ApprovalDecision{}
		if err := decode(r, d); err != nil {
			return nil, err
		}
		d.ApprovalId = r.PathValue("id")
		if d.Decision == v1.Decision_DECISION_UNSPECIFIED {
			return nil, invalid("decision is required")
		}
		return ackOf(h.decide(clientName(r), d))
	}))
}

func (h *Hub) apiTimeline(r *http.Request) (proto.Message, *opError) {
	id := r.PathValue("id")
	if h.sessions[id] == nil {
		return nil, errNotFound
	}
	var after uint64
	if s := r.URL.Query().Get("after"); s != "" {
		v, err := strconv.ParseUint(s, 10, 64)
		if err != nil {
			return nil, invalid("after must be a number")
		}
		after = v
	}
	items, _, err := h.store.ItemsAfter(id, after)
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	latest, err := h.store.LatestSeq(id)
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	sort.Slice(items, func(i, j int) bool { return items[i].Ord < items[j].Ord })
	// Seq is always the session's latest, so a client whose cached seq is
	// higher knows the hub was reset and its cache is stale.
	return &v1.TimelinePage{Session: id, Items: items, Seq: latest}, nil
}

// api wraps a handler with auth, locking and JSON encoding. Errors are
// written as an Error message with the matching status code.
func (h *Hub) api(fn func(*http.Request) (proto.Message, *opError)) http.HandlerFunc {
	return h.authed(func(w http.ResponseWriter, r *http.Request) {
		h.mu.Lock()
		msg, err := fn(r)
		h.mu.Unlock()
		if err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, msg)
	})
}

type identityKey struct{}

// authed lets through requests with the admin token or a client's token,
// with the caller's identity in the request context.
func (h *Hub) authed(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := h.auth(r, false)
		if err != nil {
			writeError(w, err)
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), identityKey{}, id)))
	}
}

// auth identifies a request. Node tokens are for the agent's WebSocket,
// plus the few routes agents call (allowNode).
func (h *Hub) auth(r *http.Request, allowNode bool) (identity, *opError) {
	ip := remoteIP(r)
	if h.limited(ip) {
		return identity{}, errRateLimited
	}
	token, _ := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
	id, ok := h.identifyFrom(token, ip)
	if !ok || id.kind == kindNode && !allowNode {
		h.fail(ip)
		return identity{}, errUnauthorized
	}
	return id, nil
}

func decode(r *http.Request, m proto.Message) *opError {
	body, err := io.ReadAll(io.LimitReader(r.Body, maxBody))
	if err != nil {
		return invalid("could not read body")
	}
	if len(body) == 0 {
		return nil
	}
	if err := jsonIn.Unmarshal(body, m); err != nil {
		return invalid("malformed JSON: " + err.Error())
	}
	return nil
}

func ackOf(session string, err *opError) (proto.Message, *opError) {
	if err != nil {
		return nil, err
	}
	return &v1.Ack{Session: session}, nil
}

func writeJSON(w http.ResponseWriter, status int, m proto.Message) {
	b, err := jsonOut.Marshal(m)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(b)
}

func writeError(w http.ResponseWriter, e *opError) {
	writeJSON(w, e.Status, &v1.Error{Code: e.Code, Message: e.Message})
}

func clientName(r *http.Request) string {
	if n := r.Header.Get("X-Tether-Client"); n != "" {
		return n
	}
	return r.RemoteAddr
}
