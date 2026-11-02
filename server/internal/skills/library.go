package skills

import (
	"encoding/json"
	"errors"
	"fmt"
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
	p, err := Validate(md)
	if err != nil {
		return Skill{}, err
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if _, err := l.get(p.Name); err == nil {
		return Skill{}, ErrExists
	} else if !errors.Is(err, ErrNotFound) {
		return Skill{}, err
	}
	s := Skill{Name: p.Name, Description: p.Description, Status: statusProposed, Mutating: mutating, Source: source,
		Versions: []Version{{N: 1, MD: strings.TrimSpace(md), Note: "first draft", By: by, AtMs: now}}}
	return s, l.put(s, now)
}

// Approve lets Claude use a proposed skill.
func (l *Library) Approve(name string, now int64) (Skill, error) {
	return l.setStatus(name, statusActive, now)
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
	if strings.TrimSpace(md) == s.Latest().MD {
		return s, nil
	}
	s.Description = p.Description
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
			s.Description = p.Description
			s.Versions = append(s.Versions, Version{N: s.Latest().N + 1, MD: v.MD, Note: fmt.Sprintf("back to version %d", n), By: by, AtMs: now})
			return s, l.put(s, now)
		}
	}
	return Skill{}, fmt.Errorf("the skill has no version %d", n)
}
