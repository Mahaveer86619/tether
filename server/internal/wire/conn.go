// Package wire sends and receives protocol frames over a WebSocket.
package wire

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

const (
	Version      = 1
	readLimit    = 64 << 20
	pingInterval = 20 * time.Second
	writeTimeout = 15 * time.Second
	outBuffer    = 1024
)

var (
	marshal   = protojson.MarshalOptions{UseProtoNames: false}
	unmarshal = protojson.UnmarshalOptions{DiscardUnknown: true}

	ErrSlow = errors.New("peer too slow, dropping connection")
)

// Conn is a frame-oriented WebSocket. Send never blocks; a peer that falls
// too far behind is disconnected instead of stalling the sender.
type Conn struct {
	ws     *websocket.Conn
	out    chan *v1.Frame
	ctx    context.Context
	cancel context.CancelCauseFunc
}

func newConn(ws *websocket.Conn) *Conn {
	ws.SetReadLimit(readLimit)
	ctx, cancel := context.WithCancelCause(context.Background())
	return &Conn{ws: ws, out: make(chan *v1.Frame, outBuffer), ctx: ctx, cancel: cancel}
}

func Accept(w http.ResponseWriter, r *http.Request) (*Conn, error) {
	ws, err := websocket.Accept(w, r, nil)
	if err != nil {
		return nil, err
	}
	return newConn(ws), nil
}

func Dial(ctx context.Context, url string) (*Conn, error) {
	ws, _, err := websocket.Dial(ctx, url, nil)
	if err != nil {
		return nil, err
	}
	return newConn(ws), nil
}

// Send queues a frame. It reports false if the connection is closed or full.
func (c *Conn) Send(f *v1.Frame) bool {
	if f.V == 0 {
		f.V = Version
	}
	select {
	case <-c.ctx.Done():
		return false
	default:
	}
	select {
	case c.out <- f:
		return true
	default:
		c.Close(ErrSlow)
		return false
	}
}

// Read blocks for the next frame. Use it before Run, e.g. for the hello.
func (c *Conn) Read(ctx context.Context) (*v1.Frame, error) {
	_, data, err := c.ws.Read(ctx)
	if err != nil {
		return nil, err
	}
	f := &v1.Frame{}
	if err := unmarshal.Unmarshal(data, f); err != nil {
		return nil, err
	}
	return f, nil
}

// Run pumps frames until the connection ends, calling handle for each one
// read. It returns the reason the connection ended.
func (c *Conn) Run(handle func(*v1.Frame)) error {
	go c.writeLoop()
	go c.pingLoop()
	for {
		f, err := c.Read(c.ctx)
		if err != nil {
			c.Close(err)
			return context.Cause(c.ctx)
		}
		handle(f)
	}
}

func (c *Conn) Done() <-chan struct{} { return c.ctx.Done() }

func (c *Conn) Close(cause error) {
	c.cancel(cause)
	_ = c.ws.Close(websocket.StatusNormalClosure, "")
}

func (c *Conn) writeLoop() {
	for {
		select {
		case <-c.ctx.Done():
			return
		case f := <-c.out:
			data, err := marshal.Marshal(f)
			if err != nil {
				continue
			}
			ctx, cancel := context.WithTimeout(c.ctx, writeTimeout)
			err = c.ws.Write(ctx, websocket.MessageText, data)
			cancel()
			if err != nil {
				c.Close(err)
				return
			}
		}
	}
}

func (c *Conn) pingLoop() {
	t := time.NewTicker(pingInterval)
	defer t.Stop()
	for {
		select {
		case <-c.ctx.Done():
			return
		case <-t.C:
			ctx, cancel := context.WithTimeout(c.ctx, writeTimeout)
			err := c.ws.Ping(ctx)
			cancel()
			if err != nil {
				c.Close(err)
				return
			}
		}
	}
}
