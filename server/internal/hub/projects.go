package hub

import (
	"encoding/json"
	"io"
	"net/http"
	"sort"
	"strings"
	"time"
)

// Projects: named groups of folders (a device and a path each) that chats
// belong to. A chat's project is kept beside the chat, not in the Chat
// message, so the wire contract stays as it is; the app merges the two. See
// docs/architecture/chats.md#projects.

const (
	projectsKey     = "projects"
	chatProjectsKey = "chat_projects"
	maxProjectName  = 80
)

type projectFolder struct {
	Node string `json:"node"`
	Cwd  string `json:"cwd"`
}

type project struct {
	ID        string          `json:"id"`
	Name      string          `json:"name"`
	Folders   []projectFolder `json:"folders"`
	CreatedMs int64           `json:"createdMs"`
	Chats     []string        `json:"chats"`
	Owner     string          `json:"owner,omitempty"`
}

var errProjectNotFound = &opError{"not_found", "no such project", http.StatusNotFound}

// projectList returns every project, oldest first, without its chats.
// Caller holds h.mu.
func (h *Hub) projectList() []project {
	var out []project
	if b, err := h.store.Get(projectsKey); err == nil && b != nil {
		_ = json.Unmarshal(b, &out)
	}
	return out
}

func (h *Hub) saveProjects(list []project) *opError {
	for i := range list {
		list[i].Chats = nil
	}
	return h.putJSON(projectsKey, list)
}

// chatProjects maps a chat to its project. Caller holds h.mu.
func (h *Hub) chatProjects() map[string]string {
	out := map[string]string{}
	if b, err := h.store.Get(chatProjectsKey); err == nil && b != nil {
		_ = json.Unmarshal(b, &out)
	}
	return out
}

func (h *Hub) putJSON(key string, v any) *opError {
	b, err := json.Marshal(v)
	if err == nil {
		err = h.store.Put(key, b)
	}
	if err != nil {
		return internalError(err)
	}
	return nil
}

func findProject(list []project, id string) int {
	for i := range list {
		if list[i].ID == id {
			return i
		}
	}
	return -1
}

// setChatProject puts a chat in a project, or makes it a one-off when
// project is "". Caller holds h.mu.
func (h *Hub) setChatProject(chat, project string) *opError {
	if h.chats[chat] == nil {
		return errChatNotFound
	}
	if project != "" && findProject(h.projectList(), project) < 0 {
		return errProjectNotFound
	}
	m := h.chatProjects()
	if project == "" {
		delete(m, chat)
	} else {
		m[chat] = project
	}
	return h.putJSON(chatProjectsKey, m)
}

// forgetChatProject drops a deleted chat's project. Caller holds h.mu.
func (h *Hub) forgetChatProject(chat string) {
	m := h.chatProjects()
	if _, ok := m[chat]; !ok {
		return
	}
	delete(m, chat)
	if err := h.putJSON(chatProjectsKey, m); err != nil {
		h.log.Error("forget chat project", "chat", chat, "err", err.Message)
	}
}

// chatFolder is where a chat works: its active session's folder, else its
// target's. Caller holds h.mu.
func (h *Hub) chatFolder(id string) projectFolder {
	c := h.chats[id]
	if c == nil {
		return projectFolder{}
	}
	if s := h.sessions[c.ActiveSession]; s != nil && s.Node != "" && s.Cwd != "" && !s.Scratch {
		return projectFolder{s.Node, s.Cwd}
	}
	if t := c.GetTarget(); t != nil && !t.Scratch {
		return projectFolder{t.Node, t.Cwd}
	}
	return projectFolder{}
}

func sameFolder(a, b projectFolder) bool {
	return a.Node == b.Node && a.Cwd != "" && normPath(a.Cwd) == normPath(b.Cwd)
}

// fileChats puts the chats that work in one of the project's folders and
// are in no project yet into it, so making a folder a project brings its
// chats along. Caller holds h.mu.
func (h *Hub) fileChats(p project) *opError {
	m := h.chatProjects()
	changed := false
	for id, c := range h.chats {
		if m[id] != "" || h.chatOwner(c) != firstNonEmpty(p.Owner, h.ownerID) {
			continue
		}
		f := h.chatFolder(id)
		for _, pf := range p.Folders {
			if sameFolder(f, pf) {
				m[id] = p.ID
				changed = true
				break
			}
		}
	}
	if !changed {
		return nil
	}
	return h.putJSON(chatProjectsKey, m)
}

func checkProject(in *project) *opError {
	in.Name = strings.TrimSpace(in.Name)
	kept := in.Folders[:0]
	for _, f := range in.Folders {
		f.Node, f.Cwd = strings.TrimSpace(f.Node), strings.TrimSpace(f.Cwd)
		if f.Node == "" || f.Cwd == "" {
			return invalid("a project folder needs its device and path")
		}
		dup := false
		for _, k := range kept {
			dup = dup || sameFolder(k, f)
		}
		if !dup {
			kept = append(kept, f)
		}
	}
	in.Folders = kept
	if in.Name == "" && len(in.Folders) > 0 {
		in.Name = labelOf(in.Folders[0].Cwd)
	}
	if in.Name == "" {
		return invalid("a project needs a name or a folder")
	}
	if len([]rune(in.Name)) > maxProjectName {
		in.Name = string([]rune(in.Name)[:maxProjectName])
	}
	return nil
}

// projectsWithChats is every project with the ids of its chats, oldest
// first. Caller holds h.mu.
// projectsWithChats is id's projects, each with the chats in it id may see.
func (h *Hub) projectsWithChats(id identity) []project {
	var list []project
	for _, p := range h.projectList() {
		if h.can(id, actManage, objProject, p.ID) {
			list = append(list, p)
		}
	}
	byProject := map[string][]string{}
	for chat, p := range h.chatProjects() {
		if h.chats[chat] != nil && h.can(id, actView, objChat, chat) {
			byProject[p] = append(byProject[p], chat)
		}
	}
	for i := range list {
		list[i].Chats = byProject[list[i].ID]
		if list[i].Chats == nil {
			list[i].Chats = []string{}
		}
		sort.Strings(list[i].Chats)
		if list[i].Folders == nil {
			list[i].Folders = []projectFolder{}
		}
	}
	if list == nil {
		list = []project{}
	}
	return list
}

func decodePlain(r *http.Request, v any) *opError {
	if json.NewDecoder(io.LimitReader(r.Body, maxBody)).Decode(v) != nil {
		return invalid("malformed JSON")
	}
	return nil
}

// plainAPI is api for handlers that answer plain JSON rather than a proto
// message.
func (h *Hub) plainAPI(fn func(*http.Request) (any, *opError)) http.HandlerFunc {
	return h.authed(func(w http.ResponseWriter, r *http.Request) {
		h.mu.Lock()
		v, err := fn(r)
		h.mu.Unlock()
		if err != nil {
			writeError(w, err)
			return
		}
		writePlainJSON(w, v)
	})
}

func (h *Hub) projectRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/projects", h.plainAPI(func(r *http.Request) (any, *opError) {
		return map[string]any{"projects": h.projectsWithChats(userOf(r))}, nil
	}))
	mux.HandleFunc("POST /api/v1/projects", h.plainAPI(func(r *http.Request) (any, *opError) {
		var in project
		if err := decodePlain(r, &in); err != nil {
			return nil, err
		}
		if err := checkProject(&in); err != nil {
			return nil, err
		}
		in.ID, in.CreatedMs, in.Owner = newRuleID(), time.Now().UnixMilli(), firstNonEmpty(userOf(r).userID(), h.ownerID)
		if err := h.saveProjects(append(h.projectList(), in)); err != nil {
			return nil, err
		}
		return h.answerProject(in)
	}))
	mux.HandleFunc("PUT /api/v1/projects/{id}", h.plainAPI(func(r *http.Request) (any, *opError) {
		var in project
		if err := decodePlain(r, &in); err != nil {
			return nil, err
		}
		list := h.projectList()
		i := findProject(list, r.PathValue("id"))
		if i < 0 {
			return nil, errProjectNotFound
		}
		if in.Folders == nil {
			in.Folders = list[i].Folders
		}
		if err := checkProject(&in); err != nil {
			return nil, err
		}
		in.ID, in.CreatedMs, in.Owner = list[i].ID, list[i].CreatedMs, list[i].Owner
		list[i] = in
		if err := h.saveProjects(list); err != nil {
			return nil, err
		}
		return h.answerProject(in)
	}))
	mux.HandleFunc("POST /api/v1/projects/{id}/folders", h.plainAPI(func(r *http.Request) (any, *opError) {
		var f projectFolder
		if err := decodePlain(r, &f); err != nil {
			return nil, err
		}
		list := h.projectList()
		i := findProject(list, r.PathValue("id"))
		if i < 0 {
			return nil, errProjectNotFound
		}
		p := list[i]
		p.Folders = append(append([]projectFolder{}, p.Folders...), f)
		if err := checkProject(&p); err != nil {
			return nil, err
		}
		list[i] = p
		if err := h.saveProjects(list); err != nil {
			return nil, err
		}
		return h.answerProject(p)
	}))
	// Deleting a project makes its chats one-offs; the chats themselves stay.
	mux.HandleFunc("DELETE /api/v1/projects/{id}", h.plainAPI(func(r *http.Request) (any, *opError) {
		id := r.PathValue("id")
		list := h.projectList()
		i := findProject(list, id)
		if i < 0 {
			return nil, errProjectNotFound
		}
		if err := h.saveProjects(append(list[:i], list[i+1:]...)); err != nil {
			return nil, err
		}
		m := h.chatProjects()
		for chat, p := range m {
			if p == id {
				delete(m, chat)
			}
		}
		if err := h.putJSON(chatProjectsKey, m); err != nil {
			return nil, err
		}
		return map[string]bool{"ok": true}, nil
	}))
	mux.HandleFunc("PUT /api/v1/chats/{id}/project", h.plainAPI(func(r *http.Request) (any, *opError) {
		var in struct {
			Project string `json:"project"`
		}
		if err := decodePlain(r, &in); err != nil {
			return nil, err
		}
		if in.Project != "" && !h.can(userOf(r), actManage, objProject, in.Project) {
			return nil, errProjectNotFound
		}
		if err := h.setChatProject(r.PathValue("id"), in.Project); err != nil {
			return nil, err
		}
		return map[string]string{"chat": r.PathValue("id"), "project": in.Project}, nil
	}))
	mux.HandleFunc("GET /api/v1/chat-projects", h.plainAPI(func(r *http.Request) (any, *opError) {
		out := map[string]string{}
		for chat, p := range h.chatProjects() {
			if h.chats[chat] != nil && h.can(userOf(r), actView, objChat, chat) {
				out[chat] = p
			}
		}
		return map[string]any{"chats": out}, nil
	}))
}

// answerProject files the project's folders' loose chats into it and returns
// it with its chats. Caller holds h.mu.
func (h *Hub) answerProject(p project) (any, *opError) {
	if err := h.fileChats(p); err != nil {
		return nil, err
	}
	for _, x := range h.projectsWithChats(h.asUser(firstNonEmpty(p.Owner, h.ownerID))) {
		if x.ID == p.ID {
			return x, nil
		}
	}
	return nil, errProjectNotFound
}
