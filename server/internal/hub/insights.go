package hub

import (
	"math"
	"net/http"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

// Insights, the measure layer: counts and distributions from what the hub
// saved, with no model involved. computeInsights is pure so a synthetic
// store with known numbers can pin it down. See docs/plans/prompt-desk.md#insights.

const insightCacheTTL = 2 * time.Minute

type insightCache struct {
	mu   sync.Mutex
	key  int
	at   time.Time
	data *insightInput
}

type insightChat struct {
	ID       string
	Title    string
	Sessions int
	// In the window, in the order they were said, copies from forks dropped.
	Messages []*v1.ChatMessage
}

type insightInput struct {
	NowMs     int64
	SinceMs   int64
	Days      int
	Chats     []insightChat
	Lineage   []*v1.LineageEvent
	Usage     []store.UsageRow
	Tools     []*v1.ToolCard
	Approvals []store.AuditEntry
	Titles    map[string]string
}

type dist struct {
	Count  int   `json:"count"`
	Median int64 `json:"median"`
	P90    int64 `json:"p90"`
	Max    int64 `json:"max"`
	Total  int64 `json:"total"`
}

type labelled struct {
	Label string `json:"label"`
	Count int    `json:"count"`
}

type restartsBack struct {
	Back  int `json:"back"`
	Count int `json:"count"`
}

type sessionTokens struct {
	Session    string `json:"session"`
	Title      string `json:"title"`
	Model      string `json:"model"`
	Messages   int    `json:"messages"`
	Input      int64  `json:"input"`
	Output     int64  `json:"output"`
	CacheWrite int64  `json:"cacheWrite"`
	CacheRead  int64  `json:"cacheRead"`
	Total      int64  `json:"total"`
}

type tokenStats struct {
	Sessions   int   `json:"sessions"`
	Input      int64 `json:"input"`
	Output     int64 `json:"output"`
	CacheWrite int64 `json:"cacheWrite"`
	CacheRead  int64 `json:"cacheRead"`
	// Cache reads as a share of everything sent in (input, cache write, cache read).
	CacheReadShare float64         `json:"cacheReadShare"`
	PerSession     dist            `json:"perSession"`
	Top            []sessionTokens `json:"top"`
}

type modelCost struct {
	Model    string  `json:"model"`
	Messages int     `json:"messages"`
	USD      float64 `json:"usd"`
}

type costEstimate struct {
	Estimate bool        `json:"estimate"`
	USD      float64     `json:"usd"`
	ByModel  []modelCost `json:"byModel"`
	// Messages whose model has no price in the table.
	Unpriced int    `json:"unpriced"`
	Note     string `json:"note"`
}

type toolCount struct {
	Name   string `json:"name"`
	Calls  int    `json:"calls"`
	Errors int    `json:"errors"`
}

type approvalTool struct {
	Tool    string `json:"tool"`
	Allowed int    `json:"allowed"`
	Denied  int    `json:"denied"`
}

type approvalStats struct {
	Allowed int            `json:"allowed"`
	Denied  int            `json:"denied"`
	ByTool  []approvalTool `json:"byTool"`
	// When the first decision in the window was recorded, 0 if none was.
	FirstMs int64 `json:"firstMs"`
}

type phraseCount struct {
	Label   string `json:"label"`
	Rule    string `json:"rule"`
	Prompts int    `json:"prompts"`
	Chats   int    `json:"chats"`
}

type modelUse struct {
	Model    string `json:"model"`
	Messages int    `json:"messages"`
	Tokens   int64  `json:"tokens"`
}

type sampleSize struct {
	Chats    int `json:"chats"`
	Messages int `json:"messages"`
}

type insightStats struct {
	GeneratedMs       int64          `json:"generatedMs"`
	Days              int            `json:"days"`
	SinceMs           int64          `json:"sinceMs"`
	Chats             int            `json:"chats"`
	Messages          int            `json:"messages"`
	Prompts           int            `json:"prompts"`
	MessagesPerChat   dist           `json:"messagesPerChat"`
	PromptsPerChat    dist           `json:"promptsPerChat"`
	PromptLength      dist           `json:"promptLength"`
	PromptLengths     []labelled     `json:"promptLengths"`
	LongAsFile        int            `json:"longAsFile"`
	MultiSessionChats int            `json:"multiSessionChats"`
	Lineage           []labelled     `json:"lineage"`
	RepeatedPrompts   int            `json:"repeatedPrompts"`
	Restarts          int            `json:"restarts"`
	RestartsBack      []restartsBack `json:"restartsBack"`
	Tokens            tokenStats     `json:"tokens"`
	Cost              costEstimate   `json:"cost"`
	ToolCalls         int            `json:"toolCalls"`
	ToolErrors        int            `json:"toolErrors"`
	Tools             []toolCount    `json:"tools"`
	Approvals         approvalStats  `json:"approvals"`
	Phrases           []phraseCount  `json:"phrases"`
	Models            []modelUse     `json:"models"`
	Sample            sampleSize     `json:"sample"`
}

// longFilePhrase is how a long message reaches a session as a file.
const longFilePhrase = "message is long, so it is in the attached file"

// A restart is a prompt this similar to one of the restartWindow before it.
const (
	restartSimilarity = 0.6
	restartWindow     = 8
	restartMinWords   = 3
	topSessions       = 5
	topTools          = 15
)

var promptBuckets = []struct {
	label string
	upTo  int
}{{"under 100", 100}, {"100 to 499", 500}, {"500 to 1,999", 2000}, {"2,000 and more", math.MaxInt}}

// instructionPhrases are rule-like things users say again and again. Each
// carries the rule it would become; the app offers the same ones as starters.
var instructionPhrases = []struct {
	label, rule string
	re          *regexp.Regexp
}{
	{"Don't commit or push", "Do not commit or push unless I ask; commit locally only when asked.",
		regexp.MustCompile(`(?i)\b(don'?t|do not|never|no)\s+(git\s+)?(commit|push)`)},
	{"Read the logs first", "Read the logs before proposing a fix.",
		regexp.MustCompile(`(?i)\b(check|read|look at|see)\s+(the\s+)?(\w+\s+)?logs?\b`)},
	{"Docs with the change", "Update docs/ and the README in the same change as the behaviour.",
		regexp.MustCompile(`(?i)\b(update|keep|change)\b[^.\n]{0,30}\bdocs?\b`)},
	{"Keep replies short", "Keep replies short.",
		regexp.MustCompile(`(?i)\b(keep (it|replies|answers|responses) (short|brief)|short (answer|reply|replies|answers)|be (brief|concise))\b`)},
	{"Read-only on copies", "For a read-only task, work on copies and never change the original.",
		regexp.MustCompile(`(?i)\bread[- ]only\b`)},
	{"Verify before done", "Verify (run the build and tests) before saying it is done.",
		regexp.MustCompile(`(?i)\b(verify|run the tests|test it|make sure it works)\b`)},
	{"Never restart services", "Never restart a running service unless told to.",
		regexp.MustCompile(`(?i)\b(don'?t|do not|never)\s+(re)?start\b`)},
	{"No code comments", "Do not write comments in code except for a non-obvious why.",
		regexp.MustCompile(`(?i)\b(no|don'?t (write|add)|without|remove( the)?)\s+(code\s+)?comments\b`)},
}

// prices are list prices in dollars per million tokens, by model family,
// for an estimate only: plans and discounts are not known to the hub. The
// first matching prefix wins, so the specific ones come first.
var prices = []struct {
	prefix                          string
	input, output, cacheWrite, read float64
}{
	{"claude-fable", 10, 50, 12.5, 0.25},
	{"claude-mythos", 10, 50, 12.5, 0.25},
	{"claude-opus-5-5", 4, 20, 5, 0.20},
	{"claude-opus", 5, 25, 6.25, 0.50},
	{"claude-sonnet-5", 2, 10, 2.5, 0.20},
	{"claude-sonnet", 3, 15, 3.75, 0.30},
	{"claude-haiku-5", 0.10, 0.50, 0.125, 0.01},
	{"claude-haiku", 1, 5, 1.25, 0.10},
}

func priceOf(model string) (in, out, write, read float64, ok bool) {
	m := strings.ToLower(model)
	for _, p := range prices {
		if strings.HasPrefix(m, p.prefix) {
			return p.input, p.output, p.cacheWrite, p.read, true
		}
	}
	return 0, 0, 0, 0, false
}

// distOf is nearest-rank: the median and p90 are values that occur.
func distOf(xs []int64) dist {
	if len(xs) == 0 {
		return dist{}
	}
	s := append([]int64(nil), xs...)
	sort.Slice(s, func(i, j int) bool { return s[i] < s[j] })
	rank := func(p float64) int64 { return s[max(0, int(math.Ceil(p*float64(len(s))))-1)] }
	d := dist{Count: len(s), Median: rank(0.5), P90: rank(0.9), Max: s[len(s)-1]}
	for _, x := range s {
		d.Total += x
	}
	return d
}

func words(s string) []string {
	return strings.FieldsFunc(strings.ToLower(s), func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) })
}

func wordSet(ws []string) map[string]bool {
	out := make(map[string]bool, len(ws))
	for _, w := range ws {
		out[w] = true
	}
	return out
}

// jaccard is the share of words two prompts have in common.
func jaccard(a, b map[string]bool) float64 {
	if len(a) == 0 || len(b) == 0 {
		return 0
	}
	both := 0
	for w := range a {
		if b[w] {
			both++
		}
	}
	return float64(both) / float64(len(a)+len(b)-both)
}

func sortedLabels(m map[string]int) []labelled {
	out := []labelled{}
	for k, v := range m {
		out = append(out, labelled{k, v})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Count != out[j].Count {
			return out[i].Count > out[j].Count
		}
		return out[i].Label < out[j].Label
	})
	return out
}

func computeInsights(in insightInput) insightStats {
	st := insightStats{GeneratedMs: in.NowMs, Days: in.Days, SinceMs: in.SinceMs}
	var perChat, promptsPerChat, lengths []int64
	buckets := make([]int, len(promptBuckets))
	backs := map[int]int{}
	phrasePrompts := make([]int, len(instructionPhrases))
	phraseChats := make([]int, len(instructionPhrases))
	for _, c := range in.Chats {
		if len(c.Messages) == 0 {
			continue
		}
		st.Chats++
		st.Messages += len(c.Messages)
		perChat = append(perChat, int64(len(c.Messages)))
		if c.Sessions > 1 {
			st.MultiSessionChats++
		}
		var prompts []string
		for _, m := range c.Messages {
			if m.Role == "user" {
				prompts = append(prompts, m.Text)
			}
		}
		st.Prompts += len(prompts)
		promptsPerChat = append(promptsPerChat, int64(len(prompts)))
		inChat := make([]bool, len(instructionPhrases))
		var sets []map[string]bool
		seen := map[string]bool{}
		for i, p := range prompts {
			n := len([]rune(p))
			lengths = append(lengths, int64(n))
			for b, pb := range promptBuckets {
				if n < pb.upTo {
					buckets[b]++
					break
				}
			}
			if strings.Contains(p, longFilePhrase) {
				st.LongAsFile++
			}
			for k, ph := range instructionPhrases {
				if ph.re.MatchString(p) {
					phrasePrompts[k]++
					inChat[k] = true
				}
			}
			ws := words(p)
			set := wordSet(ws)
			sets = append(sets, set)
			if len(ws) < restartMinWords {
				continue
			}
			norm := strings.Join(ws, " ")
			if seen[norm] {
				st.RepeatedPrompts++
			}
			seen[norm] = true
			for back := 1; back <= restartWindow && i-back >= 0; back++ {
				if jaccard(set, sets[i-back]) >= restartSimilarity {
					st.Restarts++
					backs[back]++
					break
				}
			}
		}
		for k := range inChat {
			if inChat[k] {
				phraseChats[k]++
			}
		}
	}
	st.MessagesPerChat = distOf(perChat)
	st.PromptsPerChat = distOf(promptsPerChat)
	st.PromptLength = distOf(lengths)
	for b, pb := range promptBuckets {
		st.PromptLengths = append(st.PromptLengths, labelled{pb.label, buckets[b]})
	}
	st.RestartsBack = []restartsBack{}
	for back := 1; back <= restartWindow; back++ {
		if backs[back] > 0 {
			st.RestartsBack = append(st.RestartsBack, restartsBack{back, backs[back]})
		}
	}
	st.Phrases = []phraseCount{}
	for k, ph := range instructionPhrases {
		st.Phrases = append(st.Phrases, phraseCount{Label: ph.label, Rule: ph.rule, Prompts: phrasePrompts[k], Chats: phraseChats[k]})
	}
	sort.SliceStable(st.Phrases, func(i, j int) bool { return st.Phrases[i].Prompts > st.Phrases[j].Prompts })

	kinds := map[string]int{}
	for _, e := range in.Lineage {
		kinds[e.Kind]++
	}
	st.Lineage = sortedLabels(kinds)

	st.Tokens, st.Cost, st.Models = usageInsights(in.Usage, in.Titles)

	byTool := map[string]*toolCount{}
	for _, t := range in.Tools {
		tc := byTool[t.Name]
		if tc == nil {
			tc = &toolCount{Name: t.Name}
			byTool[t.Name] = tc
		}
		tc.Calls++
		st.ToolCalls++
		if t.Status == v1.ToolCard_STATUS_FAILED || t.GetOutput().GetIsError() {
			tc.Errors++
			st.ToolErrors++
		}
	}
	st.Tools = []toolCount{}
	for _, tc := range byTool {
		st.Tools = append(st.Tools, *tc)
	}
	sort.Slice(st.Tools, func(i, j int) bool {
		if st.Tools[i].Calls != st.Tools[j].Calls {
			return st.Tools[i].Calls > st.Tools[j].Calls
		}
		return st.Tools[i].Name < st.Tools[j].Name
	})
	if len(st.Tools) > topTools {
		st.Tools = st.Tools[:topTools]
	}

	st.Approvals = approvalInsights(in.Approvals)
	return st
}

func usageInsights(rows []store.UsageRow, titles map[string]string) (tokenStats, costEstimate, []modelUse) {
	var ts tokenStats
	cost := costEstimate{Estimate: true, ByModel: []modelCost{}, Note: "Estimated from list prices per model family; plans, discounts and the 1M-context and batch rates are not known to the hub."}
	sessions := map[string]*sessionTokens{}
	models := map[string]*modelUse{}
	costs := map[string]*modelCost{}
	for _, u := range rows {
		ts.Input += u.Input
		ts.Output += u.Output
		ts.CacheWrite += u.CacheWrite
		ts.CacheRead += u.CacheRead
		total := u.Input + u.Output + u.CacheWrite + u.CacheRead
		s := sessions[u.Session]
		if s == nil {
			s = &sessionTokens{Session: u.Session, Title: titles[u.Session]}
			sessions[u.Session] = s
		}
		s.Messages++
		s.Input += u.Input
		s.Output += u.Output
		s.CacheWrite += u.CacheWrite
		s.CacheRead += u.CacheRead
		s.Total += total
		if u.Model != "" {
			s.Model = u.Model
		}
		model := firstNonEmpty(u.Model, "unknown")
		mu := models[model]
		if mu == nil {
			mu = &modelUse{Model: model}
			models[model] = mu
		}
		mu.Messages++
		mu.Tokens += total
		in, out, write, read, ok := priceOf(u.Model)
		if !ok {
			cost.Unpriced++
			continue
		}
		usd := (float64(u.Input)*in + float64(u.Output)*out + float64(u.CacheWrite)*write + float64(u.CacheRead)*read) / 1e6
		mc := costs[model]
		if mc == nil {
			mc = &modelCost{Model: model}
			costs[model] = mc
		}
		mc.Messages++
		mc.USD += usd
		cost.USD += usd
	}
	if in := ts.Input + ts.CacheWrite + ts.CacheRead; in > 0 {
		ts.CacheReadShare = math.Round(float64(ts.CacheRead)/float64(in)*1000) / 1000
	}
	ts.Sessions = len(sessions)
	var totals []int64
	all := []sessionTokens{}
	for _, s := range sessions {
		totals = append(totals, s.Total)
		all = append(all, *s)
	}
	ts.PerSession = distOf(totals)
	sort.Slice(all, func(i, j int) bool {
		if all[i].Total != all[j].Total {
			return all[i].Total > all[j].Total
		}
		return all[i].Session < all[j].Session
	})
	ts.Top = all[:min(len(all), topSessions)]

	for _, mc := range costs {
		mc.USD = math.Round(mc.USD*100) / 100
		cost.ByModel = append(cost.ByModel, *mc)
	}
	sort.Slice(cost.ByModel, func(i, j int) bool {
		if cost.ByModel[i].USD != cost.ByModel[j].USD {
			return cost.ByModel[i].USD > cost.ByModel[j].USD
		}
		return cost.ByModel[i].Model < cost.ByModel[j].Model
	})
	cost.USD = math.Round(cost.USD*100) / 100

	uses := []modelUse{}
	for _, m := range models {
		uses = append(uses, *m)
	}
	sort.Slice(uses, func(i, j int) bool {
		if uses[i].Messages != uses[j].Messages {
			return uses[i].Messages > uses[j].Messages
		}
		return uses[i].Model < uses[j].Model
	})
	return ts, cost, uses
}

func approvalInsights(entries []store.AuditEntry) approvalStats {
	a := approvalStats{ByTool: []approvalTool{}}
	byTool := map[string]*approvalTool{}
	for _, e := range entries {
		tool := detailField(e.Detail, "tool")
		t := byTool[tool]
		if t == nil {
			t = &approvalTool{Tool: tool}
			byTool[tool] = t
		}
		switch e.Subject {
		case "allow":
			a.Allowed++
			t.Allowed++
		case "deny":
			a.Denied++
			t.Denied++
		default:
			continue
		}
		if a.FirstMs == 0 || e.AtMs < a.FirstMs {
			a.FirstMs = e.AtMs
		}
	}
	for _, t := range byTool {
		if t.Allowed+t.Denied > 0 {
			a.ByTool = append(a.ByTool, *t)
		}
	}
	sort.Slice(a.ByTool, func(i, j int) bool {
		x, y := a.ByTool[i], a.ByTool[j]
		if x.Allowed+x.Denied != y.Allowed+y.Denied {
			return x.Allowed+x.Denied > y.Allowed+y.Denied
		}
		return x.Tool < y.Tool
	})
	return a
}

// detailField reads key=value out of an audit detail.
func detailField(detail, key string) string {
	for _, f := range strings.Fields(detail) {
		if v, ok := strings.CutPrefix(f, key+"="); ok {
			return v
		}
	}
	return ""
}

// auditApproval records a decision on an approval. Caller holds h.mu.
func (h *Hub) auditApproval(by string, a *v1.ApprovalRequest, d v1.Decision) {
	subject := "allow"
	if d == v1.Decision_DECISION_DENY {
		subject = "deny"
	}
	tool := strings.ReplaceAll(firstNonEmpty(a.ToolName, strings.ToLower(strings.TrimPrefix(a.Kind.String(), "KIND_"))), " ", "_")
	h.audit(firstNonEmpty(by, "unknown"), "approval", subject, "tool="+tool+" session="+a.Session, true)
}

// insightData reads what the stats are computed from, for the last days
// (0 for all of it). A copy is kept for a short while: reading every
// timeline takes a moment.
func (h *Hub) insightData(days int) (*insightInput, error) {
	c := &h.insights
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.data != nil && c.key == days && time.Since(c.at) < insightCacheTTL {
		return c.data, nil
	}
	now := time.Now()
	in := &insightInput{NowMs: now.UnixMilli(), Days: days, Titles: map[string]string{}}
	if days > 0 {
		in.SinceMs = now.Add(-time.Duration(days) * 24 * time.Hour).UnixMilli()
	}
	chats, err := h.store.Chats()
	if err != nil {
		return nil, err
	}
	for _, ch := range chats {
		msgs, err := h.store.ChatMessages(ch.Id)
		if err != nil {
			return nil, err
		}
		in.Chats = append(in.Chats, insightChat{ID: ch.Id, Title: ch.Title, Sessions: len(ch.Sessions), Messages: inWindow(msgs, in.SinceMs)})
	}
	if in.Lineage, err = h.store.LineageSince(in.SinceMs); err != nil {
		return nil, err
	}
	if in.Usage, err = h.store.UsageSince(in.SinceMs); err != nil {
		return nil, err
	}
	if in.Approvals, err = h.store.AuditSince("approval", in.SinceMs); err != nil {
		return nil, err
	}
	sessions, err := h.store.Sessions()
	if err != nil {
		return nil, err
	}
	for _, s := range sessions {
		in.Titles[s.Id] = s.Title
		if s.UpdatedMs != 0 && s.UpdatedMs < in.SinceMs {
			continue
		}
		items, _, err := h.store.ItemsAfter(s.Id, 0)
		if err != nil {
			continue
		}
		for _, it := range items {
			// Items carry no time when the transcript didn't; the session's last change stands in.
			if t := it.GetTool(); t != nil && cmp0(it.TsMs, s.UpdatedMs) >= in.SinceMs {
				in.Tools = append(in.Tools, t)
			}
		}
	}
	c.key, c.at, c.data = days, now, in
	return in, nil
}

func cmp0(a, b int64) int64 {
	if a != 0 {
		return a
	}
	return b
}

// inWindow keeps the messages said since sinceMs, dropping the copies a
// fork makes of what was said before it.
func inWindow(msgs []*v1.ChatMessage, sinceMs int64) []*v1.ChatMessage {
	var out []*v1.ChatMessage
	seen := map[string]bool{}
	for _, m := range msgs {
		if m.TsMs < sinceMs {
			continue
		}
		key := m.Role + "\x00" + strconv.FormatInt(m.TsMs, 10) + "\x00" + m.Text
		if seen[key] {
			continue
		}
		seen[key] = true
		out = append(out, m)
	}
	return out
}

func (h *Hub) insightStats(days int) (insightStats, *insightInput, error) {
	in, err := h.insightData(days)
	if err != nil {
		return insightStats{}, nil, err
	}
	st := computeInsights(*in)
	for _, c := range insightSample(in.Chats, nil) {
		st.Sample.Chats++
		st.Sample.Messages += len(c.Messages)
	}
	return st, in, nil
}

func (h *Hub) insightRoutes(mux *http.ServeMux) {
	// GET /api/v1/insights/stats?days=30 (days=0 for all of history).
	mux.HandleFunc("GET /api/v1/insights/stats", h.authed(func(w http.ResponseWriter, r *http.Request) {
		st, _, err := h.insightStats(atoiOr(r.URL.Query().Get("days"), 30))
		if err != nil {
			writeError(w, internalError(err))
			return
		}
		writePlainJSON(w, st)
	}))
	h.insightReportRoutes(mux)
}
