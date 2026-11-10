package hub

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

// Remote chats: a chat's project folder is kept in step on two devices
// through the hub's git repository for it. See docs/plans/remote-projects.md.
//
// One device writes at a time (the source: where the chat's active session
// runs). After each turn its folder is pushed, and the other device (the
// mirror) pulls. Making a chat remote pushes the folder, pulls it on the
// mirror and moves the chat there, which makes the mirror the writer.

const (
	remotePending = "pending"
	remoteSyncing = "syncing"
	remoteSynced  = "synced"
	remoteFailed  = "failed"
)

// secretPaths stay out of the repository; the vault serves them instead.
var secretPaths = []string{".env", ".env.*"}

// isProjectFolder says whether a folder is somewhere a project lives, rather
// than a home folder, a folder Tether or a tool keeps for itself, or nothing.
func isProjectFolder(cwd string) bool {
	cwd = strings.TrimSpace(cwd)
	return cwd != "" && !notAProject(cwd) && !homeFolder.MatchString(strings.TrimRight(strings.ReplaceAll(cwd, `\`, "/"), "/"))
}

// isProject is a variable so tests can use the temporary folders of the machine they run on.
var isProject = isProjectFolder

var notRepoChar = regexp.MustCompile(`[^a-z0-9]+`)

// repoName is a repository id for a project folder on a node: its name, and
// a few characters of where it is, so two folders with one name do not meet.
func repoName(node, cwd string) string {
	name := strings.Trim(notRepoChar.ReplaceAllString(strings.ToLower(baseOf(cwd)), "-"), "-")
	if name == "" {
		name = "project"
	}
	if len(name) > 40 {
		name = name[:40]
	}
	sum := sha256.Sum256([]byte(node + "|" + normPath(cwd)))
	return name + "-" + hex.EncodeToString(sum[:3])
}

func (h *Hub) remoteRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/chats/{id}/remote", h.authed(func(w http.ResponseWriter, r *http.Request) {
		h.mu.Lock()
		defer h.mu.Unlock()
		rem, ok, err := h.store.ChatRemote(r.PathValue("id"))
		if err != nil {
			writeError(w, &opError{"internal", err.Error(), http.StatusInternalServerError})
			return
		}
		if !ok {
			writeJSONPlain(w, http.StatusOK, map[string]any{"on": false})
			return
		}
		writeJSONPlain(w, http.StatusOK, map[string]any{"on": true, "remote": rem})
	}))
	mux.HandleFunc("POST /api/v1/chats/{id}/remote", h.authed(func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			On   bool   `json:"on"`
			Node string `json:"node"`
		}
		if json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBody)).Decode(&in) != nil {
			writeError(w, invalid("malformed JSON"))
			return
		}
		h.mu.Lock()
		defer h.mu.Unlock()
		var err *opError
		if in.On {
			err = h.makeRemote(r.PathValue("id"), in.Node, clientName(r))
		} else {
			err = h.stopRemote(r.PathValue("id"))
		}
		if err != nil {
			writeError(w, err)
			return
		}
		writeJSONPlain(w, http.StatusAccepted, map[string]any{"ok": true})
	}))
}

func writeJSONPlain(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// makeRemote starts making a chat remote: it pushes the chat's folder, has
// mirrorNode pull it, and moves the chat there. It answers at once; the rest
// happens as the agents report. Caller holds h.mu.
func (h *Hub) makeRemote(chat, mirrorNode, from string) *opError {
	c := h.chats[chat]
	if c == nil {
		return errChatNotFound
	}
	if _, on, _ := h.store.ChatRemote(chat); on {
		return invalid("this chat is already remote")
	}
	s := h.sessions[c.ActiveSession]
	if s == nil || s.Node == "" || !isProject(s.Cwd) || s.Scratch {
		return invalid("only a chat that works in a project folder can be made remote")
	}
	if mirrorNode == "" || mirrorNode == s.Node {
		return invalid("pick another device to move it to")
	}
	if h.agents[s.Node] == nil {
		return errNodeOffline
	}
	if h.agents[mirrorNode] == nil {
		return invalid(mirrorNode + " is not online")
	}
	repo := repoName(s.Node, s.Cwd)
	if _, err := h.ensureRepo(repo); err != nil {
		h.log.Warn("repo", "repo", repo, "err", err)
		return &opError{"internal", "could not make the repository on the hub: " + err.Error(), http.StatusInternalServerError}
	}
	rem := store.ChatRemote{
		Chat: chat, Repo: repo, Branch: "chat-" + chat,
		SourceNode: s.Node, SourceCwd: s.Cwd, MirrorNode: mirrorNode, MirrorCwd: h.mirrorFolder(mirrorNode, s.Cwd),
		State: remotePending,
	}
	h.saveRemote(rem)
	h.syncChain(rem, func(done store.ChatRemote) {
		// Both copies match: the mirror takes over the work.
		target := &v1.ChatTarget{Mode: targetManual, State: targetResolved, Node: done.MirrorNode, Cwd: done.MirrorCwd, Reason: "remote: the project is kept in step on both"}
		c := h.chats[chat]
		if c == nil {
			return
		}
		prev := c.Target
		c.Target = target
		if _, err := h.moveChat(c, target, "", nil, from, ""); err != nil {
			c.Target = prev
			done.State, done.Error = remoteFailed, "moving the chat: "+err.Message
			h.saveRemote(done)
			return
		}
		c.UpdatedMs = time.Now().UnixMilli()
		h.putChat(c)
		done.SourceNode, done.SourceCwd, done.MirrorNode, done.MirrorCwd = done.MirrorNode, done.MirrorCwd, done.SourceNode, done.SourceCwd
		h.saveRemote(done)
	})
	return nil
}

// stopRemote stops keeping a chat's folders in step; both copies stay where they are.
func (h *Hub) stopRemote(chat string) *opError {
	if _, on, _ := h.store.ChatRemote(chat); !on {
		return nil
	}
	if err := h.store.DeleteChatRemote(chat); err != nil {
		return &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	return nil
}

// mirrorFolder is where a project goes on a device: under its workspace
// root if it has one, otherwise left to the agent.
func (h *Hub) mirrorFolder(node, cwd string) string {
	for _, r := range h.workspaces().Roots {
		if r.Node == node && r.Path != "" {
			sep := "/"
			if strings.Contains(r.Path, `\`) {
				sep = `\`
			}
			return strings.TrimRight(r.Path, `/\`) + sep + baseOf(cwd)
		}
	}
	return ""
}

func (h *Hub) saveRemote(r store.ChatRemote) {
	if err := h.store.PutChatRemote(r); err != nil {
		h.log.Error("store chat remote", "chat", r.Chat, "err", err)
	}
}

// syncChain pushes from the source, then pulls on the mirror, recording
// each step, and calls done with the result when both went well. Caller
// holds h.mu.
func (h *Hub) syncChain(rem store.ChatRemote, done func(store.ChatRemote)) {
	fail := func(msg string) {
		rem.State, rem.Error = remoteFailed, msg
		h.saveRemote(rem)
	}
	rem.State, rem.Error = remoteSyncing, ""
	h.saveRemote(rem)
	h.syncStep(rem.SourceNode, &v1.AgentCommand_SyncProject{Chat: rem.Chat, Direction: "push", Cwd: rem.SourceCwd, Repo: rem.Repo, Branch: rem.Branch, Exclude: secretPaths}, func(res *v1.SyncResult) {
		if !res.Ok {
			fail(rem.SourceNode + ": " + res.Error)
			return
		}
		h.syncStep(rem.MirrorNode, &v1.AgentCommand_SyncProject{Chat: rem.Chat, Direction: "pull", Cwd: rem.MirrorCwd, Repo: rem.Repo, Branch: rem.Branch, Exclude: secretPaths}, func(res *v1.SyncResult) {
			if !res.Ok {
				fail(rem.MirrorNode + ": " + res.Error)
				return
			}
			rem.MirrorCwd, rem.State, rem.Error, rem.SyncedMs = res.Cwd, remoteSynced, "", time.Now().UnixMilli()
			h.saveRemote(rem)
			if done != nil {
				done(rem)
			}
		})
	})
}

// syncStep sends a sync command to a node and calls next with its answer.
// A node that is not connected is an answer too.
func (h *Hub) syncStep(node string, cmd *v1.AgentCommand_SyncProject, next func(*v1.SyncResult)) {
	agent := h.agents[node]
	if agent == nil {
		next(&v1.SyncResult{Chat: cmd.Chat, Direction: cmd.Direction, Error: "not connected"})
		return
	}
	cmd.Id = uuid.NewString()
	if h.syncWait == nil {
		h.syncWait = map[string]func(*v1.SyncResult){}
	}
	h.syncWait[cmd.Id] = next
	agent.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_SyncProject_{SyncProject: proto.Clone(cmd).(*v1.AgentCommand_SyncProject)}}))
	time.AfterFunc(syncTimeout, func() {
		h.mu.Lock()
		defer h.mu.Unlock()
		if f, ok := h.syncWait[cmd.Id]; ok {
			delete(h.syncWait, cmd.Id)
			f(&v1.SyncResult{Chat: cmd.Chat, Direction: cmd.Direction, Error: "no answer from " + node})
		}
	})
}

const syncTimeout = 5 * time.Minute

// noteSyncResult hands a node's answer to whoever asked. Caller holds h.mu.
func (h *Hub) noteSyncResult(res *v1.SyncResult) {
	if f, ok := h.syncWait[res.Id]; ok {
		delete(h.syncWait, res.Id)
		f(res)
	}
}

// syncAfterTurn keeps a remote chat's copies in step once its session ends a
// turn: the writer's folder goes up and the other device's comes down. Caller
// holds h.mu.
func (h *Hub) syncAfterTurn(chat string) {
	rem, on, err := h.store.ChatRemote(chat)
	if err != nil || !on || rem.State == remoteSyncing || rem.State == remotePending {
		return
	}
	h.syncChain(rem, nil)
}
