package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/Mahaveer86619/tether/server/internal/wire"
)

type rpcRequest struct {
	ID     json.RawMessage `json:"id,omitempty"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (e *rpcError) Error() string { return fmt.Sprintf("%d: %s", e.Code, e.Message) }

type rpcResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

type hubClient struct {
	base   string
	token  string
	client *http.Client
}

func newHubClient(hubURL, token, fingerprint string) *hubClient {
	client := wire.HTTPClient(fingerprint)
	// MCP calls can wait for sub-agents for up to 15 minutes.
	client.Timeout = 0
	return &hubClient{base: wire.HTTPBase(hubURL), token: token, client: client}
}

func (c *hubClient) request(ctx context.Context, method, path string, body []byte, out any) error {
	var reader io.Reader
	if body != nil {
		reader = bytes.NewReader(body)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.base+path, reader)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := c.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("hub %s: %s", path, resp.Status)
	}
	if out == nil {
		return nil
	}
	return json.Unmarshal(data, out)
}

func (c *hubClient) rpc(ctx context.Context, req rpcRequest) (rpcResponse, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return rpcResponse{}, err
	}
	var out rpcResponse
	if err := c.request(ctx, http.MethodPost, "/mcp", body, &out); err != nil {
		return rpcResponse{}, err
	}
	if out.Error != nil {
		return out, out.Error
	}
	return out, nil
}

func (c *hubClient) state(ctx context.Context) (welcomeState, error) {
	var out welcomeState
	err := c.request(ctx, http.MethodGet, "/api/v1/state", nil, &out)
	return out, err
}
