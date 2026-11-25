package hub

import (
	"context"
	"encoding/json"
	"path"
	"regexp"
	"strconv"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// A task that stops at Claude's usage limit has not finished. The hub notes
// when the limit resets, shows the task as waiting, and tells the session to
// carry on once it has. See docs/architecture/chats.md#tasks-and-the-usage-limit.

const (
	limitWaitsKey   = "limit_waits"
	limitWaitEvery  = 30 * time.Second
	limitResetSlack = 2 * time.Minute
	// A limit message is the whole of the last reply; a long reply that only
	// mentions limits is an ordinary one.
	limitReplyMax = 500
)

type limitWait struct {
	Session  string `json:"session"`
	Chat     string `json:"chat"`
	ResumeMs int64  `json:"resumeMs"`
	Item     string `json:"item"`
}

var (
	limitWords  = regexp.MustCompile(`(?i)(usage|session|5-hour|five-hour|weekly|opus|sonnet)\s+limit|hit your limit|limit reached`)
	limitEpoch  = regexp.MustCompile(`(?i)limit reached\|(\d{9,13})`)
	limitResets = regexp.MustCompile(`(?i)resets?\s+(?:at\s+)?(?:([A-Za-z]{3,9})\s+(\d{1,2}),?\s+)?(\d{1,2})(?::(\d{2}))?\s*([ap]m)(?:\s*\(([^)]+)\))?`)
	months      = map[string]time.Month{"jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12}
)

// parseLimitReset says when the limit a message talks about resets, if it is a
// limit message at all. It reads "limit reached|<unix time>" and "resets
// 3pm (Asia/Kolkata)" or "resets Oct 18, 7:29pm"; with no zone named, the hub's.
func parseLimitReset(text string, now time.Time) (time.Time, bool) {
	if !limitWords.MatchString(text) {
		return time.Time{}, false
	}
	if m := limitEpoch.FindStringSubmatch(text); m != nil {
		n, _ := strconv.ParseInt(m[1], 10, 64)
		if n > 1e12 {
			n /= 1000
		}
		return time.Unix(n, 0), true
	}
	m := limitResets.FindStringSubmatch(text)
	if m == nil {
		return time.Time{}, false
	}
	loc := now.Location()
	if m[6] != "" {
		if l, err := time.LoadLocation(strings.TrimSpace(m[6])); err == nil {
			loc = l
		}
	}
	hour, _ := strconv.Atoi(m[3])
	min, _ := strconv.Atoi(m[4])
	if hour < 1 || hour > 12 {
		return time.Time{}, false
	}
	hour %= 12
	if strings.EqualFold(m[5], "pm") {
		hour += 12
	}
	local := now.In(loc)
	at := time.Date(local.Year(), local.Month(), local.Day(), hour, min, 0, 0, loc)
	if m[1] != "" {
		mon, ok := months[strings.ToLower(m[1])[:3]]
		if !ok {
			return time.Time{}, false
		}
		day, _ := strconv.Atoi(m[2])
		at = time.Date(local.Year(), mon, day, hour, min, 0, 0, loc)
		if at.Before(now.Add(-24 * time.Hour)) {
			at = at.AddDate(1, 0, 0)
		}
		return at, true
	}
	if !at.After(now) {
		at = at.AddDate(0, 0, 1)
	}
	return at, true
}

func (h *Hub) limitWaits() []limitWait {
	var out []limitWait
	if b, err := h.store.Get(limitWaitsKey); err == nil && b != nil {
		_ = json.Unmarshal(b, &out)
	}
	return out
}

func (h *Hub) saveLimitWaits(list []limitWait) {
	b, _ := json.Marshal(list)
	if err := h.store.Put(limitWaitsKey, b); err != nil {
		h.log.Warn("limit waits", "err", err)
	}
}

// limitHit is when the limit a task ended on resets, or false if it ended on
// anything else. Caller holds h.mu.
func (h *Hub) limitHit(task string, s *v1.SessionInfo, now time.Time) (time.Time, bool) {
	text := s.Error
	if blocks, _ := h.lastReply(task); len(blocks) > 0 {
		if reply := blocksText(blocks); len(reply) <= limitReplyMax {
			text += "\n" + reply
		}
	}
	return parseLimitReset(text, now)
}

// waitForLimit shows a task that hit the limit as waiting, and keeps it to
// continue at the reset. Caller holds h.mu.
func (h *Hub) waitForLimit(c *v1.Chat, task string, rep *v1.TaskReport, item string, reset time.Time) {
	resume := reset.Add(limitResetSlack)
	rep.Waiting, rep.ResumeMs, rep.Failed = true, resume.UnixMilli(), false
	rep.Detail = "Stopped at the usage limit. It carries on by itself after " + resume.Format("3:04 pm") + "."
	list := h.limitWaits()
	kept := list[:0]
	for _, w := range list {
		if w.Session != task {
			kept = append(kept, w)
		}
	}
	h.saveLimitWaits(append(kept, limitWait{Session: task, Chat: c.Id, ResumeMs: resume.UnixMilli(), Item: item}))
}

// resumeLimitWaits carries on every task whose limit has reset. Caller holds h.mu.
func (h *Hub) resumeLimitWaits(now time.Time) {
	list := h.limitWaits()
	if len(list) == 0 {
		return
	}
	var pending []limitWait
	for _, w := range list {
		if w.ResumeMs > now.UnixMilli() {
			pending = append(pending, w)
			continue
		}
		s, c := h.sessions[w.Session], h.chats[w.Chat]
		if s == nil || c == nil {
			continue
		}
		if _, err := h.sendMessage(&v1.SendMessage{Session: w.Session, Text: "The usage limit has reset. Carry on with the task where you left off."}, "limit-wait"); err != nil {
			h.log.Warn("limit resume", "session", w.Session, "err", err.Message)
			if now.UnixMilli()-w.ResumeMs < int64(time.Hour/time.Millisecond) {
				pending = append(pending, w)
			}
			continue
		}
		h.markResumed(c, s, w)
	}
	h.saveLimitWaits(pending)
}

// markResumed rewrites the waiting card in the chat as one that has carried on.
func (h *Hub) markResumed(c *v1.Chat, s *v1.SessionInfo, w limitWait) {
	if w.Item == "" || c.ActiveSession == "" {
		return
	}
	folder := ""
	if s.Cwd != "" {
		folder = path.Base(strings.ReplaceAll(s.Cwd, `\`, "/"))
	}
	rep := &v1.TaskReport{
		Title: clip(firstNonEmpty(s.Title, "a task"), 120), Node: s.Node, Folder: folder, Session: s.Id,
		Detail: "The limit reset and the task carried on.",
	}
	h.commit(c.ActiveSession, []*v1.TimelineItem{{ItemId: w.Item, TsMs: time.Now().UnixMilli(), Kind: &v1.TimelineItem_TaskReport{TaskReport: rep}}})
}

func (h *Hub) limitWaitLoop(ctx context.Context) {
	t := time.NewTicker(limitWaitEvery)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-t.C:
			h.mu.Lock()
			h.resumeLimitWaits(now)
			h.mu.Unlock()
		}
	}
}
