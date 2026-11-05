package skills

import (
	"math"
	"sort"
)

// Match is a skill that seems to fit a request.
type Match struct {
	Skill Skill
	Score float64
}

// Router scoring: cosine between the request's words and the skill's words
// (name, description and the request it was learned from), each word
// weighted by how rare it is across the skills so "build" doesn't match
// everything. No model, nothing leaves the hub.
const routerMinScore = 0.2

// Rank returns up to k skills that fit the request best, best first, and
// none for a request that shares no meaningful words with any.
func Rank(request string, list []Skill, k int) []Match {
	req := tokens(request)
	if len(req) == 0 || len(list) == 0 || k <= 0 {
		return nil
	}
	docs := make([]map[string]float64, len(list))
	df := map[string]int{}
	for i, s := range list {
		docs[i] = map[string]float64{}
		for _, w := range tokens(s.Name + " " + s.Description + " " + s.Description + " " + s.Source) {
			docs[i][w]++
		}
		for w := range docs[i] {
			df[w]++
		}
	}
	idf := func(w string) float64 { return math.Log(1+float64(len(list))/float64(1+df[w])) + 1 }
	q := map[string]float64{}
	for _, w := range req {
		q[w]++
	}
	var out []Match
	for i, s := range list {
		var dot, qn, dn float64
		for w, n := range q {
			qn += (n * idf(w)) * (n * idf(w))
			if m, ok := docs[i][w]; ok {
				dot += n * idf(w) * m * idf(w)
			}
		}
		for w, n := range docs[i] {
			dn += (n * idf(w)) * (n * idf(w))
		}
		if dot == 0 || qn == 0 || dn == 0 {
			continue
		}
		if score := dot / (math.Sqrt(qn) * math.Sqrt(dn)); score >= routerMinScore {
			out = append(out, Match{Skill: s, Score: score})
		}
	}
	sort.SliceStable(out, func(a, b int) bool { return out[a].Score > out[b].Score })
	if len(out) > k {
		out = out[:k]
	}
	return out
}
