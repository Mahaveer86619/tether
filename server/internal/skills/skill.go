package skills

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
	"unicode/utf8"
)

// A skill is a Claude Code skill: SKILL.md with a front matter that names it
// and says when to use it, then the steps. Tether keeps them on the hub and
// hands them to Claude through the hub's MCP server, so every machine has the
// same ones. See docs/skills.md.

const (
	maxSkillBytes   = 20 << 10
	maxDescription  = 400
	minDescription  = 12
	maxNameLen      = 40
	statusProposed  = "proposed"
	statusActive    = "active"
	statusDismissed = "dismissed"
)

var nameRe = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{1,` + "39" + `}$`)

// Parsed is a SKILL.md split into the parts Tether needs.
type Parsed struct {
	Name, Description, Body string
}

// ParseSkill reads the front matter (name and description) of a SKILL.md.
func ParseSkill(md string) (Parsed, error) {
	md = strings.ReplaceAll(strings.TrimSpace(md), "\r\n", "\n")
	if !strings.HasPrefix(md, "---\n") {
		return Parsed{}, errors.New("a skill starts with front matter: --- name: ... description: ... ---")
	}
	rest := md[4:]
	end := strings.Index(rest, "\n---")
	if end < 0 {
		return Parsed{}, errors.New("the front matter is not closed with ---")
	}
	p := Parsed{Body: strings.TrimSpace(rest[end+4:])}
	for _, line := range strings.Split(rest[:end], "\n") {
		k, v, ok := strings.Cut(line, ":")
		if !ok {
			continue
		}
		v = strings.Trim(strings.TrimSpace(v), `"'`)
		switch strings.TrimSpace(k) {
		case "name":
			p.Name = v
		case "description":
			p.Description = v
		}
	}
	return p, nil
}

// secretLike finds text that looks like a credential. A skill is shared with
// every session, so it must name where a secret lives, never hold one.
var secretLike = []*regexp.Regexp{
	regexp.MustCompile(`-----BEGIN [A-Z ]*PRIVATE KEY-----`),
	regexp.MustCompile(`\bAKIA[0-9A-Z]{16}\b`),
	regexp.MustCompile(`\bsk-[A-Za-z0-9_-]{20,}`),
	regexp.MustCompile(`\bgh[pousr]_[A-Za-z0-9]{30,}`),
	regexp.MustCompile(`\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}`),
	regexp.MustCompile(`(?i)\bbearer\s+[A-Za-z0-9._~+/-]{20,}`),
	regexp.MustCompile(`(?i)\b(password|passwd|secret|token|api[_-]?key)\s*[=:]\s*["']?[^\s"'<$]{8,}`),
	regexp.MustCompile(`(?i)://[^/\s:@]+:[^/\s@]{3,}@`),
}

// Validate checks a SKILL.md before it is kept.
func Validate(md string) (Parsed, error) {
	if len(md) > maxSkillBytes {
		return Parsed{}, fmt.Errorf("a skill is at most %d KB", maxSkillBytes>>10)
	}
	p, err := ParseSkill(md)
	if err != nil {
		return Parsed{}, err
	}
	if !nameRe.MatchString(p.Name) {
		return Parsed{}, fmt.Errorf("the name %q must be lower case letters, digits and dashes, 2 to %d characters", p.Name, maxNameLen)
	}
	if n := utf8.RuneCountInString(p.Description); n < minDescription || n > maxDescription {
		return Parsed{}, fmt.Errorf("the description must say when to use the skill, %d to %d characters", minDescription, maxDescription)
	}
	if len(strings.Fields(p.Body)) < 8 {
		return Parsed{}, errors.New("the skill has no steps")
	}
	for _, re := range secretLike {
		if re.MatchString(md) {
			return Parsed{}, errors.New("the skill contains what looks like a secret; name where to read it instead")
		}
	}
	return p, nil
}
