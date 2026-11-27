# Architecture

## Goals

- Run Tether core - hub, agents and `tetherctl` - on any device and see/control every session from a shell, MCP client, app or Herdr, with no Tether app required.
- Render agent output properly on any screen without changing how the agent responds.
- Use an always-on machine as the hub and shared state for all nodes.
- Keep everything inside the tailnet. No public endpoints, no third-party relay.
- Let one Claude Code main agent delegate bounded work in parallel to configured free-tier CLIs such as Antigravity CLI and OpenCode CLI, with token budgeting owned by the hub.

See [core-first-v1.md](../plans/core-first-v1.md) for the v1 boundary. The Flutter apps are optional views; Herdr is an external harness that can replace them. Core-owned token routing is a hard gate for full v1.

Non-goals for v1: driving phones or desktop GUIs as devices, bundling or wrapping third-party coding CLIs, forking Herdr.

## Components

### tether-agent

Runs on every machine that hosts sessions: laptops, desktops, always-on servers and phones that can run the binary.

- Hosts sessions a client starts: the main Claude Code session in tmux where tmux exists (Linux), otherwise headless `claude -p` in stream-json mode (Windows), plus sub-agent sessions from profiles such as Antigravity CLI and OpenCode CLI. See [hosting.md](hosting.md) and [core-first-v1.md](../plans/core-first-v1.md).
- Tracks the live state of every Claude Code session on the machine, including ones you start yourself, through HTTP hooks installed in `~/.claude/settings.json`.
- Indexes sessions created anywhere on the machine, including in the TUI, by reading `~/.claude/projects/*/*.jsonl` (see [sessions.md](sessions.md)).
- Mirrors live TUI sessions read-only by tailing their transcript file.
- Forwards raw events to the hub untouched. Parsing happens in one place, the hub.
- Routes permission prompts to the app: through the `PermissionRequest` hook for interactive sessions (the terminal can answer too; first answer wins), and through Claude Code's stdio control protocol (`--permission-prompt-tool stdio`) for headless runs.
- On the mini PC, launches each session in a sandbox container instead of directly on the host ([home-server.md](../operations/home-server.md)).
- Reports node health: CPU, memory, disk, Claude Code version, online state, and its hardware (GPUs, memory, CPU count).
- Runs **jobs** for the hub: servers and scripts in their own process group (a Job Object on Windows), with stop, pause, resume, restart policies and a capped log ([jobs.md](jobs.md)).

On Windows it runs as a per-user scheduled task that the app starts on launch, not a service, so it inherits the user's Claude Code login, PATH and `~/.claude`.

### tether-hub

Runs once, on the mini PC, as a systemd service.

- Listens on the mini PC's Tailscale IP and checks a shared token on every connection. (Planned: join the tailnet as its own node with `tsnet` and identify callers with Tailscale `WhoIs`.)
- Accepts **outbound** connections from agents and apps. Nothing ever needs to connect into a laptop or phone, which avoids NAT, sleep and battery-killer problems.
- Owns the canonical event log per session in SQLite with a monotonically increasing `seq`, so any client can reconnect and replay from where it left off.
- Runs the **renderer**: Claude Code stream-json and transcript lines in, typed contract events out ([protocol.md](protocol.md)).
- Routes commands from any client - app, `tetherctl`, MCP/SSE caller or Herdr bridge - to the right agent, and approvals from agents to every authorized client.
- Serves the NAS file API (browse, upload, download) for the app's Files view.
- Runs scheduled jobs (cron expressions → new headless session on a chosen node).
- Exposes an MCP server so a session on any node can list nodes, start or read sessions elsewhere, and read or write NAS files. In v1 it also owns chat creation, agent profiles, sub-agent delegation and token-status/tools. This is how nodes and external clients talk to each other.

### Optional clients: Flutter app and Herdr

The Flutter app is one codebase, two layouts. It is a view over hub state, not the owner of chats.

- **Android:** tabs for Dashboard, Sessions, Files, Settings. Approvals arrive as notifications.
- **Windows:** multi-pane layout. Session list on the left, transcript in the middle, tool details or a second session on the right. Several sessions can be open side by side, which is the main improvement over the TUI.
- Renders only the contract's block and card types. It never sees Claude Code's raw format.

Herdr desktop/Android is an external client and can replace the Flutter app as the person's window into core. Herdr owns panes and terminal UI through its own `herdr-core` OpenRPC/socket API; Tether owns chats, sessions, jobs, permissions and budgets through REST/MCP. The contract and mapping are in [core-first-v1.md](../plans/core-first-v1.md#herdr-integration-contract). Tether does not vendor or fork Herdr.

## Data flow: a prompt from any client to a device

```
Client ──session.send──► Hub ──agent.run──► Agent(device) ──stdin──► configured CLI
                                                                      │ stdout: stream-json
Client ◄───timeline/token status── Hub(render + log, seq++) ◄──rawEvents── Agent ◄─┘
```

Approval loop:

```
claude ──permission tool call──► Agent ──approval.request──► Hub ──approval.requested──► App(s)
claude ◄──────allow/deny──────── Agent ◄──approval.result─── Hub ◄──approval.respond──── App
```

## Technology choices

| Choice | Why |
|---|---|
| Go for hub and agent | Single static binaries for Windows and Linux, good concurrency for streaming. |
| Shared token now, `tsnet` later | A token over Tailscale is enough for one owner. `tsnet` would add per-device identity via `WhoIs` and remove the open port. |
| Protobuf as the contract, JSON on the wire | One schema generates Go and Dart types so server and app can't drift. JSON (`protojson`) keeps frames readable while debugging. |
| WebSocket | Long-lived, bidirectional, works the same on Android and Windows. |
| SQLite (`modernc.org/sqlite`) | Pure Go, no CGO, so the agent cross-compiles to Windows easily. |
| `goldmark` with GFM | Parses tables, task lists and strikethrough the way Claude writes them. |
| Hub parses, agent forwards raw | One parser to maintain; agents stay thin and version-tolerant; raw events are kept so rendering can be re-run after parser fixes. |
| Spawning the `claude` CLI, not the Agent SDK | It uses the existing Claude Code login on each machine and behaves exactly like the user's TUI sessions. |
