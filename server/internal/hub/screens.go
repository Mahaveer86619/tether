package hub

import (
	"net/http"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// A session's terminal screen and key presses, relayed to its node: the way
// out of a dialog Tether can't parse. See docs/hosting.md#dialogs-on-screen.

const screenWait = 4 * time.Second

func (h *Hub) screenRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v1/sessions/{id}/keys", h.api(func(r *http.Request) (proto.Message, *opError) {
		k := &v1.SendKeys{}
		if err := decode(r, k); err != nil {
			return nil, err
		}
		k.Session = r.PathValue("id")
		return ackOf(h.sendKeys(k))
	}))
	mux.HandleFunc("GET /api/v1/sessions/{id}/screen", h.authed(func(w http.ResponseWriter, r *http.Request) {
		snap, err := h.screen(r.PathValue("id"))
		if err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, snap)
	}))
}

// sendKeys asks the node to press keys. Caller holds h.mu.
func (h *Hub) sendKeys(k *v1.SendKeys) (string, *opError) {
	info, agent, err := h.target(k.Session)
	if err != nil {
		return "", err
	}
	if info.Host == v1.SessionHost_SESSION_HOST_HEADLESS {
		return "", &opError{"unsupported", "a headless run has no terminal to press keys in", http.StatusBadRequest}
	}
	if len(k.Keys) == 0 && k.Text == "" {
		return "", invalid("no keys to press")
	}
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Keys{Keys: proto.Clone(k).(*v1.SendKeys)}}))
	return info.Id, nil
}

// screen asks the node for a fresh capture and waits a little for it,
// falling back to the last one seen.
func (h *Hub) screen(session string) (*v1.ScreenSnapshot, *opError) {
	h.mu.Lock()
	info, agent, err := h.target(session)
	if err != nil {
		h.mu.Unlock()
		return nil, err
	}
	wait := make(chan *v1.ScreenSnapshot, 1)
	h.screenWaiters[info.Id] = append(h.screenWaiters[info.Id], wait)
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Capture{Capture: &v1.AgentCommand_CaptureScreen{Session: info.Id}}}))
	h.mu.Unlock()

	select {
	case snap := <-wait:
		return snap, nil
	case <-time.After(screenWait):
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if last := h.screens[info.Id]; last != nil {
		return proto.Clone(last).(*v1.ScreenSnapshot), nil
	}
	return nil, &opError{"timeout", "the node didn't send the screen; it may be an older agent", http.StatusGatewayTimeout}
}

// noteScreen keeps a snapshot from a node and passes it on. Caller holds h.mu.
func (h *Hub) noteScreen(node string, snap *v1.ScreenSnapshot) {
	info := h.sessions[snap.Session]
	if info == nil || info.Node != node {
		return
	}
	h.screens[snap.Session] = snap
	for _, w := range h.screenWaiters[snap.Session] {
		w <- proto.Clone(snap).(*v1.ScreenSnapshot)
	}
	delete(h.screenWaiters, snap.Session)
	for c := range h.subs[snap.Session] {
		c.conn.Send(&v1.Frame{Body: &v1.Frame_ScreenSnapshot{ScreenSnapshot: proto.Clone(snap).(*v1.ScreenSnapshot)}})
	}
}
