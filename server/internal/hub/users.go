package hub

import (
	"errors"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Users, invites and who may do what. See docs/architecture/security.md#users
// and docs/plans/teams.md#b-users-and-workspaces.

const (
	roleAdmin  = "admin"
	roleMember = "member"

	accessFull = "full"
	accessJobs = "jobs"

	shareRead        = "read"
	shareCollaborate = "collaborate"

	inviteTTL = 24 * time.Hour
)

type action int

const (
	actView action = iota
	// Send into it, answer its approvals.
	actUse
	// Interrupt or stop it.
	actStop
	// Rename, delete, share, change its settings.
	actManage
	// Start a Claude Code session on a node.
	actRunClaude
	// Start a job (a plain process) on a node.
	actRunJob
	// Hub-wide settings, users and invites.
	actAdmin
)

type objKind int

const (
	objHub objKind = iota
	objNode
	objSession
	objChat
	objApproval
	objArtifact
	objProject
	objJob
)

var (
	errForbidden  = &opError{"forbidden", "you do not have access to this", http.StatusForbidden}
	errNameTaken  = &opError{"name_taken", "another user has a device with this name", http.StatusConflict}
	errUnknownUsr = &opError{"not_found", "unknown user", http.StatusNotFound}
)

type invite struct {
	expires time.Time
	by      string
}

// loadUsers reads the users and grants, making the hub's owner the first
// user when there is none yet and giving them everything from before.
// Called by New.
func (h *Hub) loadUsers() error {
	users, err := h.store.Users()
	if err != nil {
		return err
	}
	if len(users) == 0 {
		owner := &v1.User{Id: uuid.NewString(), Name: "Owner", Role: roleAdmin, CreatedMs: time.Now().UnixMilli()}
		if err := h.store.PutUser(owner); err != nil {
			return err
		}
		users = []*v1.User{owner}
		if err := h.giveToOwner(owner.Id); err != nil {
			return err
		}
	}
	h.ownerID = users[0].Id
	for _, u := range users {
		h.users[u.Id] = u
	}
	grants, err := h.store.Grants()
	if err != nil {
		return err
	}
	h.grants = grants
	return nil
}

// giveToOwner is the one-time migration to users: every device, chat,
// session, notification and artifact so far is the owner's.
func (h *Hub) giveToOwner(owner string) error {
	for hash, d := range h.devices {
		if d.User == "" {
			d.User = owner
			if err := h.store.PutDevice(d, hash); err != nil {
				return err
			}
		}
	}
	for _, c := range h.chats {
		if c.Owner == "" {
			c.Owner = owner
			if err := h.store.PutChat(c); err != nil {
				return err
			}
		}
	}
	for _, s := range h.sessions {
		if s.Owner == "" {
			s.Owner = owner
			if err := h.store.PutSession(s); err != nil {
				return err
			}
		}
	}
	list := h.projectList()
	for i := range list {
		if list[i].Owner == "" {
			list[i].Owner = owner
		}
	}
	if len(list) > 0 {
		if err := h.saveProjects(list); err != nil {
			return err
		}
	}
	return h.store.GiveUnowned(owner)
}

func (id identity) userID() string {
	if id.user == nil {
		return ""
	}
	return id.user.Id
}

// root is the admin token: recovery and tetherctl, allowed everything.
func (id identity) root() bool { return id.kind == kindAdmin }

// userOf is the identity the guard put on a request.
func userOf(r *http.Request) identity {
	id, _ := r.Context().Value(identityKey{}).(identity)
	return id
}

// nodeOwner is the user whose machine a node is: whoever paired its agent,
// or the hub's owner for one that connects with the admin token or over
// the trusted tailnet. Caller holds h.mu.
func (h *Hub) nodeOwner(node string) string {
	for _, d := range h.devices {
		if d.Kind == kindNode && d.Name == node && d.User != "" {
			return d.User
		}
	}
	return h.ownerID
}

func (h *Hub) sessionOwner(s *v1.SessionInfo) string {
	if s.Owner != "" {
		return s.Owner
	}
	return h.nodeOwner(s.Node)
}

func (h *Hub) chatOwner(c *v1.Chat) string {
	return firstNonEmpty(c.Owner, h.ownerID)
}

func shareOf(c *v1.Chat, user string) string {
	for _, s := range c.Shares {
		if s.User == user {
			return s.Access
		}
	}
	return ""
}

// can is the one permission check: may this identity do act to the object?
// Every REST route (through guard), MCP tool and WebSocket frame goes
// through it, and every list is filtered with it. Caller holds h.mu.
func (h *Hub) can(id identity, act action, kind objKind, obj string) bool {
	if id.root() {
		return true
	}
	u := id.userID()
	if u == "" || h.users[u] == nil {
		return false
	}
	switch kind {
	case objHub:
		return act != actAdmin || h.users[u].Role == roleAdmin
	case objNode:
		if h.nodeOwner(obj) == u {
			return true
		}
		g := h.grants[obj][u]
		switch act {
		case actView, actRunJob:
			return g != nil
		case actRunClaude:
			return g != nil && g.Access == accessFull
		}
		return false
	case objSession:
		s := h.sessions[obj]
		if s == nil {
			return false
		}
		if h.sessionOwner(s) == u {
			return true
		}
		chat := h.chats[h.chatOf[obj]]
		switch act {
		case actView:
			return h.nodeOwner(s.Node) == u || chat != nil && h.can(id, actView, objChat, chat.Id)
		case actStop:
			return h.nodeOwner(s.Node) == u || chat != nil && h.can(id, actUse, objChat, chat.Id)
		case actUse:
			return chat != nil && h.can(id, actUse, objChat, chat.Id)
		}
		return false
	case objChat:
		c := h.chats[obj]
		if c == nil {
			return false
		}
		if h.chatOwner(c) == u {
			return true
		}
		switch act {
		case actView:
			return shareOf(c, u) != ""
		case actUse:
			return shareOf(c, u) == shareCollaborate
		}
		return false
	case objApproval:
		a := h.approvals[obj]
		// Approvals go to whoever asked for the work, not the device's owner.
		return a != nil && (act == actView || act == actUse) && h.can(id, actUse, objSession, a.Session)
	case objArtifact:
		a, err := h.store.Artifact(obj)
		if err != nil || a == nil {
			return false
		}
		return h.canArtifact(id, act, a)
	case objJob:
		j := h.jobs[obj]
		if j == nil {
			return false
		}
		if firstNonEmpty(j.Owner, h.ownerID) == u {
			return true
		}
		// The device's owner sees and can stop everything run on it.
		return act != actManage && h.nodeOwner(j.Spec.GetNode()) == u
	case objProject:
		list := h.projectList()
		i := findProject(list, obj)
		return i >= 0 && firstNonEmpty(list[i].Owner, h.ownerID) == u
	}
	return false
}

func (h *Hub) canArtifact(id identity, act action, a *v1.Artifact) bool {
	if id.root() {
		return true
	}
	if a.Session != "" && h.sessions[a.Session] != nil {
		if act == actView {
			return h.can(id, actView, objSession, a.Session)
		}
		return h.can(id, actUse, objSession, a.Session)
	}
	return firstNonEmpty(a.Owner, h.ownerID) == id.userID()
}

// check is can as an error.
func (h *Hub) check(id identity, act action, kind objKind, obj string) *opError {
	if !h.can(id, act, kind, obj) {
		return errForbidden
	}
	return nil
}

// asUser is the identity a user's own app would have, for work done on
// their behalf (a chat's sessions, the hub's own jobs).
func (h *Hub) asUser(user string) identity {
	return identity{kind: kindClient, user: h.users[user]}
}

// ---- lists, filtered before they are sent ----

func (h *Hub) visibleNodes(id identity) []*v1.NodeStatus {
	var out []*v1.NodeStatus
	for _, n := range h.nodes {
		if h.can(id, actView, objNode, n.Node) {
			out = append(out, h.nodeFor(id, n))
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Node < out[j].Node })
	return out
}

// nodeFor is a node's status as id sees it: its owner, and its grants only
// for the owner.
func (h *Hub) nodeFor(id identity, n *v1.NodeStatus) *v1.NodeStatus {
	n = proto.Clone(n).(*v1.NodeStatus)
	n.Owner = h.nodeOwner(n.Node)
	if id.root() || n.Owner == id.userID() {
		for _, g := range h.grants[n.Node] {
			n.Grants = append(n.Grants, proto.Clone(g).(*v1.DeviceGrant))
		}
		sort.Slice(n.Grants, func(i, j int) bool { return n.Grants[i].GrantedMs < n.Grants[j].GrantedMs })
	}
	return n
}

// chatFor is a chat as id sees it: a person it is shared with sees their
// own share, not everyone's.
func (h *Hub) chatFor(id identity, c *v1.Chat) *v1.Chat {
	c = proto.Clone(c).(*v1.Chat)
	c.Owner = h.chatOwner(c)
	if !id.root() && c.Owner != id.userID() {
		var mine []*v1.ChatShare
		for _, s := range c.Shares {
			if s.User == id.userID() {
				mine = append(mine, s)
			}
		}
		c.Shares = mine
	}
	return c
}

func (h *Hub) userList() []*v1.User {
	out := make([]*v1.User, 0, len(h.users))
	for _, u := range h.users {
		out = append(out, proto.Clone(u).(*v1.User))
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedMs < out[j].CreatedMs })
	return out
}

// frameFor is what client c may see of a broadcast frame: the frame, a
// copy trimmed for them, or nil. Unknown kinds go to the admin token only.
func (h *Hub) frameFor(c *client, f *v1.Frame) *v1.Frame {
	id := c.id
	switch b := f.Body.(type) {
	case *v1.Frame_SessionInfo:
		return h.when(h.can(id, actView, objSession, b.SessionInfo.Id), f)
	case *v1.Frame_SessionRemoved:
		return h.when(h.can(id, actView, objSession, b.SessionRemoved.Session), f)
	case *v1.Frame_NodeStatus:
		if !h.can(id, actView, objNode, b.NodeStatus.Node) {
			return nil
		}
		return &v1.Frame{Body: &v1.Frame_NodeStatus{NodeStatus: h.nodeFor(id, b.NodeStatus)}}
	case *v1.Frame_ApprovalRequested:
		return h.when(h.can(id, actUse, objSession, b.ApprovalRequested.Session), f)
	case *v1.Frame_ApprovalResolved:
		return h.when(h.can(id, actUse, objSession, b.ApprovalResolved.Session), f)
	case *v1.Frame_Chat:
		c := b.Chat
		// A deleted chat is gone from h.chats; its last copy says who saw it.
		seen := h.chats[c.Id] == nil && (id.root() || h.chatOwner(c) == id.userID() || shareOf(c, id.userID()) != "")
		if !seen && !h.can(id, actView, objChat, c.Id) {
			return nil
		}
		return &v1.Frame{Body: &v1.Frame_Chat{Chat: h.chatFor(id, b.Chat)}}
	case *v1.Frame_ArtifactAdded:
		return h.when(h.canArtifact(id, actView, b.ArtifactAdded), f)
	case *v1.Frame_Job:
		j := b.Job
		seen := h.jobs[j.Id] == nil && (id.root() || firstNonEmpty(j.Owner, h.ownerID) == id.userID() || h.nodeOwner(j.Spec.GetNode()) == id.userID())
		return h.when(seen || h.can(id, actView, objJob, j.Id), f)
	case *v1.Frame_Preferences, *v1.Frame_NotifyEndpoint, *v1.Frame_UpdateAvailable:
		return f
	}
	return h.when(id.root(), f)
}

func (h *Hub) when(ok bool, f *v1.Frame) *v1.Frame {
	if ok {
		return f
	}
	return nil
}

// dropAccess makes a change of rights take effect on open connections: the
// user's apps reconnect and get a Welcome with only what they may see now.
// Caller holds h.mu.
var errAccessChanged = errors.New("access changed")

func (h *Hub) dropAccess(user string) {
	for c := range h.clients {
		if c.id.userID() == user && !c.id.root() {
			c.conn.Close(errAccessChanged)
		}
	}
}

// ---- users and invites ----

func (h *Hub) newInvite(by string) (*v1.PairingCode, error) {
	code, err := h.randomCode()
	if err != nil {
		return nil, err
	}
	now := time.Now()
	for c, inv := range h.invites {
		if now.After(inv.expires) {
			delete(h.invites, c)
		}
	}
	exp := now.Add(inviteTTL)
	h.invites[code] = invite{expires: exp, by: by}
	return &v1.PairingCode{Code: code[:codeLen/2] + "-" + code[codeLen/2:], ExpiresMs: exp.UnixMilli(), CertFingerprint: h.cfg.CertFingerprint}, nil
}

// join turns an invite code into a new member. Caller holds h.mu.
func (h *Hub) join(code, name string) (*v1.User, *opError) {
	inv, ok := h.invites[code]
	if !ok || time.Now().After(inv.expires) {
		return nil, errBadCode
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, invalid("an invite needs the name of the person joining")
	}
	delete(h.invites, code)
	u := &v1.User{Id: uuid.NewString(), Name: clip(name, 60), Role: roleMember, CreatedMs: time.Now().UnixMilli()}
	if err := h.store.PutUser(u); err != nil {
		return nil, internalError(err)
	}
	h.users[u.Id] = u
	by := "admin"
	if u := h.users[inv.by]; u != nil {
		by = u.Name
	}
	h.audit(by, "user", "joined", u.Name, true)
	return u, nil
}

// removeUser deletes a member with their devices and the grants made to
// them. What they made stays, visible to the admin token only.
func (h *Hub) removeUser(id identity, user string) *opError {
	u := h.users[user]
	if u == nil {
		return errUnknownUsr
	}
	if user == h.ownerID {
		return invalid("the hub's owner cannot be removed")
	}
	for hash, d := range h.devices {
		if d.User == user {
			h.forgetDevice(hash, d)
		}
	}
	if err := h.store.DeleteUser(user); err != nil {
		return internalError(err)
	}
	for _, gs := range h.grants {
		delete(gs, user)
	}
	delete(h.users, user)
	h.dropAccess(user)
	h.audit(whoOf(id), "user", "removed", u.Name, true)
	return nil
}

// ---- device sharing ----

func (h *Hub) grant(id identity, node string, g *v1.DeviceGrant) *opError {
	if !h.can(id, actManage, objNode, node) {
		return errForbidden
	}
	if g.Access != accessFull && g.Access != accessJobs {
		return invalid(`access must be "full" or "jobs"`)
	}
	if h.users[g.User] == nil {
		return errUnknownUsr
	}
	if g.User == h.nodeOwner(node) {
		return invalid("that user owns this device")
	}
	g = &v1.DeviceGrant{User: g.User, Access: g.Access, GrantedMs: time.Now().UnixMilli()}
	if err := h.store.PutGrant(node, g); err != nil {
		return internalError(err)
	}
	if h.grants[node] == nil {
		h.grants[node] = map[string]*v1.DeviceGrant{}
	}
	h.grants[node][g.User] = g
	h.audit(whoOf(id), "grant", node, h.users[g.User].Name+" "+g.Access, true)
	h.dropAccess(g.User)
	h.resendNode(node)
	return nil
}

func (h *Hub) revokeGrant(id identity, node, user string) *opError {
	if !h.can(id, actManage, objNode, node) {
		return errForbidden
	}
	if h.grants[node][user] == nil {
		return &opError{"not_found", "this device is not shared with that user", http.StatusNotFound}
	}
	if err := h.store.DeleteGrant(node, user); err != nil {
		return internalError(err)
	}
	delete(h.grants[node], user)
	name := user
	if u := h.users[user]; u != nil {
		name = u.Name
	}
	h.audit(whoOf(id), "grant", node, "revoked "+name, true)
	h.dropAccess(user)
	h.resendNode(node)
	return nil
}

func (h *Hub) resendNode(node string) {
	if n := h.nodes[node]; n != nil {
		h.broadcast(&v1.Frame{Body: &v1.Frame_NodeStatus{NodeStatus: proto.Clone(n).(*v1.NodeStatus)}})
	}
}

// ---- chat sharing ----

func (h *Hub) shareChat(id identity, chat string, s *v1.ChatShare) (*v1.Chat, *opError) {
	c := h.chats[chat]
	if c == nil || !h.can(id, actManage, objChat, chat) {
		return nil, errForbidden
	}
	if h.users[s.User] == nil {
		return nil, errUnknownUsr
	}
	if s.User == h.chatOwner(c) {
		return nil, invalid("that user owns this chat")
	}
	var kept []*v1.ChatShare
	for _, old := range c.Shares {
		if old.User != s.User {
			kept = append(kept, old)
		}
	}
	switch s.Access {
	case shareRead, shareCollaborate:
		kept = append(kept, &v1.ChatShare{User: s.User, Access: s.Access})
	case "":
	default:
		return nil, invalid(`access must be "read", "collaborate" or empty to stop sharing`)
	}
	c.Shares = kept
	h.putChat(c)
	h.audit(whoOf(id), "share", chat, h.users[s.User].Name+" "+firstNonEmpty(s.Access, "none"), true)
	if s.Access == "" {
		h.dropAccess(s.User)
	}
	return h.chatFor(id, c), nil
}

// ---- routes ----

func (h *Hub) userRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/users", h.api(func(r *http.Request) (proto.Message, *opError) {
		return &v1.UserList{Users: h.userList()}, nil
	}))
	mux.HandleFunc("GET /api/v1/me", h.api(func(r *http.Request) (proto.Message, *opError) {
		if u := userOf(r).user; u != nil {
			return proto.Clone(u).(*v1.User), nil
		}
		return &v1.User{}, nil
	}))
	mux.HandleFunc("POST /api/v1/invites", h.api(func(r *http.Request) (proto.Message, *opError) {
		code, err := h.newInvite(userOf(r).userID())
		if err != nil {
			return nil, internalError(err)
		}
		return code, nil
	}))
	mux.HandleFunc("DELETE /api/v1/users/{user}", h.api(func(r *http.Request) (proto.Message, *opError) {
		return ackOf("", h.removeUser(userOf(r), r.PathValue("user")))
	}))
	mux.HandleFunc("PUT /api/v1/users/{user}", h.api(func(r *http.Request) (proto.Message, *opError) {
		in := &v1.User{}
		if err := decode(r, in); err != nil {
			return nil, err
		}
		u := h.users[r.PathValue("user")]
		if u == nil {
			return nil, errUnknownUsr
		}
		if name := strings.TrimSpace(in.Name); name != "" {
			u.Name = clip(name, 60)
		}
		if err := h.store.PutUser(u); err != nil {
			return nil, internalError(err)
		}
		return proto.Clone(u).(*v1.User), nil
	}))
	mux.HandleFunc("PUT /api/v1/nodes/{node}/grants", h.api(func(r *http.Request) (proto.Message, *opError) {
		g := &v1.DeviceGrant{}
		if err := decode(r, g); err != nil {
			return nil, err
		}
		return ackOf("", h.grant(userOf(r), r.PathValue("node"), g))
	}))
	mux.HandleFunc("DELETE /api/v1/nodes/{node}/grants/{user}", h.api(func(r *http.Request) (proto.Message, *opError) {
		return ackOf("", h.revokeGrant(userOf(r), r.PathValue("node"), r.PathValue("user")))
	}))
	mux.HandleFunc("PUT /api/v1/chats/{id}/shares", h.api(func(r *http.Request) (proto.Message, *opError) {
		s := &v1.ChatShare{}
		if err := decode(r, s); err != nil {
			return nil, err
		}
		return h.shareChat(userOf(r), r.PathValue("id"), s)
	}))
}
