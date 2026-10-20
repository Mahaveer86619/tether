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
	text, from string
	at         time.Time
}

// noteSent remembers that from sent text to session. Caller holds h.mu.
func (h *Hub) noteSent(session, text, from string) {
	h.sent[session] = append(h.sent[session], sentMsg{text: strings.TrimSpace(text), from: from, at: time.Now()})
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
		u.Source = h.sourceOf(session, u.Text)
	}
}

// sourceOf finds who sent text, dropping notes too old to match. A queued
// placeholder and the message that replaces it both match the same note.
func (h *Hub) sourceOf(session, text string) string {
	text = strings.TrimSpace(text)
	cutoff := time.Now().Add(-sourceTTL)
	kept := h.sent[session][:0]
	from := ""
	for _, m := range h.sent[session] {
		if m.at.Before(cutoff) {
			continue
		}
		kept = append(kept, m)
		// The agent appends the list of attached files to the message.
		if from == "" && (m.text == text || strings.HasPrefix(text, m.text+"\n\nAttached files")) {
			from = m.from
		}
	}
	if len(kept) == 0 {
		delete(h.sent, session)
	} else {
		h.sent[session] = kept
	}
	if from == "" {
		return sourceTerminal
	}
	return from
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
