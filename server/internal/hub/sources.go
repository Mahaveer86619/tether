package hub

import (
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Every user message is stamped with where it came from: the app or tool
// that sent it through the hub, or the session's own terminal. The stamp is
// stored with the message, so history keeps it.

const (
	// How long a sent message waits to show up in the transcript.
	sourceTTL      = 15 * time.Minute
	sourceTerminal = "terminal"
)

type sentMsg struct {
	text, from, clientID string
	at                   time.Time
}

// noteSent remembers that from sent text to session. Caller holds h.mu.
func (h *Hub) noteSent(session, text, from string) { h.noteSentAs(session, text, from, "") }

// noteSentAs also keeps the client's id for the message. Caller holds h.mu.
func (h *Hub) noteSentAs(session, text, from, clientID string) {
	h.sent[session] = append(h.sent[session], sentMsg{text: strings.TrimSpace(text), from: from, clientID: clientID, at: time.Now()})
}

// alreadySent reports whether a message with this client id went to the
// session recently: a retry after a lost answer. Caller holds h.mu.
func (h *Hub) alreadySent(session, clientID string) bool {
	if clientID == "" {
		return false
	}
	cutoff := time.Now().Add(-sourceTTL)
	for _, m := range h.sent[session] {
		if m.clientID == clientID && m.at.After(cutoff) {
			return true
		}
	}
	return false
}

// tagSources stamps user items that have no source yet. Caller holds h.mu.
func (h *Hub) tagSources(session string, items []*v1.TimelineItem) {
	for _, it := range items {
		u := it.GetUser()
		if u == nil || u.Source != "" {
			continue
		}
		if src, ok := h.keptSources[session][it.ItemId]; ok {
			u.Source = src
			continue
		}
		u.Source, u.ClientId = h.sourceOf(session, u.Text)
	}
}

// sameMessage compares a message as sent with how the transcript shows it:
// the agent appends the list of attached files, and Windows adds CRs.
func sameMessage(sent, got string) bool {
	norm := func(s string) string { return strings.TrimSpace(strings.ReplaceAll(s, "\r\n", "\n")) }
	sent, got = norm(sent), norm(got)
	return sent == got || strings.HasPrefix(got, sent+"\n\nAttached files")
}

// sourceOf finds who sent text and the client's id for it, dropping notes
// too old to match. A queued placeholder and the message that replaces it
// both match the same note.
func (h *Hub) sourceOf(session, text string) (string, string) {
	cutoff := time.Now().Add(-sourceTTL)
	kept := h.sent[session][:0]
	from, clientID := "", ""
	for _, m := range h.sent[session] {
		if m.at.Before(cutoff) {
			continue
		}
		kept = append(kept, m)
		if from == "" && sameMessage(m.text, text) {
			from, clientID = m.from, m.clientID
		}
	}
	if len(kept) == 0 {
		delete(h.sent, session)
	} else {
		h.sent[session] = kept
	}
	if from == "" {
		return sourceTerminal, ""
	}
	return from, clientID
}

// dropStaleQueued removes "queued" placeholders whose message has arrived
// for real. The renderer removes them as Claude Code dequeues, but it
// forgets them when the hub restarts or a mirror resumes mid-transcript,
// and the queued and real text can differ slightly. Caller holds h.mu.
func (h *Hub) dropStaleQueued(session string, items []*v1.TimelineItem) []*v1.TimelineItem {
	queued := h.queuedItems[session]
	if queued == nil {
		queued = map[string]string{}
		if stored, _, err := h.store.ItemsAfter(session, 0); err == nil {
			for _, it := range stored {
				if u := it.GetUser(); u != nil && u.Queued {
					queued[it.ItemId] = u.Text
				}
			}
		}
		h.queuedItems[session] = queued
	}
	inBatch := map[string]bool{}
	for _, it := range items {
		inBatch[it.ItemId] = true
		switch u := it.GetUser(); {
		case it.Kind == nil:
			delete(queued, it.ItemId)
		case u != nil && u.Queued:
			queued[it.ItemId] = u.Text
		}
	}
	for _, it := range items {
		u := it.GetUser()
		if u == nil || u.Queued {
			continue
		}
		for id, text := range queued {
			if !inBatch[id] && sameMessage(text, u.Text) {
				items = append(items, &v1.TimelineItem{ItemId: id})
				delete(queued, id)
				break
			}
		}
	}
	return items
}

// keepSources remembers a session's stamps before its timeline is rebuilt
// from the transcript, which has no record of them. Caller holds h.mu.
func (h *Hub) keepSources(session string) {
	items, _, err := h.store.ItemsAfter(session, 0)
	if err != nil {
		h.log.Error("read items", "session", session, "err", err)
		return
	}
	kept := map[string]string{}
	for _, it := range items {
		if src := it.GetUser().GetSource(); src != "" {
			kept[it.ItemId] = src
		}
	}
	h.keptSources[session] = kept
}
