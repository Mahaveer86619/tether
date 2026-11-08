package skills

import (
	"hash/fnv"
	"math"
	"sort"
	"strings"
	"unicode"
)

// Dim is the size of the hashed word vector.
const Dim = 512

// Fingerprint is what two tasks are compared by: the words of the request,
// the steps taken, and where it ran.
type Fingerprint struct {
	// Words is a hashed bag of the request's words and word pairs, scaled to
	// length 1, so the dot product of two is their cosine similarity. It is the
	// light local embedder from docs/plans/plan.md: no model, nothing leaves the hub.
	Words [Dim]float32
	// Steps are the distinct step keys, sorted.
	Steps     []string
	Node, Cwd string
}

// FingerprintOf summarises a task.
func FingerprintOf(t Task) Fingerprint {
	f := Fingerprint{Node: t.Node, Cwd: t.Cwd}
	words := tokens(Mask(t.Request))
	add := func(s string) {
		h := fnv.New64a()
		h.Write([]byte(s))
		sum := h.Sum64()
		sign := float32(1)
		if sum>>63 == 1 {
			sign = -1
		}
		f.Words[sum%Dim] += sign
	}
	for i, w := range words {
		add(w)
		if i > 0 {
			add(words[i-1] + " " + w)
		}
	}
	var norm float64
	for _, v := range f.Words {
		norm += float64(v) * float64(v)
	}
	if norm > 0 {
		inv := float32(1 / math.Sqrt(norm))
		for i := range f.Words {
			f.Words[i] *= inv
		}
	}
	seen := map[string]bool{}
	for _, s := range t.Steps {
		if s.Key != "" && !seen[s.Key] {
			seen[s.Key] = true
			f.Steps = append(f.Steps, s.Key)
		}
	}
	sort.Strings(f.Steps)
	return f
}

// Similarity is 0 to 1, on the unweighted steps. See related.
func Similarity(a, b Fingerprint) float64 { return related(a, b, nil) }

// minWords is the least the words of two requests must have in common for
// them to be the same routine, whatever else is alike: "grep" and "sed" turn
// up in everything. What was asked decides; the steps only add to it, because
// the same question is answered by different commands on different days.
const minWords = 0.3

// stepBonus is how much of the score the steps can add.
const stepBonus = 0.25

// related is how alike two tasks are. The words of the request must overlap
// (the cosine of the two word vectors, at least minWords); when both used
// tools, steps they share add up to stepBonus, each counted by how rare it is
// across all tasks (w; nil counts every step the same), so grep or cat add
// little.
func related(a, b Fingerprint, w map[string]float64) float64 {
	var dot float64
	for i := range a.Words {
		dot += float64(a.Words[i]) * float64(b.Words[i])
	}
	if dot < minWords {
		return 0
	}
	if len(a.Steps) == 0 || len(b.Steps) == 0 {
		return dot
	}
	return math.Min(1, dot+stepBonus*weightedJaccard(a.Steps, b.Steps, w))
}

func weightedJaccard(a, b []string, w map[string]float64) float64 {
	in := map[string]bool{}
	for _, s := range a {
		in[s] = true
	}
	var both, all float64
	seen := map[string]bool{}
	for _, s := range b {
		seen[s] = true
		if in[s] {
			both += weight(w, s)
		}
	}
	for s := range in {
		all += weight(w, s)
	}
	for s := range seen {
		if !in[s] {
			all += weight(w, s)
		}
	}
	if all == 0 {
		return 0
	}
	return both / all
}

func weight(w map[string]float64, key string) float64 {
	if v, ok := w[key]; ok {
		return v
	}
	return 1
}

// stepWeights gives each step key a weight that falls as more tasks use it:
// ln(tasks / tasks using it), never below 0.05.
func stepWeights(tasks []Task) map[string]float64 {
	df := map[string]int{}
	for _, t := range tasks {
		seen := map[string]bool{}
		for _, s := range t.Steps {
			if s.Key != "" && !seen[s.Key] {
				seen[s.Key] = true
				df[s.Key]++
			}
		}
	}
	w := make(map[string]float64, len(df))
	for k, n := range df {
		w[k] = math.Max(math.Log(float64(len(tasks))/float64(n)), 0.05)
	}
	return w
}

func jaccard(a, b []string) float64 {
	in := map[string]bool{}
	for _, s := range a {
		in[s] = true
	}
	both, all := 0, len(in)
	for _, s := range b {
		if in[s] {
			both++
		} else {
			all++
		}
	}
	if all == 0 {
		return 0
	}
	return float64(both) / float64(all)
}

var stopWords = map[string]bool{
	"the": true, "a": true, "an": true, "and": true, "or": true, "of": true, "to": true, "in": true, "on": true, "for": true,
	"is": true, "are": true, "was": true, "it": true, "this": true, "that": true, "me": true, "my": true, "i": true, "you": true,
	"please": true, "can": true, "could": true, "now": true, "again": true, "with": true, "at": true, "be": true, "do": true,
	"how": true, "what": true, "whats": true,
}

// tokens lowercases text into words, dropping placeholders, one-letter
// words and the small words that carry no meaning.
func tokens(s string) []string {
	var out []string
	for _, w := range strings.FieldsFunc(strings.ToLower(s), func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) && r != '<' && r != '>' }) {
		if strings.HasPrefix(w, "<") || len(w) < 2 || stopWords[w] {
			continue
		}
		out = append(out, w)
	}
	return out
}
