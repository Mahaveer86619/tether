// Package indexer scans and indexes Claude Code sessions and parses ignore rules.
package indexer

import (
	"regexp"
	"strings"
)

// DefaultTetherignore is written into a codebase that has no .tetherignore
// when it's first snapshotted. Gitignore syntax.
const DefaultTetherignore = `# What Tether never copies to the hub. Gitignore syntax.
# .env files are kept separately, encrypted on the hub; see docs/plan.md.
.git/
.tether/attachments/
.env
.env.*
!.env.example
!.env.sample
!.env.template

# Dependencies and build output: rebuilt on the other side.
node_modules/
.dart_tool/
.gradle/
build/
dist/
out/
target/
.next/
.nuxt/
.venv/
venv/
__pycache__/
*.pyc
.pytest_cache/
.mypy_cache/
.terraform/
vendor/bundle/

# Editors and OS clutter.
.idea/
.vs/
.DS_Store
Thumbs.db
*.log
`

type ignoreRule struct {
	re      *regexp.Regexp
	negate  bool
	dirOnly bool
}

// IgnoreRules is a parsed .tetherignore. The last rule that matches a path
// decides, as with .gitignore.
type IgnoreRules []ignoreRule

// ParseIgnore parses gitignore-style ignore rules from text.
func ParseIgnore(text string) IgnoreRules {
	var rules IgnoreRules
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimRight(line, "\r \t")
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		r := ignoreRule{}
		if strings.HasPrefix(line, "!") {
			r.negate, line = true, line[1:]
		}
		if strings.HasSuffix(line, "/") {
			r.dirOnly, line = true, strings.TrimSuffix(line, "/")
		}
		// A slash anywhere but the end anchors the pattern to the root.
		anchored := strings.Contains(line, "/")
		line = strings.TrimPrefix(line, "/")
		var b strings.Builder
		if anchored {
			b.WriteString("^")
		} else {
			b.WriteString("^(?:.*/)?")
		}
		for i := 0; i < len(line); i++ {
			switch c := line[i]; {
			case strings.HasPrefix(line[i:], "**/"):
				b.WriteString("(?:.*/)?")
				i += 2
			case strings.HasPrefix(line[i:], "/**"):
				b.WriteString("(?:/.*)?")
				i += 2
			case c == '*':
				b.WriteString("[^/]*")
			case c == '?':
				b.WriteString("[^/]")
			default:
				b.WriteString(regexp.QuoteMeta(string(c)))
			}
		}
		b.WriteString("$")
		re, err := regexp.Compile(b.String())
		if err != nil {
			continue
		}
		r.re = re
		rules = append(rules, r)
	}
	return rules
}

// Ignored reports whether rel (forward slashes, relative to the codebase)
// is left out. Callers skip an ignored folder's contents.
func (rules IgnoreRules) Ignored(rel string, dir bool) bool {
	out := false
	for _, r := range rules {
		if r.dirOnly && !dir {
			continue
		}
		if r.re.MatchString(rel) {
			out = !r.negate
		}
	}
	return out
}

func (rules IgnoreRules) ignored(rel string, dir bool) bool {
	return rules.Ignored(rel, dir)
}

var envName = regexp.MustCompile(`^\.env(\..+)?$`)

// IsEnvFile reports whether a file holds secrets for the vault: .env and
// .env.<anything>, except the examples projects commit.
func IsEnvFile(name string) bool {
	if !envName.MatchString(name) {
		return false
	}
	switch strings.TrimPrefix(name, ".env.") {
	case "example", "sample", "template", "dist", "defaults":
		return false
	}
	return true
}
