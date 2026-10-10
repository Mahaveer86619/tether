package hub

import (
	"io"
	"net/http"
	"sort"
	"strconv"
	"strings"

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
		return h.welcome(), nil
	}))
	mux.HandleFunc("GET /api/v1/sessions/{id}/timeline", h.api(h.apiTimeline))
	mux.HandleFunc("POST /api/v1/sessions", h.api(func(r *http.Request) (proto.Message, *opError) {
		cs := &v1.CreateSession{}
		if err := decode(r, cs); err != nil {
			return nil, err
		}
		return ackOf(h.createSession(cs))
	}))
	mux.HandleFunc("POST /api/v1/sessions/{id}/messages", h.api(func(r *http.Request) (proto.Message, *opError) {
		m := &v1.SendMessage{}
		if err := decode(r, m); err != nil {
			return nil, err
		}
		m.Session = r.PathValue("id")
		return ackOf(h.sendMessage(m))
	}))
	mux.HandleFunc("POST /api/v1/sessions/{id}/interrupt", h.api(func(r *http.Request) (proto.Message, *opError) {
		return ackOf(h.interrupt(r.PathValue("id")))
	}))
	mux.HandleFunc("POST /api/v1/sessions/{id}/stop", h.api(func(r *http.Request) (proto.Message, *opError) {
		return ackOf(h.stop(r.PathValue("id")))
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
	return func(w http.ResponseWriter, r *http.Request) {
		token, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok || !h.authorized(token) {
			writeError(w, errUnauthorized)
			return
		}
		h.mu.Lock()
		msg, err := fn(r)
		h.mu.Unlock()
		if err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, msg)
	}
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
