package skills

import (
	"fmt"
	"sort"
	"strings"
)

// Options say what counts as a routine worth a skill.
type Options struct {
	// Similar is the average similarity to a group's members that a task needs
	// to join it.
	Similar float64
	// MinRuns is how often a routine must come up.
	MinRuns int
	// WindowMs, if set, only counts tasks from the last WindowMs before NowMs.
	WindowMs, NowMs int64
	// MinClean is the share of runs that must have no failed step.
	MinClean float64
	// MinSessions is how many different sessions it must have come up in: the
	// same ask repeated inside one conversation is a follow-up, not a habit.
	MinSessions int
}

// DefaultOptions: three runs in 30 days, mostly without failures.
func DefaultOptions(nowMs int64) Options {
	return Options{Similar: 0.45, MinRuns: 3, WindowMs: 30 * 24 * 3600 * 1000, NowMs: nowMs, MinClean: 0.6, MinSessions: 2}
}

// Candidate is a routine that keeps coming back.
type Candidate struct {
	// Example is the request of the most typical run.
	Example string
	Runs    []Task
	// Sessions, Nodes and Cwds are the distinct places it ran, most used first.
	Sessions int
	Nodes    []string
	Cwds     []string
	// Steps are the steps most runs share, in the order they first appear,
	// with what each looked like.
	Steps []CommonStep
	// Mutating is true if any common step changes something.
	Mutating bool
	// Clean is the share of runs without a failed step.
	Clean           float64
	FirstMs, LastMs int64
}

// CommonStep is a step most runs of a routine take.
type CommonStep struct {
	Key      string
	Detail   string
	Mutating bool
	// Share of runs that take it.
	Share float64
}

// Cluster groups tasks that are the same routine and keeps the groups that
// meet the options. Tasks without tool calls are ignored: there is nothing in
// them to repeat. Groups are sorted by how often and how recently they came up.
func Cluster(tasks []Task, o Options) []Candidate {
	type member struct {
		task Task
		fp   Fingerprint
	}
	var eligible []Task
	// A fork or a continued chat carries the earlier history with it, so the same
	// request shows up in several sessions: count it once.
	seen := map[string]bool{}
	for _, t := range tasks {
		if !t.Routine() || !t.Standalone() || o.WindowMs > 0 && t.StartMs > 0 && o.NowMs-t.StartMs > o.WindowMs {
			continue
		}
		key := fmt.Sprintf("%s|%d", t.Request, t.StartMs)
		if t.StartMs == 0 {
			key = t.Request + "|" + t.Session
		}
		if !seen[key] {
			seen[key] = true
			eligible = append(eligible, t)
		}
	}
	w := stepWeights(eligible)
	var groups [][]member
	for _, t := range eligible {
		m := member{task: t, fp: FingerprintOf(t)}
		best, bestSim := -1, 0.0
		for gi, g := range groups {
			var sum float64
			for _, other := range g {
				sum += related(m.fp, other.fp, w)
			}
			if avg := sum / float64(len(g)); avg >= o.Similar && avg > bestSim {
				best, bestSim = gi, avg
			}
		}
		if best < 0 {
			groups = append(groups, []member{m})
		} else {
			groups[best] = append(groups[best], m)
		}
	}
	var out []Candidate
	for _, g := range groups {
		if len(g) < o.MinRuns {
			continue
		}
		c := Candidate{}
		fps := make([]Fingerprint, len(g))
		for i, m := range g {
			c.Runs = append(c.Runs, m.task)
			fps[i] = m.fp
		}
		c.Example = g[typical(fps)].task.Request
		fill(&c)
		if c.Clean < o.MinClean || c.Sessions < o.MinSessions {
			continue
		}
		out = append(out, c)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if len(out[i].Runs) != len(out[j].Runs) {
			return len(out[i].Runs) > len(out[j].Runs)
		}
		return out[i].LastMs > out[j].LastMs
	})
	return out
}

// typical is the run most like all the others.
func typical(fps []Fingerprint) int {
	best, bestSum := 0, -1.0
	for i := range fps {
		var sum float64
		for j := range fps {
			if i != j {
				sum += Similarity(fps[i], fps[j])
			}
		}
		if sum > bestSum {
			best, bestSum = i, sum
		}
	}
	return best
}

func fill(c *Candidate) {
	sessions := map[string]bool{}
	nodes, cwds := map[string]int{}, map[string]int{}
	clean := 0
	first := map[string]int{}
	count := map[string]int{}
	detail := map[string]string{}
	mutating := map[string]bool{}
	var order []string
	for _, t := range c.Runs {
		sessions[t.Session] = true
		nodes[t.Node]++
		if t.Cwd != "" {
			cwds[t.Cwd]++
		}
		if c.FirstMs == 0 || t.StartMs > 0 && t.StartMs < c.FirstMs {
			c.FirstMs = t.StartMs
		}
		if t.StartMs > c.LastMs {
			c.LastMs = t.StartMs
		}
		ok, seen := true, map[string]bool{}
		for _, s := range t.Steps {
			ok = ok && !s.Failed
			if s.Key == "" || seen[s.Key] {
				continue
			}
			seen[s.Key] = true
			count[s.Key]++
			if _, known := first[s.Key]; !known {
				first[s.Key] = len(order)
				order = append(order, s.Key)
				detail[s.Key] = s.Detail
			}
			mutating[s.Key] = mutating[s.Key] || s.Mutating
		}
		if ok {
			clean++
		}
	}
	c.Sessions = len(sessions)
	c.Nodes, c.Cwds = byCount(nodes), byCount(cwds)
	c.Clean = float64(clean) / float64(len(c.Runs))
	for _, key := range order {
		share := float64(count[key]) / float64(len(c.Runs))
		if share < 0.5 {
			continue
		}
		c.Steps = append(c.Steps, CommonStep{Key: key, Detail: oneLine(detail[key]), Mutating: mutating[key], Share: share})
		c.Mutating = c.Mutating || mutating[key]
	}
}

func byCount(m map[string]int) []string {
	var out []string
	for k := range m {
		out = append(out, k)
	}
	sort.Slice(out, func(i, j int) bool {
		if m[out[i]] != m[out[j]] {
			return m[out[i]] > m[out[j]]
		}
		return out[i] < out[j]
	})
	return out
}

func oneLine(s string) string {
	s = strings.Join(strings.Fields(s), " ")
	if len(s) > 160 {
		s = s[:160] + "…"
	}
	return s
}
