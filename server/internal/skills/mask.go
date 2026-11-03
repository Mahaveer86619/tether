package skills

import (
	"regexp"
	"strings"
)

// Mask replaces the parts of a line that change from one run of a routine to
// the next (ids, dates, times, addresses, hashes, big numbers) with
// placeholders, so two runs of the same routine read the same.
func Mask(s string) string {
	for _, m := range masks {
		s = m.re.ReplaceAllStringFunc(s, func(found string) string {
			if m.keep != nil && !m.keep(found) {
				return found
			}
			return m.to
		})
	}
	return s
}

var masks = []struct {
	re   *regexp.Regexp
	to   string
	keep func(string) bool
}{
	{re: regexp.MustCompile(`[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}`), to: "<id>"},
	{re: regexp.MustCompile(`\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:?\d{2})?)?`), to: "<date>"},
	{re: regexp.MustCompile(`\b\d{8}(?:-\d{4,6})?\b`), to: "<date>"},
	{re: regexp.MustCompile(`\b\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?\b`), to: "<ip>"},
	{re: regexp.MustCompile(`\b\d{1,2}:\d{2}(?::\d{2})?\b`), to: "<time>"},
	{re: regexp.MustCompile(`\b\d{1,3}(?:,\d{3})+\b`), to: "<n>"},
	// A hash has both letters and digits; "deadbeef" and "1234567" are not one.
	{re: regexp.MustCompile(`\b[0-9a-f]{7,40}\b`), to: "<hash>", keep: func(s string) bool {
		return strings.IndexFunc(s, func(r rune) bool { return r >= '0' && r <= '9' }) >= 0 &&
			strings.IndexFunc(s, func(r rune) bool { return r >= 'a' && r <= 'f' }) >= 0
	}},
	{re: regexp.MustCompile(`\b\d{3,}\b`), to: "<n>"},
}

// subcommandTools take a verb after their name, so "git status" and "git push"
// are different steps.
var subcommandTools = map[string]bool{
	"git": true, "docker": true, "systemctl": true, "tmux": true, "kubectl": true, "npm": true, "go": true,
	"flutter": true, "adb": true, "gh": true, "journalctl": false, "tailscale": true, "cargo": true, "pnpm": true,
}

// commandKey names a shell command by its first command and, for tools with
// subcommands, the subcommand: "tail", "tmux capture-pane", "git log".
func commandKey(cmd string) string {
	for _, seg := range segments(cmd) {
		fields := strings.Fields(seg)
		for len(fields) > 0 && (isAssignment(fields[0]) || fields[0] == "sudo" || fields[0] == "export") {
			fields = fields[1:]
		}
		if len(fields) == 0 {
			continue
		}
		verb := baseName(fields[0])
		if verb == "cd" || verb == "set" {
			continue
		}
		if !plainWord.MatchString(verb) {
			// A shell function, a variable or a stray quote: nothing to name it by.
			return "shell"
		}
		if subcommandTools[verb] {
			for _, f := range fields[1:] {
				if !strings.HasPrefix(f, "-") {
					return verb + " " + f
				}
			}
		}
		return verb
	}
	return ""
}

var plainWord = regexp.MustCompile(`^[A-Za-z][A-Za-z0-9._-]*$`)

func isAssignment(f string) bool {
	i := strings.Index(f, "=")
	return i > 0 && !strings.ContainsAny(f[:i], "/\\.:") && !strings.HasPrefix(f, "-")
}

func baseName(p string) string {
	p = strings.ReplaceAll(p, `\`, "/")
	return strings.TrimSuffix(p[strings.LastIndex(p, "/")+1:], ".exe")
}

// segments splits a command line at pipes, && , || and ;.
func segments(cmd string) []string {
	r := strings.NewReplacer("&&", "\x00", "||", "\x00", "|", "\x00", ";", "\x00", "\n", "\x00")
	var out []string
	for _, s := range strings.Split(r.Replace(cmd), "\x00") {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}

// readOnlyVerbs never change anything on their own.
var readOnlyVerbs = map[string]bool{
	"ls": true, "dir": true, "cat": true, "head": true, "tail": true, "grep": true, "rg": true, "egrep": true, "find": true,
	"wc": true, "du": true, "df": true, "ps": true, "pgrep": true, "top": true, "htop": true, "echo": true, "pwd": true,
	"which": true, "where": true, "stat": true, "file": true, "less": true, "more": true, "sort": true, "uniq": true,
	"date": true, "uname": true, "whoami": true, "hostname": true, "free": true, "uptime": true, "env": true, "printenv": true,
	"journalctl": true, "ping": true, "nslookup": true, "dig": true, "jq": true, "cut": true, "tr": true, "awk": true,
	"test": true, "[": true, "type": true, "get-content": true, "get-childitem": true, "select-string": true,
}

// readOnlySubcommands are the subcommands of tools that only look.
var readOnlySubcommands = map[string]map[string]bool{
	"git":       {"status": true, "log": true, "diff": true, "show": true, "branch": true, "remote": true, "rev-parse": true, "ls-files": true, "blame": true, "describe": true, "fetch": true, "stash list": true},
	"docker":    {"ps": true, "logs": true, "images": true, "inspect": true, "stats": true, "compose ps": true},
	"systemctl": {"status": true, "is-active": true, "list-units": true, "is-enabled": true, "show": true},
	"tmux":      {"ls": true, "list-sessions": true, "capture-pane": true, "list-windows": true, "has-session": true, "list-panes": true},
	"adb":       {"devices": true, "logcat": true},
	"gh":        {"pr": true, "run": true, "api": true, "auth": true},
	"tailscale": {"status": true, "ip": true, "ping": true},
	"go":        {"test": true, "vet": true, "version": true, "list": true},
	"flutter":   {"analyze": true, "test": true, "doctor": true},
	"kubectl":   {"get": true, "describe": true, "logs": true},
}

var writeWords = regexp.MustCompile(`(?i)\b(insert|update|delete|drop|alter|create|truncate|grant|revoke|replace)\b`)

// mutatingCommand is true unless every part of the command line is known to
// only look. Unknown commands count as mutating, so a skill never labels a
// step safe by guessing.
func mutatingCommand(cmd string) bool {
	if redirectsToFile(cmd) {
		return true
	}
	for _, seg := range segments(cmd) {
		fields := strings.Fields(seg)
		for len(fields) > 0 && (isAssignment(fields[0]) || fields[0] == "sudo" || fields[0] == "export") {
			fields = fields[1:]
		}
		if len(fields) == 0 {
			continue
		}
		verb := strings.ToLower(baseName(fields[0]))
		switch {
		case verb == "cd" || verb == "set":
		case verb == "psql" || verb == "mysql" || verb == "sqlite3":
			if writeWords.MatchString(seg) {
				return true
			}
		case verb == "curl" || verb == "wget" || verb == "http":
			if hasAny(fields, "-X", "--request", "-d", "--data", "--data-raw", "-F", "--form", "-T", "-o", "-O", "--output") {
				return true
			}
		case verb == "sed":
			if hasAny(fields, "-i", "--in-place") {
				return true
			}
		case verb == "awk" || verb == "find":
			if hasAny(fields, "-exec", "-delete", "system(") {
				return true
			}
		case readOnlySubcommands[verb] != nil:
			if !readOnlySubcommands[verb][subcommand(fields)] {
				return true
			}
		case readOnlyVerbs[verb]:
		default:
			return true
		}
	}
	return false
}

func hasAny(fields []string, any ...string) bool {
	for _, f := range fields {
		for _, a := range any {
			if f == a || a == "system(" && strings.Contains(f, a) {
				return true
			}
		}
	}
	return false
}

// subcommand returns the words after the tool name that name what it does:
// one word, or two for "docker compose ps" and "git stash list".
func subcommand(fields []string) string {
	var words []string
	for _, f := range fields[1:] {
		if !strings.HasPrefix(f, "-") {
			words = append(words, f)
		}
		if len(words) == 2 {
			break
		}
	}
	if len(words) == 2 && (words[0] == "compose" || words[0] == "stash") {
		return words[0] + " " + words[1]
	}
	if len(words) > 0 {
		return words[0]
	}
	return ""
}

// unquoted blanks out what is inside quotes: a > in an SQL comparison or an
// echoed string is not a redirect.
func unquoted(s string) string {
	var b strings.Builder
	var quote rune
	for _, r := range s {
		switch {
		case quote != 0 && r == quote:
			quote = 0
		case quote != 0:
		case r == '\'' || r == '"':
			quote = r
		default:
			b.WriteRune(r)
		}
	}
	return b.String()
}

// redirectsToFile is true for > and >> into anything but /dev/null or a file
// descriptor, and for tee.
func redirectsToFile(cmd string) bool {
	c := strings.NewReplacer("=>", "", "->", "", "2>&1", "", "1>&2", "", ">&2", "", "&>/dev/null", "", "&> /dev/null", "", "2>/dev/null", "", "2> /dev/null", "", ">/dev/null", "", "> /dev/null", "").Replace(cmd)
	if strings.Contains(unquoted(c), ">") {
		return true
	}
	for _, seg := range segments(c) {
		if f := strings.Fields(seg); len(f) > 0 && baseName(f[0]) == "tee" {
			return true
		}
	}
	return false
}
