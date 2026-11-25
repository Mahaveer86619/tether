package skills

import (
	"math"
	"sort"
	"strings"
)

// Match is a skill that seems to fit a request.
type Match struct {
	Skill Skill
	Score float64
	// Shared are the request's words the skill has too, the weightiest first.
	Shared []string
}

// Reason says in a line why the skill matched.
func (m Match) Reason() string {
	if len(m.Shared) == 0 {
		return ""
	}
	return "shares " + strings.Join(m.Shared, ", ")
}

// Router scoring: cosine between the request's words and the skill's words
// (name, description and the request it was learned from), each word
// weighted by how rare it is across the skills so "build" doesn't match
// everything. No model, nothing leaves the hub.
const routerMinScore = 0.2

// searchMinScore is lower than the router's: someone typing in the search
// box wants every skill that shares a meaningful word.
const searchMinScore = 0.05

// Rank returns up to k skills that fit the request best, best first, and
// none for a request that shares no meaningful words with any.
func Rank(request string, list []Skill, k int) []Match {
	return rank(tokens(request), list, k, routerMinScore, false)
}

// Search ranks the skills for a search box: like Rank, with a lower bar, and
// the last word may be unfinished ("syn" finds "sync").
func Search(query string, list []Skill, k int) []Match {
	return rank(tokens(query), list, k, searchMinScore, !strings.HasSuffix(query, " "))
}

func rank(req []string, list []Skill, k int, floor float64, prefix bool) []Match {
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
	var out []Match
	for i, s := range list {
		q := map[string]float64{}
		for j, w := range req {
			if prefix && j == len(req)-1 && docs[i][w] == 0 {
				w = completion(w, docs[i])
			}
			q[w]++
		}
		var dot, qn, dn float64
		var shared []string
		for w, n := range q {
			qn += (n * idf(w)) * (n * idf(w))
			if m, ok := docs[i][w]; ok {
				dot += n * idf(w) * m * idf(w)
				shared = append(shared, w)
			}
		}
		for w, n := range docs[i] {
			dn += (n * idf(w)) * (n * idf(w))
		}
		if dot == 0 || qn == 0 || dn == 0 {
			continue
		}
		if score := dot / (math.Sqrt(qn) * math.Sqrt(dn)); score >= floor {
			sort.SliceStable(shared, func(a, b int) bool {
				if ia, ib := idf(shared[a]), idf(shared[b]); ia != ib {
					return ia > ib
				}
				return shared[a] < shared[b]
			})
			out = append(out, Match{Skill: s, Score: score, Shared: shared})
		}
	}
	sort.SliceStable(out, func(a, b int) bool { return out[a].Score > out[b].Score })
	if len(out) > k {
		out = out[:k]
	}
	return out
}

// completion is the shortest word in doc that w begins, or w.
func completion(w string, doc map[string]float64) string {
	best := ""
	for d := range doc {
		if strings.HasPrefix(d, w) && (best == "" || len(d) < len(best) || len(d) == len(best) && d < best) {
			best = d
		}
	}
	if best == "" {
		return w
	}
	return best
}
