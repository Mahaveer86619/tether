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
	slots, err := h.store.Slots("")
	if err != nil {
		return err
	}
	h.slots = map[string][]*v1.DeviceSlot{}
	for _, s := range slots {
		h.slots[s.Node] = append(h.slots[s.Node], s)
	}
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

// inTimeWindow checks if t falls within the grant's allowed time window.
// If StartHour == EndHour, hours are unrestricted 24/7; days still apply.
// Overnight windows (e.g. 20:00 to 10:00 next day) are valid when hour >= 20 || hour < 10.
func inTimeWindow(t time.Time, g *v1.DeviceGrant) bool {
	if g == nil {
		return false
	}
	if g.Timezone != "" {
		if loc, err := time.LoadLocation(g.Timezone); err == nil {
			t = t.In(loc)
		}
	}
	if g.Days != "" {
		day := strings.ToLower(t.Weekday().String()[:3])
		matched := false
		for _, d := range strings.Split(g.Days, ",") {
			if strings.TrimSpace(d) == day {
				matched = true
				break
			}
		}
		if !matched {
			return false
		}
	}
	if g.StartHour == g.EndHour {
		return true
	}
	hour := t.Hour()
	start := int(g.StartHour)
	end := int(g.EndHour)
	if start < end {
		return hour >= start && hour < end
	}
	return hour >= start || hour < end
}

// activeSlot returns the slot active on node at nowMs, or nil.
func (h *Hub) activeSlot(node string, nowMs int64) *v1.DeviceSlot {
	for _, s := range h.slots[node] {
		if nowMs >= s.StartMs && nowMs < s.EndMs {
			return s
		}
	}
	return nil
}

// slotByID looks up a booked slot on node. Caller holds h.mu.
func (h *Hub) slotByID(node, id string) *v1.DeviceSlot {
	for _, s := range h.slots[node] {
		if s.Id == id {
			return s
		}
	}
	return nil
}

// canUseDeviceNow checks if id can execute compute on node at now.
// Returns (ok, reason). Reason is empty when ok is true, or one of:
// "unauthenticated", "no_grant", "slot_conflict", "outside_window".
func (h *Hub) canUseDeviceNow(id identity, act action, node string, now time.Time) (bool, string) {
	if id.root() {
		return true, ""
	}
	u := id.userID()
	if u == "" || h.users[u] == nil {
		return false, "unauthenticated"
	}
	if h.nodeOwner(node) == u {
		return true, ""
	}
	g := h.grants[node][u]
	slot := h.activeSlot(node, now.UnixMilli())
	if slot != nil {
		if slot.User == u {
			if act == actRunClaude && (g == nil || g.Access != accessFull) {
				return false, "requires_full_access"
			}
			return true, ""
		}
		return false, "slot_conflict"
	}
	if g == nil {
		return false, "no_grant"
	}
	if act == actRunClaude && g.Access != accessFull {
		return false, "requires_full_access"
	}
	if !inTimeWindow(now, g) {
		return false, "outside_window"
	}
	return true, ""
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

// nodeFor is a node's status as id sees it: its owner, its grants only
// for the owner (or grantee's own grant), and booked slots.
func (h *Hub) nodeFor(id identity, n *v1.NodeStatus) *v1.NodeStatus {
	n = proto.Clone(n).(*v1.NodeStatus)
	n.Owner = h.nodeOwner(n.Node)
	if id.root() || n.Owner == id.userID() {
		for _, g := range h.grants[n.Node] {
			n.Grants = append(n.Grants, proto.Clone(g).(*v1.DeviceGrant))
		}
		sort.Slice(n.Grants, func(i, j int) bool { return n.Grants[i].GrantedMs < n.Grants[j].GrantedMs })
	} else if g := h.grants[n.Node][id.userID()]; g != nil {
		n.Grants = append(n.Grants, proto.Clone(g).(*v1.DeviceGrant))
	}
	for _, s := range h.slots[n.Node] {
		n.Slots = append(n.Slots, proto.Clone(s).(*v1.DeviceSlot))
	}
	sort.Slice(n.Slots, func(i, j int) bool { return n.Slots[i].StartMs < n.Slots[j].StartMs })
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
	for node, slist := range h.slots {
		var kept []*v1.DeviceSlot
		for _, s := range slist {
			if s.User != user {
				kept = append(kept, s)
			}
		}
		h.slots[node] = kept
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
	if g.StartHour < 0 || g.StartHour > 23 || g.EndHour < 0 || g.EndHour > 23 {
		return invalid("hours must be between 0 and 23")
	}
	if g.Timezone != "" {
		if _, err := time.LoadLocation(g.Timezone); err != nil {
			return invalid("unknown timezone: " + g.Timezone)
		}
	}
	g = &v1.DeviceGrant{
		User:      g.User,
		Access:    g.Access,
		GrantedMs: time.Now().UnixMilli(),
		StartHour: g.StartHour,
		EndHour:   g.EndHour,
		Days:      strings.ToLower(strings.TrimSpace(g.Days)),
		Timezone:  g.Timezone,
	}
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

// ---- slot booking ----

func (h *Hub) listSlots(id identity, node string) (*v1.DeviceSlotList, *opError) {
	if !h.can(id, actView, objNode, node) {
		return nil, errForbidden
	}
	list := &v1.DeviceSlotList{}
	for _, s := range h.slots[node] {
		list.Slots = append(list.Slots, proto.Clone(s).(*v1.DeviceSlot))
	}
	sort.Slice(list.Slots, func(i, j int) bool { return list.Slots[i].StartMs < list.Slots[j].StartMs })
	return list, nil
}

func (h *Hub) bookSlot(id identity, node string, req *v1.BookSlotRequest) (*v1.DeviceSlot, *opError) {
	if !h.can(id, actRunJob, objNode, node) && h.nodeOwner(node) != id.userID() {
		return nil, errForbidden
	}
	targetUser := req.User
	if targetUser == "" {
		targetUser = id.userID()
	}
	if targetUser != id.userID() && h.nodeOwner(node) != id.userID() && !id.root() {
		return nil, errForbidden
	}
	if h.users[targetUser] == nil {
		return nil, errUnknownUsr
	}
	now := time.Now().UnixMilli()
	if req.StartMs <= 0 || req.EndMs <= 0 || req.EndMs <= req.StartMs {
		return nil, invalid("start_ms must be before end_ms")
	}
	if req.EndMs-req.StartMs > 48*3600*1000 {
		return nil, invalid("slot duration cannot exceed 48 hours")
	}
	for _, existing := range h.slots[node] {
		if existing.StartMs < req.EndMs && existing.EndMs > req.StartMs {
			return nil, &opError{"slot_conflict", "this time slot overlaps with an existing booking (" + existing.Id + ")", http.StatusConflict}
		}
	}
	slot := &v1.DeviceSlot{
		Id:        uuid.NewString()[:8],
		Node:      node,
		User:      targetUser,
		StartMs:   req.StartMs,
		EndMs:     req.EndMs,
		Notes:     clip(req.Notes, 200),
		CreatedMs: now,
	}
	if err := h.store.PutSlot(slot); err != nil {
		return nil, internalError(err)
	}
	h.slots[node] = append(h.slots[node], slot)
	userName := targetUser
	if u := h.users[targetUser]; u != nil {
		userName = u.Name
	}
	h.audit(whoOf(id), "slot", node, "booked slot for "+userName+": "+slot.Id, true)
	h.resendNode(node)
	return proto.Clone(slot).(*v1.DeviceSlot), nil
}

func (h *Hub) cancelSlot(id identity, node, slotID string) *opError {
	if !h.can(id, actView, objNode, node) {
		return errForbidden
	}
	var found *v1.DeviceSlot
	var idx int = -1
	for i, s := range h.slots[node] {
		if s.Id == slotID {
			found = s
			idx = i
			break
		}
	}
	if found == nil {
		return &opError{"not_found", "slot not found", http.StatusNotFound}
	}
	if found.User != id.userID() && h.nodeOwner(node) != id.userID() && !id.root() {
		return errForbidden
	}
	if err := h.store.DeleteSlot(slotID); err != nil {
		return internalError(err)
	}
	h.slots[node] = append(h.slots[node][:idx], h.slots[node][idx+1:]...)
	h.audit(whoOf(id), "slot", node, "cancelled slot "+slotID, true)
	h.resendNode(node)
	return nil
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
	mux.HandleFunc("GET /api/v1/nodes/{node}/slots", h.api(func(r *http.Request) (proto.Message, *opError) {
		return h.listSlots(userOf(r), r.PathValue("node"))
	}))
	mux.HandleFunc("POST /api/v1/nodes/{node}/slots", h.api(func(r *http.Request) (proto.Message, *opError) {
		req := &v1.BookSlotRequest{}
		if err := decode(r, req); err != nil {
			return nil, err
		}
		return h.bookSlot(userOf(r), r.PathValue("node"), req)
	}))
	mux.HandleFunc("DELETE /api/v1/nodes/{node}/slots/{slot}", h.api(func(r *http.Request) (proto.Message, *opError) {
		return ackOf("", h.cancelSlot(userOf(r), r.PathValue("node"), r.PathValue("slot")))
	}))
	mux.HandleFunc("PUT /api/v1/chats/{id}/shares", h.api(func(r *http.Request) (proto.Message, *opError) {
		s := &v1.ChatShare{}
		if err := decode(r, s); err != nil {
			return nil, err
		}
		return h.shareChat(userOf(r), r.PathValue("id"), s)
	}))
}
