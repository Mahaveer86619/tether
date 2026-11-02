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
	// light local embedder from docs/plan.md: no model, nothing leaves the hub.
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

// Similarity is 0 to 1. When both tasks used tools, the words and the steps
// count equally: the same routine is asked for in different words, and
// different routines can share a word. Without steps only the words count.
func Similarity(a, b Fingerprint) float64 {
	var dot float64
	for i := range a.Words {
		dot += float64(a.Words[i]) * float64(b.Words[i])
	}
	cos := math.Max(dot, 0)
	if len(a.Steps) == 0 || len(b.Steps) == 0 {
		return cos
	}
	return 0.5*cos + 0.5*jaccard(a.Steps, b.Steps)
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
