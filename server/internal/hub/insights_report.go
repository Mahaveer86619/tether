package hub

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"sort"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/skills"
)

// Insights, the interpret layer: a hub session reads the stats and a
// bounded, masked sample of messages, and saves a report with
// recommendations through save_insight. It runs only when the user asks.

const (
	insightsKey       = "insights"
	insightReportsMax = 20
	sampleChats       = 50
	sampleMessages    = 20
	sampleClip        = 800
	maxRecommended    = 30
)

type recommendation struct {
	Kind  string `json:"kind"`
	Title string `json:"title"`
	Why   string `json:"why"`
	Text  string `json:"text"`
}

type insightReport struct {
	ID              string           `json:"id"`
	Session         string           `json:"session"`
	Days            int              `json:"days"`
	Status          string           `json:"status"`
	StartedMs       int64            `json:"startedMs"`
	SavedMs         int64            `json:"savedMs,omitempty"`
	Sample          sampleSize       `json:"sample"`
	Title           string           `json:"title,omitempty"`
	Summary         string           `json:"summary,omitempty"`
	Recommendations []recommendation `json:"recommendations"`
}

type sampledChat struct {
	Chat     string
	Messages []*v1.ChatMessage
}

// insightSample picks the most recently active chats and their latest
// messages, clipped and passed through mask (nil leaves them as they are,
// for counting).
func insightSample(chats []insightChat, mask func(string) string) []sampledChat {
	var withMsgs []insightChat
	for _, c := range chats {
		if len(c.Messages) > 0 {
			withMsgs = append(withMsgs, c)
		}
	}
	last := func(c insightChat) int64 { return c.Messages[len(c.Messages)-1].TsMs }
	sort.SliceStable(withMsgs, func(i, j int) bool { return last(withMsgs[i]) > last(withMsgs[j]) })
	var out []sampledChat
	for i, c := range withMsgs {
		if i == sampleChats {
			break
		}
		msgs := c.Messages[max(0, len(c.Messages)-sampleMessages):]
		sc := sampledChat{Chat: fmt.Sprintf("chat %d", i+1)}
		for _, m := range msgs {
			text := m.Text
			if mask != nil {
				text = mask(clip(text, sampleClip))
			}
			sc.Messages = append(sc.Messages, &v1.ChatMessage{Role: m.Role, Text: text, TsMs: m.TsMs})
		}
		out = append(out, sc)
	}
	return out
}

var privacyMasks = []struct {
	re *regexp.Regexp
	to string
}{
	{regexp.MustCompile(`[\w.+-]+@[\w-]+(?:\.[\w-]+)+`), "<email>"},
	{regexp.MustCompile(`(?i)\b[a-z][a-z0-9+.-]*://[^\s"'<>)\]]+`), "<url>"},
	{regexp.MustCompile(`(?i)\b[a-z]:[\\/][^\s"'<>|]*`), "<path>"},
	{regexp.MustCompile(`(?:~|\B/)(?:[\w.@-]+/)+[\w.@-]*`), "<path>"},
	{regexp.MustCompile(`(?i)\b[\w-]+(?:\.[\w-]+)*\.(?:ts\.net|local|lan|home|internal|corp|localdomain)\b`), "<host>"},
}

// maskForModel takes out of a message what must not reach a model: secrets
// as the history redaction does, then emails, URLs, paths, host names and
// the user's device names, then what skills.Mask hides (ids, addresses,
// dates, hashes, numbers).
func maskForModel(s string, devices []string) string {
	s, _ = redactString(s)
	for _, m := range privacyMasks {
		s = m.re.ReplaceAllString(s, m.to)
	}
	for _, d := range devices {
		if len(d) >= 3 {
			s = regexp.MustCompile(`(?i)\b`+regexp.QuoteMeta(d)+`\b`).ReplaceAllString(s, "<device>")
		}
	}
	return skills.Mask(s)
}

// deviceNames are the names the hub knows machines by. Caller holds h.mu.
func (h *Hub) deviceNames() []string {
	var out []string
	for n := range h.nodes {
		out = append(out, n)
	}
	sort.Slice(out, func(i, j int) bool { return len(out[i]) > len(out[j]) })
	return out
}

func analysisBrief(reportID string, st insightStats, sample []sampledChat) string {
	var b strings.Builder
	b.WriteString("Before anything else, read Tether's guide: call the tether tool tether_guide with topic \"data\", then with topic \"features\".\n\n")
	b.WriteString("You are analysing how the user works with Tether and Claude Code, from what the hub saved. Read only: change nothing, start no other session.\n\n")
	b.WriteString("Say what is wrong or wasteful (long contexts, restarts, repeated instructions, failing tools, denied approvals, cost) and recommend changes:\n")
	b.WriteString("- rule: a standing instruction Tether adds to every session (text is the rule exactly as Claude should read it, one or two sentences);\n")
	b.WriteString("- skill: a routine worth writing down as a skill (text says what it does and when to use it);\n")
	b.WriteString("- context: a change to how chats are kept or carried (text says the change).\n")
	b.WriteString("Ground every recommendation in a number below or in the sample, and say which in why. Prefer a few strong recommendations to many weak ones.\n\n")
	fmt.Fprintf(&b, "When done, call the tether tool save_insight once with report_id %q, a short title, a summary in Markdown (what you found, with the numbers), and recommendations as a JSON list of {kind: rule|skill|context, title, why, text}. Then stop.\n\n", reportID)
	stats, _ := json.MarshalIndent(st, "", " ")
	window := "all of history"
	if st.Days > 0 {
		window = fmt.Sprintf("the last %d days", st.Days)
	}
	fmt.Fprintf(&b, "## Stats for %s (deterministic, computed by the hub; cost is an estimate from list prices)\n\n```json\n%s\n```\n\n", window, stats)
	n := 0
	for _, c := range sample {
		n += len(c.Messages)
	}
	fmt.Fprintf(&b, "## Sample: %d messages from %d chats\n\n", n, len(sample))
	fmt.Fprintf(&b, "The %d most recently active chats in the window, at most the latest %d messages of each, each clipped to %d characters. "+
		"Masked before you see it: secrets, emails, URLs, paths, host and device names, ids, addresses, dates, times, hashes and numbers are placeholders like <path>, <device> and <n>. "+
		"Tether has no private flag on chats yet, so none was skipped.\n", sampleChats, sampleMessages, sampleClip)
	for _, c := range sample {
		fmt.Fprintf(&b, "\n### %s\n", c.Chat)
		for _, m := range c.Messages {
			fmt.Fprintf(&b, "\n[%s] %s\n", m.Role, m.Text)
		}
	}
	return b.String()
}

func (h *Hub) insightReports() []insightReport {
	var out []insightReport
	if b, err := h.store.Get(insightsKey); err == nil && b != nil {
		_ = json.Unmarshal(b, &out)
	}
	return out
}

// saveInsightReports keeps the newest reports. Caller holds h.mu.
func (h *Hub) saveInsightReports(list []insightReport) error {
	sort.SliceStable(list, func(i, j int) bool { return list[i].StartedMs > list[j].StartedMs })
	if len(list) > insightReportsMax {
		list = list[:insightReportsMax]
	}
	b, err := json.Marshal(list)
	if err != nil {
		return err
	}
	return h.store.Put(insightsKey, b)
}

// analyze starts the analysis session and records a report waiting for it.
func (h *Hub) analyze(days int) (insightReport, *opError) {
	st, in, err := h.insightStats(days)
	if err != nil {
		return insightReport{}, internalError(err)
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	devices := h.deviceNames()
	sample := insightSample(in.Chats, func(s string) string { return maskForModel(s, devices) })
	rep := insightReport{ID: newRuleID(), Days: days, Status: "running", StartedMs: time.Now().UnixMilli(), Sample: st.Sample, Recommendations: []recommendation{}}
	cs := &v1.CreateSession{Prompt: analysisBrief(rep.ID, st, sample), Scratch: true, Name: "Insights: analysis"}
	id, oerr := h.startSession(cs, "Insights", startExtra{})
	if oerr != nil {
		return insightReport{}, oerr
	}
	rep.Session = id
	if err := h.saveInsightReports(append(h.insightReports(), rep)); err != nil {
		return insightReport{}, internalError(err)
	}
	return rep, nil
}

func (h *Hub) insightReportRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/insights", h.authed(func(w http.ResponseWriter, r *http.Request) {
		h.mu.Lock()
		list := h.insightReports()
		h.mu.Unlock()
		if list == nil {
			list = []insightReport{}
		}
		writePlainJSON(w, map[string]any{"reports": list})
	}))
	// POST /api/v1/insights/analyze {"days": 30}
	mux.HandleFunc("POST /api/v1/insights/analyze", h.authed(func(w http.ResponseWriter, r *http.Request) {
		body := struct {
			Days *int `json:"days"`
		}{}
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBody)).Decode(&body); err != nil && err.Error() != "EOF" {
			writeError(w, invalid("send {\"days\": n}"))
			return
		}
		days := 30
		if body.Days != nil && *body.Days >= 0 {
			days = *body.Days
		}
		rep, err := h.analyze(days)
		if err != nil {
			writeError(w, err)
			return
		}
		id, _ := r.Context().Value(identityKey{}).(identity)
		h.mu.Lock()
		h.audit(actorOf(id), "insights", "analyze", fmt.Sprintf("report=%s chats=%d messages=%d", rep.ID, rep.Sample.Chats, rep.Sample.Messages), true)
		h.mu.Unlock()
		writePlainJSON(w, rep)
	}))
}

var recommendationKinds = map[string]bool{"rule": true, "skill": true, "context": true}

// recommendationsOf reads the recommendations argument, a list of objects or
// the same list as a JSON string.
func recommendationsOf(v any) ([]recommendation, error) {
	var raw []byte
	switch x := v.(type) {
	case nil:
		return []recommendation{}, nil
	case string:
		raw = []byte(x)
	default:
		raw, _ = json.Marshal(x)
	}
	var list []recommendation
	if err := json.Unmarshal(raw, &list); err != nil {
		return nil, errors.New("recommendations is a list of {kind, title, why, text}")
	}
	if len(list) > maxRecommended {
		return nil, fmt.Errorf("at most %d recommendations; keep the strongest", maxRecommended)
	}
	for i := range list {
		r := &list[i]
		r.Kind = strings.ToLower(strings.TrimSpace(r.Kind))
		if !recommendationKinds[r.Kind] {
			return nil, fmt.Errorf("recommendation %d: kind is rule, skill or context", i+1)
		}
		if strings.TrimSpace(r.Title) == "" || strings.TrimSpace(r.Text) == "" {
			return nil, fmt.Errorf("recommendation %d needs a title and a text", i+1)
		}
		if r.Kind == "rule" && len(r.Text) > maxRuleText {
			return nil, fmt.Errorf("recommendation %d: a rule is at most %d characters", i+1, maxRuleText)
		}
	}
	return list, nil
}

func (h *Hub) mcpSaveInsight(args map[string]any) (string, error) {
	recs, err := recommendationsOf(args["recommendations"])
	if err != nil {
		return "", err
	}
	summary := strings.TrimSpace(str(args, "summary"))
	if summary == "" {
		return "", errors.New("summary is empty")
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	list := h.insightReports()
	id := str(args, "report_id")
	i := -1
	for k := range list {
		if list[k].ID == id {
			i = k
		}
	}
	now := time.Now().UnixMilli()
	if i < 0 {
		list = append(list, insightReport{ID: newRuleID(), StartedMs: now})
		i = len(list) - 1
	}
	r := &list[i]
	r.Status, r.SavedMs = "saved", now
	r.Title = firstNonEmpty(strings.TrimSpace(str(args, "title")), "Insights")
	r.Summary, r.Recommendations = summary, recs
	saved := r.ID
	if err := h.saveInsightReports(list); err != nil {
		return "", err
	}
	return fmt.Sprintf("Saved report %s with %d recommendations. The user sees it on the Insights page and decides on each; nothing is applied for them.", saved, len(recs)), nil
}

var saveInsightSchema = map[string]any{
	"type":     "object",
	"required": []string{"summary", "recommendations"},
	"properties": map[string]any{
		"report_id": map[string]any{"type": "string", "description": "the report id from your instructions"},
		"title":     map[string]any{"type": "string", "description": "a short title for the report"},
		"summary":   map[string]any{"type": "string", "description": "what you found, in Markdown, with the numbers"},
		"recommendations": map[string]any{
			"type":        "array",
			"description": "what to change, strongest first",
			"items": map[string]any{
				"type":     "object",
				"required": []string{"kind", "title", "text"},
				"properties": map[string]any{
					"kind":  map[string]any{"type": "string", "enum": []string{"rule", "skill", "context"}},
					"title": map[string]any{"type": "string"},
					"why":   map[string]any{"type": "string", "description": "the number or the sample it rests on"},
					"text":  map[string]any{"type": "string", "description": "the rule as Claude should read it, what the skill does, or the context change"},
				},
			},
		},
	},
}

// draftSkillIdea starts a session that writes a skill from a recommendation
// rather than from a routine found in the history.
func (h *Hub) draftSkillIdea(title, idea string) (string, *opError) {
	var b strings.Builder
	b.WriteString("Write a Tether skill the user asked for from an Insights recommendation.\n\n")
	fmt.Fprintf(&b, "Title: %s\n\nWhat it is for: %s\n\n", oneLine(title), strings.TrimSpace(idea))
	b.WriteString("First read Tether's guide (tether tool tether_guide, topic data) and look in what the hub saved for times the user did this, so the steps are the ones that worked. ")
	b.WriteString("Write it as a SKILL.md: front matter with name (lower case, dashes, at most 40 characters) and description (when to use it, in the user's words), then numbered steps, each marked Read-only or Changes things; a step that changes something says to confirm with the user first. No secrets, addresses or personal paths. ")
	b.WriteString("Save it with the tether tool propose_skill (skill_md, mutating, source), then stop; the user reviews it in the Tether app.")
	h.mu.Lock()
	defer h.mu.Unlock()
	cs := &v1.CreateSession{Prompt: b.String(), Scratch: true, Name: "Skill: " + clip(title, 50)}
	return h.startSession(cs, "Insights", startExtra{})
}

func oneLine(s string) string { return strings.Join(strings.Fields(s), " ") }
