package skills

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"sort"
	"strings"
	"sync"
)

// KV is the small named-value store the library keeps its skills in.
type KV interface {
	Get(key string) ([]byte, error)
	Put(key string, value []byte) error
}

// Version is one text of a skill. A skill is never edited in place: a
// change is a new version with the reason, so a bad correction can be undone.
type Version struct {
	N    int    `json:"n"`
	MD   string `json:"md"`
	Note string `json:"note"`
	By   string `json:"by"`
	AtMs int64  `json:"atMs"`
}

// Skill is what the library keeps.
type Skill struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	// Status is proposed (waiting for the owner), active (Claude can use it) or
	// dismissed (the owner said no; kept so it isn't proposed again).
	Status string `json:"status"`
	// Mutating is true if a step changes something, so the owner knows before
	// approving, and Claude knows to ask.
	Mutating bool `json:"mutating"`
	// Source is the request it was learned from.
	Source   string    `json:"source"`
	Versions []Version `json:"versions"`
	UpdatedM int64     `json:"updatedMs"`
	// What a script skill's front matter declares, from the latest version.
	NeedsEnv []string `json:"needsEnv,omitempty"`
	RunsOn   string   `json:"runsOn,omitempty"`
	Effect   string   `json:"effect,omitempty"`
	// Scripts are the hashes the scripts had when the skill was proposed or
	// corrected. The scripts themselves live in the project.
	Scripts []Script `json:"scripts,omitempty"`
	// Changed holds the hash a session reported for each script that no
	// longer matches: the skill waits for review, and approving it again
	// accepts these.
	Changed map[string]string `json:"changed,omitempty"`
}

// Script is a script a skill runs, by its path in the project.
type Script struct {
	Path   string `json:"path"`
	Sha256 string `json:"sha256"`
}

// Hash is how a script's contents are compared: sha256 of the bytes in hex,
// as sha256sum prints it.
func Hash(content string) string {
	h := sha256.Sum256([]byte(content))
	return hex.EncodeToString(h[:])
}

// NeedsReview reports whether a script changed since the skill was approved.
func (s Skill) NeedsReview() bool { return len(s.Changed) > 0 }

// declare copies what a version's front matter says onto the skill, and
// hashes its scripts from the contents the session sent.
func (s *Skill) declare(p Parsed, scripts map[string]string) error {
	hashes, err := scriptHashes(p, scripts, s.Scripts)
	if err != nil {
		return err
	}
	changed := map[string]string{}
	if s.Status == statusActive {
		// A script of an approved skill doesn't change without the owner:
		// the new hash waits in Changed for approval.
		sent := map[string]bool{}
		for path := range scripts {
			if c, err := ScriptPath(path); err == nil {
				sent[c] = true
			}
		}
		for i, sc := range hashes {
			if !sent[sc.Path] {
				if h, was := s.Changed[sc.Path]; was {
					changed[sc.Path] = h
				}
				continue
			}
			old := slices.IndexFunc(s.Scripts, func(k Script) bool { return k.Path == sc.Path })
			switch {
			case old < 0:
				changed[sc.Path], hashes[i].Sha256 = sc.Sha256, ""
			case s.Scripts[old].Sha256 != sc.Sha256:
				changed[sc.Path], hashes[i] = sc.Sha256, s.Scripts[old]
			}
		}
	}
	if len(changed) == 0 {
		changed = nil
	}
	s.Description, s.NeedsEnv, s.RunsOn, s.Effect, s.Scripts, s.Changed = p.Description, p.NeedsEnv, p.RunsOn, p.Effect, hashes, changed
	if p.Effect == EffectWrite {
		s.Mutating = true
	}
	return nil
}

// scriptHashes hashes the scripts sent. A script that was not sent keeps the
// hash it had, so a correction to the text alone needs no contents.
func scriptHashes(p Parsed, scripts map[string]string, kept []Script) ([]Script, error) {
	sent := map[string]string{}
	for path, content := range scripts {
		c, err := ScriptPath(path)
		if err != nil {
			return nil, err
		}
		sent[c] = content
	}
	var out []Script
	for _, path := range p.Scripts {
		content, ok := sent[path]
		if !ok {
			if i := slices.IndexFunc(kept, func(k Script) bool { return k.Path == path }); i >= 0 {
				out = append(out, kept[i])
				continue
			}
			return nil, fmt.Errorf("send the contents of %s in scripts, so its hash is kept and a change to it is noticed", path)
		}
		if err := ValidateScript(path, content); err != nil {
			return nil, err
		}
		out = append(out, Script{Path: path, Sha256: Hash(content)})
		delete(sent, path)
	}
	for path := range sent {
		return nil, fmt.Errorf("%s is not listed under scripts in the front matter", path)
	}
	return out, nil
}

// Latest is the version in use.
func (s Skill) Latest() Version { return s.Versions[len(s.Versions)-1] }

const indexKey = "skills/index"

func skillKey(name string) string { return "skills/" + name }

// Library keeps skills in a KV. All changes go through one lock.
type Library struct {
	kv KV
	mu sync.Mutex
}

func NewLibrary(kv KV) *Library { return &Library{kv: kv} }

var (
	ErrNotFound = errors.New("no such skill")
	ErrExists   = errors.New("a skill with that name already exists")
)

func (l *Library) names() ([]string, error) {
	b, err := l.kv.Get(indexKey)
	if err != nil || b == nil {
		return nil, err
	}
	var names []string
	return names, json.Unmarshal(b, &names)
}

func (l *Library) get(name string) (Skill, error) {
	b, err := l.kv.Get(skillKey(name))
	if err != nil {
		return Skill{}, err
	}
	if b == nil {
		return Skill{}, ErrNotFound
	}
	var s Skill
	return s, json.Unmarshal(b, &s)
}

func (l *Library) put(s Skill, now int64) error {
	s.UpdatedM = now
	b, err := json.Marshal(s)
	if err != nil {
		return err
	}
	if err := l.kv.Put(skillKey(s.Name), b); err != nil {
		return err
	}
	names, err := l.names()
	if err != nil {
		return err
	}
	for _, n := range names {
		if n == s.Name {
			return nil
		}
	}
	idx, _ := json.Marshal(append(names, s.Name))
	return l.kv.Put(indexKey, idx)
}

// Get returns one skill.
func (l *Library) Get(name string) (Skill, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.get(name)
}

// List returns every skill but the dismissed ones, newest change first.
func (l *Library) List() ([]Skill, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	names, err := l.names()
	if err != nil {
		return nil, err
	}
	var out []Skill
	for _, n := range names {
		s, err := l.get(n)
		if err != nil {
			continue
		}
		if s.Status != statusDismissed {
			out = append(out, s)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].UpdatedM > out[j].UpdatedM })
	return out, nil
}

// Active returns the skills Claude may use.
func (l *Library) Active() ([]Skill, error) {
	all, err := l.List()
	var out []Skill
	for _, s := range all {
		if s.Status == statusActive {
			out = append(out, s)
		}
	}
	return out, err
}

// Propose adds a skill for the owner to approve. A name that is taken, or that
// the owner dismissed, is refused: the same routine isn't proposed twice.
func (l *Library) Propose(md string, mutating bool, source, by string, now int64) (Skill, error) {
	return l.ProposeWith(md, nil, mutating, source, by, now)
}

// ProposeWith is Propose for a skill with scripts: scripts maps each path the
// front matter lists to the script's contents, which are checked and hashed.
func (l *Library) ProposeWith(md string, scripts map[string]string, mutating bool, source, by string, now int64) (Skill, error) {
	p, err := Validate(md)
	if err != nil {
		return Skill{}, err
	}
	s := Skill{Name: p.Name, Status: statusProposed, Mutating: mutating, Source: source,
		Versions: []Version{{N: 1, MD: strings.TrimSpace(md), Note: "first draft", By: by, AtMs: now}}}
	if err := s.declare(p, scripts); err != nil {
		return Skill{}, err
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if _, err := l.get(p.Name); err == nil {
		return Skill{}, ErrExists
	} else if !errors.Is(err, ErrNotFound) {
		return Skill{}, err
	}
	return s, l.put(s, now)
}

// Approve lets Claude use a proposed skill. For a skill whose scripts
// changed, it accepts the scripts as they are now.
func (l *Library) Approve(name string, now int64) (Skill, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	s, err := l.get(name)
	if err != nil {
		return Skill{}, err
	}
	for i, sc := range s.Scripts {
		if h, ok := s.Changed[sc.Path]; ok {
			s.Scripts[i].Sha256 = h
		}
	}
	s.Status, s.Changed = statusActive, nil
	return s, l.put(s, now)
}

// CheckScripts compares the hashes a session computed for a skill's scripts
// with the ones kept, and returns the paths that differ. A difference flags
// the skill for review; hashes that match again clear it.
func (l *Library) CheckScripts(name string, hashes map[string]string, now int64) ([]string, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	s, err := l.get(name)
	if err != nil {
		return nil, err
	}
	if s.Status == statusDismissed {
		return nil, ErrNotFound
	}
	reported := map[string]string{}
	for path, h := range hashes {
		if c, err := ScriptPath(path); err == nil {
			reported[c] = strings.ToLower(strings.TrimSpace(h))
		}
	}
	changed := map[string]string{}
	var paths []string
	for _, sc := range s.Scripts {
		h, ok := reported[sc.Path]
		if !ok {
			// Not reported this time: a change seen before still stands.
			h, ok = s.Changed[sc.Path]
		}
		if ok && h != sc.Sha256 {
			changed[sc.Path] = h
			paths = append(paths, sc.Path)
		}
	}
	if !sameMap(changed, s.Changed) {
		s.Changed = changed
		if len(changed) == 0 {
			s.Changed = nil
		}
		if err := l.put(s, now); err != nil {
			return nil, err
		}
	}
	return paths, nil
}

func sameMap(a, b map[string]string) bool {
	for k, v := range a {
		if bv, ok := b[k]; !ok || bv != v {
			return false
		}
	}
	return len(a) == len(b)
}

// Dismiss refuses a skill. It stays, hidden, so it isn't proposed again.
func (l *Library) Dismiss(name string, now int64) (Skill, error) {
	return l.setStatus(name, statusDismissed, now)
}

func (l *Library) setStatus(name, status string, now int64) (Skill, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	s, err := l.get(name)
	if err != nil {
		return Skill{}, err
	}
	s.Status = status
	return s, l.put(s, now)
}

// Update makes a new version, which is how a skill is corrected. It keeps the
// skill's name and status; a note says why.
func (l *Library) Update(name, md, note, by string, now int64) (Skill, error) {
	return l.UpdateWith(name, md, nil, note, by, now)
}

// UpdateWith is Update for a skill with scripts, sent as in ProposeWith. The
// new hashes replace the old ones, which clears a review for changed scripts.
func (l *Library) UpdateWith(name, md string, scripts map[string]string, note, by string, now int64) (Skill, error) {
	p, err := Validate(md)
	if err != nil {
		return Skill{}, err
	}
	if p.Name != name {
		return Skill{}, fmt.Errorf("the skill is %q; its name can't change", name)
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	s, err := l.get(name)
	if err != nil {
		return Skill{}, err
	}
	if s.Status == statusDismissed {
		return Skill{}, ErrNotFound
	}
	if strings.TrimSpace(md) == s.Latest().MD && scripts == nil {
		return s, nil
	}
	if err := s.declare(p, scripts); err != nil {
		return Skill{}, err
	}
	if strings.TrimSpace(md) == s.Latest().MD {
		return s, l.put(s, now)
	}
	s.Versions = append(s.Versions, Version{N: s.Latest().N + 1, MD: strings.TrimSpace(md), Note: note, By: by, AtMs: now})
	return s, l.put(s, now)
}

// Rollback puts an earlier text back as a new version, so history stays whole.
func (l *Library) Rollback(name string, n int, by string, now int64) (Skill, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	s, err := l.get(name)
	if err != nil {
		return Skill{}, err
	}
	for _, v := range s.Versions {
		if v.N == n {
			p, err := ParseSkill(v.MD)
			if err != nil {
				return Skill{}, err
			}
			// The scripts' hashes stay: the files in the project are whatever
			// they are now, and the next check says whether they still fit.
			s.Description, s.NeedsEnv, s.RunsOn, s.Effect = p.Description, p.NeedsEnv, p.RunsOn, p.Effect
			s.Versions = append(s.Versions, Version{N: s.Latest().N + 1, MD: v.MD, Note: fmt.Sprintf("back to version %d", n), By: by, AtMs: now})
			return s, l.put(s, now)
		}
	}
	return Skill{}, fmt.Errorf("the skill has no version %d", n)
}
