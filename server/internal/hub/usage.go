package hub

import (
	"net/http"
	"sort"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

// Token usage per machine and session, read by agents from transcripts.
// Each node uses only its own Claude login; this only reports. See
// docs/plans/plan.md#usage-tracking.

// Claude's usage limits reset over a rolling 5-hour window.
const usageWindow = 5 * time.Hour

// usageSummary totals usage per node for the window, today and the week.
// Caller holds h.mu.
func (h *Hub) usageSummary(now time.Time) (*v1.UsageSummary, *opError) {
	midnight := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	week := now.Add(-7 * 24 * time.Hour).UnixMilli()
	window, err1 := h.store.UsageByNode(now.Add(-usageWindow).UnixMilli())
	today, err2 := h.store.UsageByNode(midnight.UnixMilli())
	weekly, err3 := h.store.UsageByNode(week)
	sessions, err4 := h.store.UsageBySession(week, 50)
	for _, err := range []error{err1, err2, err3, err4} {
		if err != nil {
			return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
	}
	names := map[string]bool{}
	for n := range h.nodes {
		names[n] = true
	}
	for n := range weekly {
		names[n] = true
	}
	out := &v1.UsageSummary{Sessions: sessions}
	for n := range names {
		out.Nodes = append(out.Nodes, &v1.NodeUsage{
			Node: n, Window: orZero(window[n]), Today: orZero(today[n]), Week: orZero(weekly[n]), Plan: h.plans[n],
		})
	}
	sort.Slice(out.Nodes, func(i, j int) bool { return out.Nodes[i].Node < out.Nodes[j].Node })
	return out, nil
}

func orZero(t *v1.UsageTotals) *v1.UsageTotals {
	if t == nil {
		return &v1.UsageTotals{}
	}
	return t
}

// setPlan keeps a node's latest /usage report. Caller holds h.mu.
func (h *Hub) setPlan(node string, p *v1.PlanUsage) {
	p.Node = node
	if prev := h.plans[node]; p.Error == "" && !sameLimits(prev, p) {
		at := p.CheckedMs
		if at == 0 {
			at = time.Now().UnixMilli()
		}
		var samples []store.LimitSample
		for _, l := range p.Limits {
			samples = append(samples, store.LimitSample{Account: node, Span: limitSpan(l.Label), Label: l.Label, Percent: l.Percent, Resets: l.Resets, AtMs: at})
		}
		if err := h.store.AddLimitSamples(samples); err != nil {
			h.log.Warn("keep plan limits", "node", node, "err", err)
		}
	}
	h.plans[node] = p
}

// sameLimits is true when a reading says nothing new, so only changes are kept.
func sameLimits(a, b *v1.PlanUsage) bool {
	if a == nil || len(a.Limits) != len(b.Limits) {
		return false
	}
	for i, l := range a.Limits {
		m := b.Limits[i]
		if l.Label != m.Label || l.Percent != m.Percent || l.Resets != m.Resets {
			return false
		}
	}
	return true
}

// limitSpan names a /usage line's window: "Current session" is the 5-hour
// one, "Current week (all models)" and the per-model weeks are the week.
func limitSpan(label string) string {
	l := strings.ToLower(label)
	switch {
	case strings.Contains(l, "week"):
		return "week"
	case strings.Contains(l, "session") || strings.Contains(l, "5"):
		return "session5h"
	}
	return "other"
}

// recordLimitHit keeps a session stopping at a usage limit. A reset more than
// usageWindow away can only be the week's.
func (h *Hub) recordLimitHit(node, session string, reset, now time.Time) {
	span := "session5h"
	if reset.Sub(now) > usageWindow {
		span = "week"
	}
	if err := h.store.AddLimitEvent(store.LimitEvent{Account: node, Span: span, ResetMs: reset.UnixMilli(), Session: session, AtMs: now.UnixMilli()}); err != nil {
		h.log.Warn("keep limit hit", "node", node, "err", err)
	}
}
