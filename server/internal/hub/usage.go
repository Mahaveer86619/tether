package hub

import (
	"net/http"
	"sort"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Token usage per machine and session, read by agents from transcripts.
// Each node uses only its own Claude login; this only reports. See
// docs/plan.md#usage-tracking.

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
	h.plans[node] = p
}
