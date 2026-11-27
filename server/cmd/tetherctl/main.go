// Command tetherctl is a terminal client for the hub, used for testing and
// scripting before the app exists.
package main

import (
	"bufio"
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

const usage = `usage: tetherctl [-hub URL] <command> [args]

commands:
  chats                                       list hub-owned chats
  chat [-node N] [-cwd DIR] [-profile P] [-mode M] [-model M] [-capability C] [-title T] <prompt>
                                              start a chat at the hub, no app needed
  chat-send <chat> <message>                  continue a chat through the hub
  chat-watch <chat>                           follow a chat's active session
  profiles                                    list core agent profiles
  models                                      list core model ranking, budgets and quota states
  nodes                                       list machines
  sessions [-node N] [-n 20]                  list sessions, newest first
  watch <session>                             follow a session live
  run -node N [-cwd DIR] [-model M] [-mode P] [-yes] <prompt>
                                              start a new session
  send [-fork] [-yes] <session> <message>     continue (or fork) a session
  dump <session>                              print a session's timeline as JSON
  interrupt <session>                         stop the current turn
  stop <session>                              end a tmux or headless session
  rebuild <session>                           re-render a session's timeline from its transcript
  pair                                        print a one-time code to pair an app or agent
  devices                                     list paired devices
  revoke <device id>                          revoke a paired device
  approvals                                   list pending approvals
  approve [-deny] <approval id>               answer one

TETHER_TOKEN must be set. -hub defaults to $TETHER_HUB. For a hub with a
self-signed certificate, set TETHER_HUB_FINGERPRINT to its SHA-256.`

func main() {
	hubURL := flag.String("hub", os.Getenv("TETHER_HUB"), "hub WebSocket URL")
	flag.Usage = func() { fmt.Fprintln(os.Stderr, usage) }
	flag.Parse()
	if flag.NArg() == 0 || *hubURL == "" || os.Getenv("TETHER_TOKEN") == "" {
		flag.Usage()
		os.Exit(2)
	}
	c, err := connect(*hubURL, os.Getenv("TETHER_TOKEN"))
	if err != nil {
		fatal(err)
	}
	args := flag.Args()[1:]
	switch flag.Arg(0) {
	case "chats":
		err = c.chats()
	case "chat":
		err = c.startChat(args, *hubURL)
	case "chat-send":
		err = c.chatSend(args, *hubURL)
	case "chat-watch":
		err = c.chatWatch(args)
	case "profiles":
		err = c.profiles(*hubURL)
	case "models":
		err = c.models(*hubURL)
	case "nodes":
		err = c.nodes()
	case "sessions":
		err = c.sessions(args)
	case "watch":
		err = c.watch(args)
	case "run":
		err = c.run(args)
	case "send":
		err = c.send(args)
	case "dump":
		err = c.dump(args)
	case "approvals":
		for _, a := range c.welcome.PendingApprovals {
			fmt.Printf("%s  %-10s %s  %s  %s\n", a.ApprovalId, a.Node, a.Session[:8], a.ToolName, a.Description)
		}
	case "approve":
		err = c.approve(args)
	case "interrupt", "stop":
		err = c.control(flag.Arg(0), args)
	case "rebuild":
		err = c.rebuild(*hubURL, args)
	case "pair":
		err = pairCode(*hubURL)
	case "devices":
		err = devices(*hubURL)
	case "revoke":
		err = revoke(*hubURL, args)
	default:
		flag.Usage()
		os.Exit(2)
	}
	if err != nil {
		fatal(err)
	}
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "tetherctl:", err)
	os.Exit(1)
}

type ctl struct {
	hub     string
	conn    *wire.Conn
	welcome *v1.Welcome
	frames  chan *v1.Frame
	stdin   *bufio.Reader
}

func connect(url, token string) (*ctl, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	conn, err := wire.Dial(ctx, url, os.Getenv("TETHER_HUB_FINGERPRINT"))
	if err != nil {
		return nil, err
	}
	host, _ := os.Hostname()
	conn.Send(&v1.Frame{Body: &v1.Frame_ClientHello{ClientHello: &v1.ClientHello{Token: token, ClientName: "tetherctl@" + host, Platform: "cli"}}})
	c := &ctl{hub: url, conn: conn, frames: make(chan *v1.Frame, 4096), stdin: bufio.NewReader(os.Stdin)}
	go func() {
		err := conn.Run(func(f *v1.Frame) { c.frames <- f })
		c.frames <- &v1.Frame{Body: &v1.Frame_Error{Error: &v1.Error{Code: "disconnected", Message: fmt.Sprint(err)}}}
	}()
	select {
	case f := <-c.frames:
		if w := f.GetWelcome(); w != nil {
			c.welcome = w
			return c, nil
		}
		if e := f.GetError(); e != nil {
			return nil, fmt.Errorf("%s: %s", e.Code, e.Message)
		}
		return nil, errors.New("unexpected first frame")
	case <-ctx.Done():
		return nil, errors.New("no welcome from hub")
	}
}

// request sends a command and waits for its Ack, printing anything else
// that arrives meanwhile through handle.
func (c *ctl) request(f *v1.Frame, handle func(*v1.Frame)) (*v1.Ack, error) {
	f.Id = uuid.NewString()
	c.conn.Send(f)
	for fr := range c.frames {
		if fr.ReplyTo == f.Id {
			if e := fr.GetError(); e != nil {
				return nil, fmt.Errorf("%s: %s", e.Code, e.Message)
			}
			// Subscribe replies with its end-of-replay marker instead of an Ack.
			if handle != nil {
				handle(fr)
			}
			return fr.GetAck(), nil
		}
		if e := fr.GetError(); e != nil && e.Code == "disconnected" {
			return nil, errors.New(e.Message)
		}
		if handle != nil {
			handle(fr)
		}
	}
	return nil, errors.New("connection closed")
}

func (c *ctl) resolve(prefix string) (*v1.SessionInfo, error) {
	var hits []*v1.SessionInfo
	for _, s := range c.welcome.Sessions {
		if strings.HasPrefix(s.Id, prefix) {
			hits = append(hits, s)
		}
	}
	switch len(hits) {
	case 0:
		return nil, fmt.Errorf("no session matches %q", prefix)
	case 1:
		return hits[0], nil
	}
	return nil, fmt.Errorf("%q matches %d sessions", prefix, len(hits))
}

func (c *ctl) nodes() error {
	for _, n := range c.welcome.Nodes {
		state := "offline"
		if n.Online {
			state = "online"
		}
		fmt.Printf("%-16s %-8s %-8s claude %-10s running %d\n", n.Node, state, n.Os, n.ClaudeVersion, n.RunningSessions)
	}
	return nil
}

func (c *ctl) sessions(args []string) error {
	fs := flag.NewFlagSet("sessions", flag.ExitOnError)
	node := fs.String("node", "", "only this node")
	n := fs.Int("n", 20, "how many")
	_ = fs.Parse(args)
	shown := 0
	for _, s := range c.welcome.Sessions {
		if *node != "" && s.Node != *node {
			continue
		}
		if shown == *n {
			break
		}
		shown++
		fmt.Printf("%s  %-10s %-18s %-9s %-5s %s\n", s.Id[:8], s.Node, stateName(s.State), hostName(s.Host), ago(s.UpdatedMs), s.Title)
		if s.AttachCommand != "" {
			fmt.Printf("          attach: %s\n", s.AttachCommand)
		}
	}
	return nil
}

func (c *ctl) subscribe(session string, p *printer) error {
	_, err := c.request(&v1.Frame{Body: &v1.Frame_Subscribe{Subscribe: &v1.Subscribe{Session: session}}}, p.handle)
	return err
}

func (c *ctl) watch(args []string) error {
	if len(args) != 1 {
		return errors.New("watch <session>")
	}
	s, err := c.resolve(args[0])
	if err != nil {
		return err
	}
	p := newPrinter(c, s.Id, false)
	p.replayed = true
	if err := c.subscribe(s.Id, p); err != nil {
		return err
	}
	return p.loop(false)
}

func (c *ctl) run(args []string) error {
	fs := flag.NewFlagSet("run", flag.ExitOnError)
	node := fs.String("node", "", "machine to run on")
	cwd := fs.String("cwd", "", "working directory on that machine")
	model := fs.String("model", "", "model alias or id")
	mode := fs.String("mode", "", "permission mode (default, acceptEdits, plan, ...)")
	yes := fs.Bool("yes", false, "approve every tool call")
	_ = fs.Parse(args)
	prompt := strings.Join(fs.Args(), " ")
	if *node == "" || prompt == "" {
		return errors.New("run -node N [-cwd DIR] <prompt>")
	}
	ack, err := c.request(&v1.Frame{Body: &v1.Frame_CreateSession{CreateSession: &v1.CreateSession{
		Node: *node, Cwd: *cwd, Prompt: prompt, Model: *model, PermissionMode: *mode,
	}}}, nil)
	if err != nil {
		return err
	}
	fmt.Printf("session %s\n", ack.Session)
	p := newPrinter(c, ack.Session, *yes)
	p.replayed = true
	if err := c.subscribe(ack.Session, p); err != nil {
		return err
	}
	return p.loop(true)
}

func (c *ctl) send(args []string) error {
	fs := flag.NewFlagSet("send", flag.ExitOnError)
	fork := fs.Bool("fork", false, "continue in a new session")
	yes := fs.Bool("yes", false, "approve every tool call")
	_ = fs.Parse(args)
	if fs.NArg() < 2 {
		return errors.New("send [-fork] <session> <message>")
	}
	s, err := c.resolve(fs.Arg(0))
	if err != nil {
		return err
	}
	text := strings.Join(fs.Args()[1:], " ")
	p := newPrinter(c, s.Id, *yes)
	// Old history may still stream in from the transcript after subscribing.
	p.since = time.Now().Add(-5 * time.Second).UnixMilli()
	if !*fork {
		// Subscribe first so the history is skipped and only the new turn prints.
		if err := c.subscribe(s.Id, p); err != nil {
			return err
		}
	}
	ack, err := c.request(&v1.Frame{Body: &v1.Frame_SendMessage{SendMessage: &v1.SendMessage{Session: s.Id, Text: text, Fork: *fork}}}, p.handle)
	if err != nil {
		return err
	}
	if *fork {
		fmt.Printf("forked into session %s\n", ack.Session)
		p = newPrinter(c, ack.Session, *yes)
		p.since = time.Now().Add(-5 * time.Second).UnixMilli()
		if err := c.subscribe(ack.Session, p); err != nil {
			return err
		}
	}
	p.replayed = true
	return p.loop(true)
}

func (c *ctl) dump(args []string) error {
	if len(args) != 1 {
		return errors.New("dump <session>")
	}
	s, err := c.resolve(args[0])
	if err != nil {
		return err
	}
	var items []*v1.TimelineItem
	_, err = c.request(&v1.Frame{Body: &v1.Frame_Subscribe{Subscribe: &v1.Subscribe{Session: s.Id}}}, func(f *v1.Frame) {
		if t := f.GetTimeline(); t != nil && t.Session == s.Id {
			items = append(items, t.Items...)
		}
	})
	if err != nil {
		return err
	}
	// Mirroring may still be loading history; give it a moment to settle.
	deadline := time.After(3 * time.Second)
collect:
	for {
		select {
		case f := <-c.frames:
			if t := f.GetTimeline(); t != nil && t.Session == s.Id {
				items = append(items, t.Items...)
				deadline = time.After(time.Second)
			}
		case <-deadline:
			break collect
		}
	}
	latest := map[string]*v1.TimelineItem{}
	for _, it := range items {
		latest[it.ItemId] = it
	}
	var out []*v1.TimelineItem
	for _, it := range latest {
		out = append(out, it)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Ord < out[j].Ord })
	m := protojson.MarshalOptions{Multiline: true}
	for _, it := range out {
		b, _ := m.Marshal(it)
		fmt.Println(string(b))
	}
	return nil
}

func (c *ctl) control(cmd string, args []string) error {
	if len(args) != 1 {
		return fmt.Errorf("%s <session>", cmd)
	}
	s, err := c.resolve(args[0])
	if err != nil {
		return err
	}
	f := &v1.Frame{Body: &v1.Frame_InterruptSession{InterruptSession: &v1.InterruptSession{Session: s.Id}}}
	if cmd == "stop" {
		f = &v1.Frame{Body: &v1.Frame_StopSession{StopSession: &v1.StopSession{Session: s.Id}}}
	}
	_, err = c.request(f, nil)
	return err
}

// rest calls the hub's REST API, for admin actions with no WebSocket command.
func rest(hubURL, method, path string, out proto.Message) error {
	return restBody(hubURL, method, path, nil, out)
}

func restBody(hubURL, method, path string, in, out proto.Message) error {
	var body []byte
	if in != nil {
		var err error
		body, err = protojson.Marshal(in)
		if err != nil {
			return err
		}
	}
	req, err := http.NewRequest(method, wire.HTTPBase(hubURL)+"/api/v1"+path, strings.NewReader(string(body)))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+os.Getenv("TETHER_TOKEN"))
	if in != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := wire.HTTPClient(os.Getenv("TETHER_HUB_FINGERPRINT")).Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	reply, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s: %s", resp.Status, reply)
	}
	if out == nil {
		return nil
	}
	return protojson.UnmarshalOptions{DiscardUnknown: true}.Unmarshal(reply, out)
}

func (c *ctl) chats() error {
	list := &v1.ChatList{}
	if err := rest(c.hubURL(), "GET", "/chats", list); err != nil {
		return err
	}
	for _, ch := range list.Chats {
		where := ""
		if ch.Target != nil {
			where = ch.Target.Node
			if ch.Target.Cwd != "" {
				where += ":" + ch.Target.Cwd
			}
		}
		fmt.Printf("%s  %-28s %-32s %s  %s\n", ch.Id[:8], ch.Title, where, ch.ActiveSession[:min(8, len(ch.ActiveSession))], ago(ch.UpdatedMs))
	}
	return nil
}

func (c *ctl) resolveChat(prefix string) (*v1.Chat, error) {
	list := &v1.ChatList{}
	if err := rest(c.hubURL(), "GET", "/chats", list); err != nil {
		return nil, err
	}
	var hits []*v1.Chat
	for _, ch := range list.Chats {
		if strings.HasPrefix(ch.Id, prefix) {
			hits = append(hits, ch)
		}
	}
	switch len(hits) {
	case 0:
		return nil, fmt.Errorf("no chat matches %q", prefix)
	case 1:
		return hits[0], nil
	}
	return nil, fmt.Errorf("%q matches %d chats", prefix, len(hits))
}

func (c *ctl) startChat(args []string, hubURL string) error {
	fs := flag.NewFlagSet("chat", flag.ExitOnError)
	node := fs.String("node", "", "machine to run on")
	cwd := fs.String("cwd", "", "folder on that machine")
	profile := fs.String("profile", "", "core agent profile id")
	mode := fs.String("mode", "main", "main or subagent")
	model := fs.String("model", "", "pin a model from token_status, e.g. opencode/big-pickle")
	capability := fs.String("capability", "", "long_context, reasoning, read, edit, test, review or vision")
	title := fs.String("title", "", "short title")
	_ = fs.Parse(args)
	if fs.NArg() != 1 {
		return errors.New("chat [-node N] [-cwd DIR] [-profile P] [-model M] [-capability C] <prompt>")
	}
	cc := &v1.CreateChat{Prompt: fs.Arg(0), Title: *title, Profile: *profile, Mode: *mode,
		Model: *model, Capability: *capability, ClientId: uuid.NewString()}
	if *node != "" || *cwd != "" {
		cc.Target = &v1.ChatTarget{Mode: "manual", Node: *node, Cwd: *cwd}
	}
	ch := &v1.Chat{}
	if err := restBody(hubURL, "POST", "/chats", cc, ch); err != nil {
		return err
	}
	fmt.Printf("chat %s  lead session %s\n", ch.Id, ch.ActiveSession)
	return nil
}

func (c *ctl) chatSend(args []string, hubURL string) error {
	if len(args) != 2 {
		return errors.New("chat-send <chat> <message>")
	}
	ch, err := c.resolveChat(args[0])
	if err != nil {
		return err
	}
	m := &v1.SendMessage{Text: args[1], ClientId: uuid.NewString()}
	return restBody(hubURL, "POST", "/chats/"+ch.Id+"/messages", m, nil)
}

func (c *ctl) chatWatch(args []string) error {
	if len(args) != 1 {
		return errors.New("chat-watch <chat>")
	}
	ch, err := c.resolveChat(args[0])
	if err != nil {
		return err
	}
	if ch.ActiveSession == "" {
		return errors.New("the chat has no active session yet")
	}
	return c.watch([]string{ch.ActiveSession})
}

func (c *ctl) profiles(hubURL string) error {
	list := &v1.AgentProfileList{}
	if err := rest(hubURL, "GET", "/profiles", list); err != nil {
		return err
	}
	for _, p := range list.Profiles {
		fmt.Printf("%-20s %-9s %-12s %-14s context %d%s\n", p.Id, p.Kind, p.Command, p.StatusProtocol, p.ContextWindow, map[bool]string{true: " free", false: ""}[p.FreeTier])
	}
	return nil
}

func (c *ctl) models(hubURL string) error {
	status := &v1.TokenStatus{}
	if err := rest(hubURL, "GET", "/token/status", status); err != nil {
		return err
	}
	fmt.Printf("last decision: %s\nreason: %s\n\n", status.LastDecision, status.LastReason)
	fmt.Printf("%-5s %-38s %-5s %-11s %10s %10s  %s\n", "RANK", "MODEL", "FREE", "QUOTA", "USED", "BUDGET", "NOTES")
	for _, b := range status.Providers {
		budget := "-"
		if b.BudgetTokens > 0 {
			budget = fmt.Sprint(b.BudgetTokens)
		}
		fmt.Printf("%-5d %-38s %-5t %-11s %10d %10s  %s\n", b.Rank, b.Provider+"/"+b.Model, b.FreeTier, b.QuotaState, b.UsedTokens, budget, b.Notes)
	}
	fmt.Println()
	return c.profiles(hubURL)
}

func (c *ctl) hubURL() string {
	return c.hub
}

func (c *ctl) rebuild(hubURL string, args []string) error {
	if len(args) != 1 {
		return errors.New("rebuild <session>")
	}
	s, err := c.resolve(args[0])
	if err != nil {
		return err
	}
	if err := rest(hubURL, "POST", "/sessions/"+s.Id+"/rebuild", nil); err != nil {
		return err
	}
	fmt.Println("rebuilding", s.Id[:8], "- it re-renders when next opened")
	return nil
}

// pair prints a one-time code another device can pair with.
func pairCode(hubURL string) error {
	code := &v1.PairingCode{}
	if err := rest(hubURL, "POST", "/pairing-codes", code); err != nil {
		return err
	}
	link := "tether://pair?hub=" + url.QueryEscape(hubURL) + "&code=" + code.Code
	if code.CertFingerprint != "" {
		link += "&fp=" + code.CertFingerprint
	}
	fmt.Printf("code: %s (valid until %s)\nlink: %s\n", code.Code, time.UnixMilli(code.ExpiresMs).Format("15:04"), link)
	fmt.Println("\nApp: on the setup screen, type the hub address and code (or scan the QR code from another app's Add a device).")
	fmt.Println("Agent: tether-agent pair -hub " + hubURL + " -token-file <path> " + code.Code)
	return nil
}

func devices(hubURL string) error {
	list := &v1.DeviceList{}
	if err := rest(hubURL, "GET", "/devices", list); err != nil {
		return err
	}
	for _, d := range list.Devices {
		fmt.Printf("%s  %-6s %-16s %-8s seen %s\n", d.Id[:8], d.Kind, d.Name, d.Platform, time.UnixMilli(d.LastSeenMs).Format("2006-01-02 15:04"))
	}
	return nil
}

func revoke(hubURL string, args []string) error {
	if len(args) != 1 {
		return errors.New("revoke <device id>")
	}
	list := &v1.DeviceList{}
	if err := rest(hubURL, "GET", "/devices", list); err != nil {
		return err
	}
	for _, d := range list.Devices {
		if strings.HasPrefix(d.Id, args[0]) {
			if err := rest(hubURL, "DELETE", "/devices/"+d.Id, nil); err != nil {
				return err
			}
			fmt.Println("revoked", d.Name)
			return nil
		}
	}
	return fmt.Errorf("no device matches %q", args[0])
}

func (c *ctl) approve(args []string) error {
	fs := flag.NewFlagSet("approve", flag.ExitOnError)
	deny := fs.Bool("deny", false, "deny instead of allow")
	_ = fs.Parse(args)
	if fs.NArg() != 1 {
		return errors.New("approve [-deny] <approval id>")
	}
	d := v1.Decision_DECISION_ALLOW
	if *deny {
		d = v1.Decision_DECISION_DENY
	}
	_, err := c.request(&v1.Frame{Body: &v1.Frame_ApprovalDecision{ApprovalDecision: &v1.ApprovalDecision{ApprovalId: fs.Arg(0), Decision: d}}}, nil)
	return err
}

func stateName(s v1.SessionState) string {
	return strings.ToLower(strings.TrimPrefix(s.String(), "SESSION_STATE_"))
}

func hostName(h v1.SessionHost) string {
	if h == v1.SessionHost_SESSION_HOST_UNSPECIFIED || h == v1.SessionHost_SESSION_HOST_NONE {
		return "-"
	}
	return strings.ToLower(strings.TrimPrefix(h.String(), "SESSION_HOST_"))
}

func ago(ms int64) string {
	d := time.Since(time.UnixMilli(ms))
	switch {
	case d < time.Minute:
		return "now"
	case d < time.Hour:
		return fmt.Sprintf("%dm", int(d.Minutes()))
	case d < 48*time.Hour:
		return fmt.Sprintf("%dh", int(d.Hours()))
	}
	return fmt.Sprintf("%dd", int(d.Hours()/24))
}
