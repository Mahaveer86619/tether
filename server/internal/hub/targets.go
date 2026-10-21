package hub

import (
	"net/http"
	"sort"
	"strings"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Where a chat runs: picked by the user, matched by the hub from the
// prompt and the folders the user works in, or worked out by Claude in a
// scratch folder when nothing matches. See docs/chats.md#targets.

const (
	scoreName  = 10 // the folder's whole name is in the prompt
	scoreWord  = 3  // one distinctive word of it is
	scorePath  = 1  // a parent folder's name is
	scorePick  = 3  // the least that auto acts on
	maxTargets = 30
)

// Words too common in folder names to say anything on their own.
var genericWords = map[string]bool{
	"app": true, "apps": true, "web": true, "api": true, "src": true, "server": true, "client": true, "test": true, "tests": true,
	"main": true, "the": true, "and": true, "new": true, "old": true, "code": true, "repo": true, "repos": true, "project": true,
	"projects": true, "work": true, "personal": true, "dev": true, "users": true, "home": true, "github": true, "gitlab": true,
	"com": true, "org": true, "www": true, "data": true, "docs": true, "lib": true, "tmp": true, "temp": true, "scratch": true,
}

// targetCandidates lists the folders the user works in, best match for
// prompt first, then most recently used. Caller holds h.mu.
func (h *Hub) targetCandidates(prompt string) []*v1.TargetCandidate {
	byKey := map[string]*v1.TargetCandidate{}
	add := func(node, cwd string, used int64) {
		if cwd == "" || strings.Contains(strings.ReplaceAll(cwd, `\`, "/"), "/.tether/") {
			return
		}
		key := node + "\x00" + normPath(cwd)
		c := byKey[key]
		if c == nil {
			c = &v1.TargetCandidate{Node: node, Cwd: cwd, Label: baseOf(cwd)}
			byKey[key] = c
		}
		c.LastUsedMs = max(c.LastUsedMs, used)
	}
	for _, s := range h.sessions {
		if !s.Scratch && s.Codebase == "" {
			add(s.Node, s.Cwd, s.UpdatedMs)
		}
	}
	if list, err := h.store.Codebases(); err == nil {
		for _, cb := range list {
			add(cb.Node, cb.Path, max(cb.SnapshotMs, cb.CreatedMs))
		}
	} else {
		h.log.Error("list codebases", "err", err)
	}

	words := wordsOf(prompt)
	text := " " + strings.Join(wordList(prompt), " ") + " "
	out := make([]*v1.TargetCandidate, 0, len(byKey))
	for _, c := range byKey {
		c.Online = h.agents[c.Node] != nil
		c.Score, c.Reason = matchScore(c.Cwd, words, text)
		out = append(out, c)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Score != out[j].Score {
			return out[i].Score > out[j].Score
		}
		if out[i].LastUsedMs != out[j].LastUsedMs {
			return out[i].LastUsedMs > out[j].LastUsedMs
		}
		return out[i].Cwd < out[j].Cwd
	})
	return out
}

// matchScore rates how clearly prompt (as words and as space-joined text)
// points at the folder cwd.
func matchScore(cwd string, words map[string]bool, text string) (float64, string) {
	name := baseOf(cwd)
	nameWords := wordList(name)
	if len(nameWords) == 0 {
		return 0, ""
	}
	joined := strings.Join(nameWords, "")
	if strings.Contains(text, " "+strings.Join(nameWords, " ")+" ") && (len(nameWords) > 1 || !genericWords[joined]) || len(joined) >= 4 && words[joined] {
		return scoreName, `matched "` + name + `"`
	}
	var score float64
	var hits []string
	for _, w := range nameWords {
		if len(w) >= 3 && !genericWords[w] && words[w] {
			score += scoreWord
			hits = append(hits, w)
		}
	}
	segs := strings.FieldsFunc(strings.ReplaceAll(cwd, `\`, "/"), func(r rune) bool { return r == '/' })
	for i := 0; i < len(segs)-1; i++ {
		for _, w := range wordList(segs[i]) {
			if len(w) >= 3 && !genericWords[w] && words[w] {
				score += scorePath
			}
		}
	}
	if len(hits) > 0 {
		return score, `matched "` + strings.Join(hits, `", "`) + `"`
	}
	if score > 0 {
		return score, "matched its parent folder"
	}
	return 0, ""
}

// autoPick is the candidate auto mode goes with: a clear, online best match,
// or nil when nothing (or more than one thing) fits.
func autoPick(list []*v1.TargetCandidate) *v1.TargetCandidate {
	var online []*v1.TargetCandidate
	for _, c := range list {
		if c.Online {
			online = append(online, c)
		}
	}
	if len(online) == 0 || online[0].Score < scorePick {
		return nil
	}
	if len(online) > 1 && online[1].Score == online[0].Score {
		return nil
	}
	return online[0]
}

func (h *Hub) targetSuggestions(prompt string) *v1.TargetSuggestions {
	list := h.targetCandidates(prompt)
	out := &v1.TargetSuggestions{Pick: autoPick(list)}
	out.Candidates = list[:min(len(list), maxTargets)]
	return out
}

// resolveTarget turns what the user asked for into where the chat starts.
// Caller holds h.mu.
func (h *Hub) resolveTarget(prompt string, t *v1.ChatTarget) (*v1.ChatTarget, *opError) {
	mode := t.GetMode()
	if mode == "" {
		mode = targetAuto
		if t.GetNode() != "" || t.GetScratch() {
			mode = targetManual
		}
	}
	switch mode {
	case targetManual:
		if t.GetNode() == "" && !t.GetScratch() {
			return nil, invalid("pick a device and folder, or let Tether choose")
		}
		return &v1.ChatTarget{Mode: targetManual, Node: t.GetNode(), Cwd: t.GetCwd(), Scratch: t.GetScratch(), State: targetResolved, Reason: "picked by you"}, nil
	case targetAuto:
		if pick := autoPick(h.targetCandidates(prompt)); pick != nil {
			return &v1.ChatTarget{Mode: targetAuto, Node: pick.Node, Cwd: pick.Cwd, State: targetResolved, Reason: pick.Reason}, nil
		}
		fallthrough
	case targetClaude:
		node := h.hubNode()
		if node == "" {
			return nil, &opError{"node_offline", "the hub's machine has no agent online to work out where this goes; pick a device and folder", http.StatusServiceUnavailable}
		}
		reason := "Claude is working out where this goes"
		if mode == targetAuto {
			reason = "nothing in the message pointed at a folder, so Claude is working it out"
		}
		return &v1.ChatTarget{Mode: targetClaude, Node: node, Scratch: true, State: targetDetecting, Reason: reason}, nil
	}
	return nil, invalid("unknown target mode " + mode)
}

// baseOf is the last folder of a Windows or POSIX path.
func baseOf(p string) string {
	p = strings.TrimRight(p, `/\`)
	if i := strings.LastIndexAny(p, `/\`); i >= 0 {
		return p[i+1:]
	}
	return p
}

// wordList splits text into lowercase words at punctuation and camelCase.
func wordList(s string) []string {
	var out []string
	var cur []rune
	flush := func() {
		if len(cur) > 0 {
			out = append(out, strings.ToLower(string(cur)))
			cur = cur[:0]
		}
	}
	rs := []rune(s)
	for i, r := range rs {
		switch {
		case r >= 'a' && r <= 'z' || r >= '0' && r <= '9':
			cur = append(cur, r)
		case r >= 'A' && r <= 'Z':
			if len(cur) > 0 && (rs[i-1] >= 'a' && rs[i-1] <= 'z' || i+1 < len(rs) && rs[i+1] >= 'a' && rs[i+1] <= 'z' && rs[i-1] >= 'A' && rs[i-1] <= 'Z') {
				flush()
			}
			cur = append(cur, r)
		case r > 127 && (r >= 'À'):
			cur = append(cur, r)
		default:
			flush()
		}
	}
	flush()
	return out
}

func wordsOf(s string) map[string]bool {
	out := map[string]bool{}
	for _, w := range wordList(s) {
		out[w] = true
	}
	// "fk-cn" or "tether_app" typed as one word still matches.
	for _, f := range strings.Fields(s) {
		out[strings.Join(wordList(f), "")] = true
	}
	return out
}
