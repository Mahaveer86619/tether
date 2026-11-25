package hub

import (
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"strings"
	"time"

	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/skills"
)

// Finding a skill, asking for a task by one, and the rules for skills that
// run scripts. See docs/plans/prompt-desk.md#skills-found-and-run.

const skillSearchMax = 20

type skillHit struct {
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Score       float64 `json:"score"`
	Reason      string  `json:"reason"`
	Version     int     `json:"version"`
	Effect      string  `json:"effect,omitempty"`
	Review      bool    `json:"review,omitempty"`
}

func (h *Hub) skillUseRoutes(mux *http.ServeMux) {
	// GET /api/v1/skills/search?q= ranks the approved skills for a search box.
	mux.HandleFunc("GET /api/v1/skills/search", h.authed(func(w http.ResponseWriter, r *http.Request) {
		active, err := h.lib().Active()
		if err != nil {
			writeError(w, internalError(err))
			return
		}
		out := []skillHit{}
		for _, m := range skills.Search(r.URL.Query().Get("q"), active, skillSearchMax) {
			out = append(out, skillHit{Name: m.Skill.Name, Description: m.Skill.Description, Score: math.Round(m.Score*1000) / 1000,
				Reason: m.Reason(), Version: m.Skill.Latest().N, Effect: m.Skill.Effect, Review: m.Skill.NeedsReview()})
		}
		writePlainJSON(w, map[string]any{"results": out})
	}))
}

// decodeWithSkill decodes a proto body and the plain "skill" field beside it:
// the name of a skill the user picked to do the message with.
func decodeWithSkill(r *http.Request, m proto.Message) (string, *opError) {
	body, err := io.ReadAll(io.LimitReader(r.Body, maxBody))
	if err != nil {
		return "", invalid("could not read body")
	}
	if len(body) == 0 {
		return "", nil
	}
	if err := jsonIn.Unmarshal(body, m); err != nil {
		return "", invalid("malformed JSON: " + err.Error())
	}
	var extra struct {
		Skill string `json:"skill"`
	}
	_ = json.Unmarshal(body, &extra)
	return strings.TrimSpace(extra.Skill), nil
}

// skillTurn is what a session is told when the user asks for a task by
// skill: follow this skill, this version, to do the request. "" for no skill.
func (h *Hub) skillTurn(name, request string) (string, *opError) {
	if name == "" {
		return "", nil
	}
	s, err := h.lib().Get(name)
	if err != nil || s.Status != "active" {
		return "", invalid(fmt.Sprintf("no approved skill called %q", name))
	}
	v := s.Latest()
	return fmt.Sprintf("The user asked for this by skill. Use the skill %q (version %d) exactly to do: %s\n\n"+
		"Follow its steps in order rather than finding another way. If a step fails or is wrong, say so, and fix the skill with update_skill.\n\n"+
		"The skill (version %d):\n\n%s%s", s.Name, v.N, clip(strings.TrimSpace(request), 2000), v.N, v.MD, scriptNote(s)), nil
}

// withSkill adds the skill to follow to the system prompt, or to the message
// itself for an agent too old to take a system prompt.
func withSkill(system, text, use string) (string, string) {
	switch {
	case use == "":
		return system, text
	case system == "":
		return system, use + "\n\n---\n\n" + text
	default:
		return system + "\n\n" + use, text
	}
}

// scriptNote is what a session must know before it runs a skill's scripts.
func scriptNote(s skills.Skill) string {
	if len(s.Scripts) == 0 && len(s.NeedsEnv) == 0 && s.Effect == "" {
		return ""
	}
	var b strings.Builder
	b.WriteString("\n\n---\nRunning this skill (from Tether, not part of the skill's text):\n")
	if len(s.Scripts) > 0 {
		b.WriteString("- Its scripts live in the project, at these paths relative to the project folder:")
		for _, sc := range s.Scripts {
			b.WriteString(" " + sc.Path)
		}
		b.WriteString(". Before the first run in a session, compute each script's sha256 (sha256sum, or Get-FileHash on Windows) and call check_skill_scripts with them. " +
			"If one changed, show the user what changed and ask before running it.\n")
	}
	if s.NeedsEnv != nil {
		b.WriteString("- It needs these environment variables: " + strings.Join(s.NeedsEnv, ", ") + ". They come from the project's .env (Tether's sealed project files, on devices the user allowed) or the device's own environment. " +
			"Never print their values, and never write them into the skill, a script or the chat.\n")
	}
	if s.RunsOn != "" && s.RunsOn != "any" {
		b.WriteString("- It runs on " + s.RunsOn + ". On another machine, hand it to a session there.\n")
	}
	switch s.Effect {
	case skills.EffectWrite:
		b.WriteString("- effect: write. It changes data: ask the user before every run, saying what it will change and where.\n")
	case skills.EffectRead:
		b.WriteString("- effect: read. Before its first run on a device, if it reaches production, show the user the command and its target (host and database or service, never a credential) and wait for their go-ahead.\n")
	}
	if s.NeedsReview() {
		b.WriteString("- A script changed since the user approved the skill; it waits for their review in the Tether app. Ask before running it.\n")
	}
	return b.String()
}

func (h *Hub) mcpCheckSkillScripts(args map[string]any) (string, error) {
	name := str(args, "name")
	raw, _ := args["hashes"].(map[string]any)
	hashes := map[string]string{}
	for p, v := range raw {
		if s, ok := v.(string); ok {
			hashes[p] = s
		}
	}
	s, err := h.lib().Get(name)
	if err != nil || s.Status != "active" {
		return "", fmt.Errorf("no approved skill called %q", name)
	}
	if len(s.Scripts) == 0 {
		return name + " has no scripts.", nil
	}
	changed, err := h.lib().CheckScripts(name, hashes, time.Now().UnixMilli())
	if err != nil {
		return "", err
	}
	var missing []string
	for _, sc := range s.Scripts {
		if _, ok := hashes[sc.Path]; !ok {
			missing = append(missing, sc.Path)
		}
	}
	var b strings.Builder
	if len(changed) > 0 {
		h.mu.Lock()
		h.audit(mcpSource, "skill", "scripts changed", name, true)
		h.mu.Unlock()
		b.WriteString("Changed since the user approved the skill: " + strings.Join(changed, ", ") +
			". The skill is flagged for their review in the Tether app. Do not run a changed script until the user has seen the change and agreed.")
	} else {
		b.WriteString("The scripts match the approved ones.")
	}
	if len(missing) > 0 {
		b.WriteString(" Not checked: " + strings.Join(missing, ", ") + "; send their hashes too.")
	}
	return b.String(), nil
}

// scriptsArg reads the scripts a session sent with a skill: path to contents.
func scriptsArg(args map[string]any) map[string]string {
	raw, ok := args["scripts"].(map[string]any)
	if !ok {
		return nil
	}
	out := map[string]string{}
	for p, v := range raw {
		if s, ok := v.(string); ok {
			out[p] = s
		}
	}
	return out
}

// draftFromItem starts a session that writes a skill from the task around
// one item of a session: the user's request and the tool calls after it.
func (h *Hub) draftFromItem(session, item string) (string, *opError) {
	h.mu.Lock()
	info := h.sessions[session]
	h.mu.Unlock()
	if info == nil {
		return "", errNotFound
	}
	items, _, err := h.store.ItemsAfter(session, 0)
	if err != nil {
		return "", internalError(err)
	}
	t, ok := skills.TaskAt(skills.Meta{Session: info.Id, Node: info.Node, Cwd: info.Cwd}, items, item)
	if !ok {
		return "", &opError{"not_found", "that message is not part of a task", http.StatusNotFound}
	}
	if len(t.Steps) == 0 {
		return "", invalid("nothing was run for that request, so there is no routine to keep")
	}
	return h.startDraft(skills.FromTask(t))
}

// startDraft starts the drafting session. A routine that runs a script is
// drafted in its project, so the script can be written there; anything else
// is drafted on the hub from the brief alone.
func (h *Hub) startDraft(c skills.Candidate) (string, *opError) {
	h.mu.Lock()
	defer h.mu.Unlock()
	name := "Skill: " + clip(c.Example, 50)
	if skills.IsScript(c) && len(c.Nodes) > 0 && len(c.Cwds) > 0 && h.agents[c.Nodes[0]] != nil {
		cs := &v1.CreateSession{Node: c.Nodes[0], Cwd: c.Cwds[0], Prompt: skills.DraftBrief(c, skills.DraftInProject), Name: name}
		return h.startSession(cs, "Routines", startExtra{})
	}
	cs := &v1.CreateSession{Prompt: skills.DraftBrief(c, skills.DraftOnHub), Scratch: true, Name: name}
	return h.startSession(cs, "Routines", startExtra{})
}
