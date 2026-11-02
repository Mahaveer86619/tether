// Package updates manages release manifests, semver comparison, and agent self-updates.
package updates

import (
	"strconv"
	"strings"
)

// Parse parses a semantic version string (e.g. "v0.17.0" or "1.2.3") into [3]int.
func Parse(s string) ([3]int, bool) {
	var out [3]int
	s = strings.TrimPrefix(strings.TrimSpace(s), "v")
	if i := strings.IndexAny(s, "-+ "); i >= 0 {
		s = s[:i]
	}
	parts := strings.Split(s, ".")
	if len(parts) != 3 {
		return out, false
	}
	for i, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil {
			return out, false
		}
		out[i] = n
	}
	return out, true
}

// AtLeast reports whether version a is greater than or equal to version b.
func AtLeast(a, b string) bool {
	va, oka := Parse(a)
	vb, okb := Parse(b)
	if !oka || !okb {
		return false
	}
	for i := 0; i < 3; i++ {
		if va[i] > vb[i] {
			return true
		}
		if va[i] < vb[i] {
			return false
		}
	}
	return true
}
