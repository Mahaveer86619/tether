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
	"os"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

const usage = `usage: tetherctl [-hub URL] <command> [args]

commands:
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
  approvals                                   list pending approvals
  approve [-deny] <approval id>               answer one

TETHER_TOKEN must be set. -hub defaults to $TETHER_HUB.`

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
	conn    *wire.Conn
	welcome *v1.Welcome
	frames  chan *v1.Frame
	stdin   *bufio.Reader
}

func connect(url, token string) (*ctl, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	conn, err := wire.Dial(ctx, url)
	if err != nil {
		return nil, err
	}
	host, _ := os.Hostname()
	conn.Send(&v1.Frame{Body: &v1.Frame_ClientHello{ClientHello: &v1.ClientHello{Token: token, ClientName: "tetherctl@" + host, Platform: "cli"}}})
	c := &ctl{conn: conn, frames: make(chan *v1.Frame, 4096), stdin: bufio.NewReader(os.Stdin)}
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

// rebuild goes over REST: it's an admin action with no WebSocket command.
func (c *ctl) rebuild(hubURL string, args []string) error {
	if len(args) != 1 {
		return errors.New("rebuild <session>")
	}
	s, err := c.resolve(args[0])
	if err != nil {
		return err
	}
	base := strings.TrimSuffix(strings.Replace(strings.Replace(hubURL, "wss://", "https://", 1), "ws://", "http://", 1), "/ws")
	req, err := http.NewRequest("POST", base+"/api/v1/sessions/"+s.Id+"/rebuild", nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+os.Getenv("TETHER_TOKEN"))
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s: %s", resp.Status, body)
	}
	fmt.Println("rebuilding", s.Id[:8], "- it re-renders when next opened")
	return nil
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
