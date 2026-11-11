package hub

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

// Notifications: what the owner is told about when they are not looking at
// the app. A turn that finished, something that needs approval, a failure.
//
// A phone with the app closed cannot hold the app's own connection, so it
// polls a small, separate surface: /n/poll, which a notification token (and
// nothing else) opens. That surface is also what the notification tunnel
// exposes to the internet, so a stolen tunnel address or token reveals
// notifications and nothing more. See docs/plans/notifications.md.

const (
	notifyKeep     = 300
	notifyWaitMax  = 30 * time.Second
	notifyBodyMax  = 140
	notifyTokenKey = "notify_tokens"
)

// notifyWake is closed, and replaced, whenever a notification is added, so
// every waiting poll looks again. Caller holds h.mu.
func (h *Hub) notifyWakeLocked() {
	close(h.notifyCh)
	h.notifyCh = make(chan struct{})
}

// notify records a notification and wakes the pollers. Caller holds h.mu.
func (h *Hub) notify(kind, title, body, chat, session string) {
	body = clip(strings.Join(strings.Fields(body), " "), notifyBodyMax)
	id, err := h.store.AddNotification(store.Notification{AtMs: time.Now().UnixMilli(), Kind: kind, Title: clip(title, 100), Body: body, Chat: chat, Session: session}, notifyKeep)
	if err != nil {
		h.log.Error("store notification", "err", err)
		return
	}
	_ = id
	h.notifyWakeLocked()
}

// notifyTurnEnded tells the owner a session finished its turn, with the last
// thing it said. A task session of a chat stays quiet: its lead reports it,
// and the lead's own turn is what finishes the conversation. Caller holds h.mu.
func (h *Hub) notifyTurnEnded(session string) {
	s := h.sessions[session]
	if s == nil || s.Archived {
		return
	}
	c := h.chats[h.chatOf[session]]
	if c != nil && h.workerOf(c, session) {
		return
	}
	title, chat, body := s.Title, "", s.LastPrompt
	if title == "" {
		title = "A session"
	}
	if c != nil {
		title, chat = firstNonEmpty(c.Title, title), c.Id
		if last := h.lastAssistantText(c.Id, session); last != "" {
			body = last
		}
	}
	kind := "finished"
	if s.State == v1.SessionState_SESSION_STATE_ERROR {
		kind, title = "failed", "Failed: "+title
		body = firstNonEmpty(s.Error, body)
	}
	h.notify(kind, title, body, chat, session)
}

// notifyApproval tells the owner Claude is waiting on them. Caller holds h.mu.
func (h *Hub) notifyApproval(a *v1.ApprovalRequest) {
	title := "Claude needs your approval"
	switch {
	case a.Kind == v1.ApprovalRequest_KIND_FOLDER_TRUST:
		title = "Claude asks to trust a folder"
	case a.ToolName == "AskUserQuestion":
		title = "Claude has a question"
	case a.ToolName != "":
		title = "Allow " + a.ToolName + "?"
	}
	body, chat := "", ""
	if s := h.sessions[a.Session]; s != nil {
		body = firstNonEmpty(s.Title, s.LastPrompt)
		if c := h.chats[h.chatOf[a.Session]]; c != nil {
			chat = c.Id
		}
	}
	h.notify("approval", title, body, chat, a.Session)
}

// ---- notification tokens ----

func (h *Hub) notifyTokens() map[string]string {
	m := map[string]string{}
	if b, err := h.store.Get(notifyTokenKey); err == nil && b != nil {
		_ = json.Unmarshal(b, &m)
	}
	return m
}

func (h *Hub) saveNotifyTokens(m map[string]string) {
	if b, err := json.Marshal(m); err == nil {
		if err := h.store.Put(notifyTokenKey, b); err != nil {
			h.log.Error("store notification tokens", "err", err)
		}
	}
}

// newNotifyToken makes a token for who, replacing any it had. The token can
// read notifications and do nothing else. Caller holds h.mu.
func (h *Hub) newNotifyToken(who string) string {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	token := hex.EncodeToString(b)
	tokens := h.notifyTokens()
	for hash, w := range tokens {
		if w == who {
			delete(tokens, hash)
		}
	}
	tokens[hashToken(token)] = who
	h.saveNotifyTokens(tokens)
	return token
}

// dropNotifyTokens forgets a device's notification token. Caller holds h.mu.
func (h *Hub) dropNotifyTokens(who string) {
	tokens := h.notifyTokens()
	for hash, w := range tokens {
		if w == who {
			delete(tokens, hash)
		}
	}
	h.saveNotifyTokens(tokens)
}

func (h *Hub) notifyTokenOK(token string) bool {
	if token == "" {
		return false
	}
	want := hashToken(token)
	h.mu.Lock()
	defer h.mu.Unlock()
	for hash := range h.notifyTokens() {
		if subtle.ConstantTimeCompare([]byte(hash), []byte(want)) == 1 {
			return true
		}
	}
	return false
}

// ---- the surfaces ----

// notifyRoutes are the authenticated ones, for the app: list, send a test,
// and get a notification token.
func (h *Hub) notifyRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/notifications", h.authed(func(w http.ResponseWriter, r *http.Request) {
		after, _ := strconv.ParseInt(r.URL.Query().Get("since"), 10, 64)
		h.mu.Lock()
		list, err := h.store.NotificationsAfter(after, 100)
		h.mu.Unlock()
		if err != nil {
			writeError(w, internalError(err))
			return
		}
		writePlainJSON(w, list)
	}))
	mux.HandleFunc("POST /api/v1/notifications/test", h.authed(func(w http.ResponseWriter, r *http.Request) {
		h.mu.Lock()
		h.notify("test", "Tether can reach you", "This is a test notification.", "", "")
		h.mu.Unlock()
		writePlainJSON(w, map[string]bool{"sent": true})
	}))
	mux.HandleFunc("POST /api/v1/notify-token", h.authed(func(w http.ResponseWriter, r *http.Request) {
		id, _ := r.Context().Value(identityKey{}).(identity)
		// A device paired with its own token is named by it; anything else (the
		// admin token, a trusted tailnet) says which install it is, so two of
		// them do not take each other's token.
		var body struct {
			Label string `json:"label"`
		}
		_ = json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<10)).Decode(&body)
		who := firstNonEmpty(id.deviceID(), "client:"+actorOf(id))
		if id.deviceID() == "" && body.Label != "" {
			who = "install:" + clip(body.Label, 64)
		}
		h.mu.Lock()
		token := h.newNotifyToken(who)
		url := h.notifyURL
		h.mu.Unlock()
		writePlainJSON(w, map[string]string{"token": token, "tunnel": url})
	}))
}

// scopedHandler serves only what a notification token opens. public is the
// copy behind the tunnel, which leaves out the notification text unless the
// owner turned that on: the tunnel's operator can read what passes through.
func (h *Hub) scopedHandler(public bool) http.Handler {
	mux := http.NewServeMux()
	h.scopedRoutes(mux, public)
	return mux
}

func (h *Hub) scopedRoutes(mux *http.ServeMux, public bool) {
	mux.HandleFunc("GET /n/ping", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"app":"tether-hub"}`))
	})
	mux.HandleFunc("GET /n/poll", func(w http.ResponseWriter, r *http.Request) { h.poll(w, r, public) })
}

// poll answers GET /n/poll?since=<id>&wait=<seconds> for a notification
// token: what is newer than since, waiting up to wait seconds when nothing
// is. With no since it only says where the log stands, so a new install
// does not replay old news.
func (h *Hub) poll(w http.ResponseWriter, r *http.Request, public bool) {
	ip := remoteIP(r)
	if public {
		// Behind the tunnel every caller comes from the tunnel's own address;
		// the token is the thing to guard, so limit by it below.
		ip = "tunnel"
	}
	if h.limited(ip) {
		writeError(w, errRateLimited)
		return
	}
	token, _ := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
	if !h.notifyTokenOK(token) {
		h.fail(ip)
		writeError(w, errUnauthorized)
		return
	}
	q := r.URL.Query()
	since, hasSince := int64(0), q.Get("since") != ""
	since, _ = strconv.ParseInt(q.Get("since"), 10, 64)
	wait := notifyWaitMax
	if s, err := strconv.Atoi(q.Get("wait")); err == nil && s >= 0 && time.Duration(s)*time.Second < wait {
		wait = time.Duration(s) * time.Second
	}
	if !hasSince {
		h.mu.Lock()
		last, err := h.store.LastNotificationID()
		h.mu.Unlock()
		if err != nil {
			writeError(w, internalError(err))
			return
		}
		writePlainJSON(w, pollResult{Items: []store.Notification{}, Last: last, Hub: h.cfg.Version})
		return
	}
	deadline := time.NewTimer(wait)
	defer deadline.Stop()
	for {
		h.mu.Lock()
		list, err := h.store.NotificationsAfter(since, 50)
		wake := h.notifyCh
		h.mu.Unlock()
		if err != nil {
			writeError(w, internalError(err))
			return
		}
		if len(list) > 0 {
			last := list[len(list)-1].ID
			if public && !h.cfg.NotifyBodiesOnTunnel {
				for i := range list {
					list[i].Body = ""
				}
			}
			writePlainJSON(w, pollResult{Items: list, Last: last, Hub: h.cfg.Version})
			return
		}
		select {
		case <-wake:
		case <-deadline.C:
			writePlainJSON(w, pollResult{Items: []store.Notification{}, Last: since, Hub: h.cfg.Version})
			return
		case <-r.Context().Done():
			return
		}
	}
}

type pollResult struct {
	Items []store.Notification `json:"items"`
	Last  int64                `json:"last"`
	Hub   string               `json:"hub"`
}
