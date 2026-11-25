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
// same ones. See docs/plans/skills.md.

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

// Parsed is a SKILL.md split into the parts Tether needs. A script skill
// also says what its scripts need: environment variable names (never their
// values), where it runs and whether it changes anything.
type Parsed struct {
	Name, Description, Body string
	NeedsEnv                []string
	RunsOn, Effect          string
	Scripts                 []string
}

const (
	EffectRead  = "read"
	EffectWrite = "write"
	maxScripts  = 8
	// MaxScriptBytes bounds a script whose contents are checked and hashed.
	MaxScriptBytes = 64 << 10
)

// ParseSkill reads the front matter of a SKILL.md. Lists are written inline
// ([A, B]) or as "- item" lines under their key.
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
	var list *[]string
	for _, line := range strings.Split(rest[:end], "\n") {
		if item, ok := strings.CutPrefix(strings.TrimSpace(line), "- "); ok && list != nil {
			*list = append(*list, unquote(item))
			continue
		}
		list = nil
		k, v, ok := strings.Cut(line, ":")
		if !ok {
			continue
		}
		v = unquote(v)
		switch strings.TrimSpace(k) {
		case "name":
			p.Name = v
		case "description":
			p.Description = v
		case "runs_on":
			p.RunsOn = v
		case "effect":
			p.Effect = strings.ToLower(v)
		case "needs_env":
			p.NeedsEnv, list = inlineList(v), &p.NeedsEnv
		case "scripts":
			p.Scripts, list = inlineList(v), &p.Scripts
		}
	}
	return p, nil
}

func unquote(v string) string { return strings.Trim(strings.TrimSpace(v), `"'`) }

func inlineList(v string) []string {
	v = strings.TrimSpace(v)
	if v == "" {
		return nil
	}
	if !strings.HasPrefix(v, "[") {
		return []string{v}
	}
	var out []string
	for _, item := range strings.Split(strings.Trim(v, "[]"), ",") {
		if item = unquote(item); item != "" {
			out = append(out, item)
		}
	}
	return out
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
	regexp.MustCompile(`(?i)://[^/\s:@]+:[^/\s@]{3,}@`),
}

// secretAssign finds a secret-named setting given a literal value, including
// environment style names such as DB_PASSWORD=... in a script or a .env line.
var secretAssign = regexp.MustCompile(`(?i)(?:\b|_)(password|passwd|secret|token|api[_-]?key|access[_-]?key)\b["']?\s*[=:]\s*["']?([^\s"'<$]{8,})`)

// codeValue is a value read from somewhere rather than written out:
// os.environ["X"], getenv("X"), process.env.X, a function call.
var codeValue = regexp.MustCompile(`^([A-Za-z_][A-Za-z0-9_]*\.)+[A-Za-z_]|[(\[{]`)

// LooksSecret reports whether text holds what looks like a credential.
func LooksSecret(text string) bool {
	for _, re := range secretLike {
		if re.MatchString(text) {
			return true
		}
	}
	for _, m := range secretAssign.FindAllStringSubmatch(text, -1) {
		if !codeValue.MatchString(m[2]) {
			return true
		}
	}
	return false
}

var (
	envNameRe = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]{0,63}$`)
	runsOnRe  = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$`)
)

// ScriptPath cleans a script's path, relative to the project, or says why not.
func ScriptPath(p string) (string, error) {
	c := strings.TrimPrefix(strings.ReplaceAll(strings.TrimSpace(p), `\`, "/"), "./")
	if c == "" || strings.HasPrefix(c, "/") || strings.HasPrefix(c, "~") || strings.Contains(c, ":") || strings.Contains("/"+c+"/", "/../") || strings.HasSuffix(c, "/") {
		return "", fmt.Errorf("the script path %q must be relative to the project, inside it", p)
	}
	return c, nil
}

// ValidateScript checks a script's contents before its hash is kept. Like the
// skill, it reads credentials from the environment and never holds them.
func ValidateScript(path, content string) error {
	if len(content) > MaxScriptBytes {
		return fmt.Errorf("%s is over %d KB", path, MaxScriptBytes>>10)
	}
	if strings.TrimSpace(content) == "" {
		return fmt.Errorf("%s is empty", path)
	}
	if LooksSecret(content) {
		return fmt.Errorf("%s contains what looks like a secret; read it from the environment (needs_env) instead", path)
	}
	return nil
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
	if LooksSecret(md) {
		return Parsed{}, errors.New("the skill contains what looks like a secret; name where to read it instead")
	}
	for _, n := range p.NeedsEnv {
		if !envNameRe.MatchString(n) {
			return Parsed{}, fmt.Errorf("needs_env lists names only, like DB_URL; %q is not one", clipText(n, 20))
		}
	}
	if p.RunsOn != "" && !runsOnRe.MatchString(p.RunsOn) {
		return Parsed{}, errors.New("runs_on is a device name or any")
	}
	if p.Effect != "" && p.Effect != EffectRead && p.Effect != EffectWrite {
		return Parsed{}, errors.New("effect is read or write")
	}
	if len(p.Scripts) > maxScripts {
		return Parsed{}, fmt.Errorf("a skill has at most %d scripts", maxScripts)
	}
	seen := map[string]bool{}
	for i, sp := range p.Scripts {
		c, err := ScriptPath(sp)
		if err != nil {
			return Parsed{}, err
		}
		if seen[c] {
			return Parsed{}, fmt.Errorf("%s is listed twice", c)
		}
		seen[c], p.Scripts[i] = true, c
	}
	if len(p.Scripts) > 0 && p.Effect == "" {
		return Parsed{}, errors.New("a skill with scripts says its effect: read or write")
	}
	return p, nil
}

func clipText(s string, n int) string {
	if r := []rune(s); len(r) > n {
		return string(r[:n]) + "…"
	}
	return s
}
