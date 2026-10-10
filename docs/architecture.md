# Architecture

## Goals

- See and control every Claude Code session on every machine from one app, on Android and Windows.
- Render Claude Code output properly on any screen without changing how Claude responds.
- Use the mini PC as an always-on sandbox and the NAS as the shared drive for all nodes.
- Keep everything inside the tailnet. No public endpoints, no third-party relay.

Non-goals for v1: driving phones or desktop GUIs, multi-user tenancy, agents other than Claude Code (the adapter layer leaves room for them later).

## Components

### tether-agent

Runs on every machine that has Claude Code: the Windows laptop and the mini PC.

- Starts Claude Code headless: `claude -p --output-format stream-json --input-format stream-json --include-partial-messages --verbose`, plus `--resume`/`--fork-session` when continuing a session.
- Indexes sessions created anywhere on the machine, including in the TUI, by reading `~/.claude/projects/*/*.jsonl` (see [sessions.md](sessions.md)).
- Mirrors live TUI sessions read-only by tailing their transcript file.
- Forwards raw events to the hub untouched. Parsing happens in one place, the hub.
- Answers permission prompts by exposing an MCP tool used with `--permission-prompt-tool`; the call blocks until the app approves or denies.
- On the mini PC, launches each session in a sandbox container instead of directly on the host ([home-server.md](home-server.md)).
- Reports node health: CPU, memory, disk, Claude Code version, online state.

On Windows it runs as a per-user logon task, not a service, so it inherits the user's Claude Code login, PATH and `~/.claude`.

### tether-hub

Runs once, on the mini PC, as a systemd service.

- Joins the tailnet as its own node (`tether`) via `tsnet`, so it gets a stable name and can identify every caller with Tailscale `WhoIs`.
- Accepts **outbound** connections from agents and apps. Nothing ever needs to connect into a laptop or phone, which avoids NAT, sleep and battery-killer problems.
- Owns the canonical event log per session in SQLite with a monotonically increasing `seq`, so any client can reconnect and replay from where it left off.
- Runs the **renderer**: Claude Code stream-json and transcript lines in, typed contract events out ([protocol.md](protocol.md)).
- Routes commands from apps to the right agent, and approvals from agents to every connected app.
- Serves the NAS file API (browse, upload, download) for the app's Files view.
- Runs scheduled jobs (cron expressions → new headless session on a chosen node).
- Exposes an MCP server so a Claude session on any node can list nodes, start or read sessions elsewhere, and read or write NAS files. This is how nodes talk to each other.

### Flutter app

One codebase, two layouts.

- **Android:** tabs for Dashboard, Sessions, Files, Settings. Approvals arrive as notifications.
- **Windows:** multi-pane layout. Session list on the left, transcript in the middle, tool details or a second session on the right. Several sessions can be open side by side, which is the main improvement over the TUI.
- Renders only the contract's block and card types. It never sees Claude Code's raw format.

## Data flow: a prompt from the phone to the laptop

```
App ──session.send──► Hub ──agent.run──► Agent(laptop) ──stdin──► claude -p
                                                                      │ stdout: stream-json
App ◄──block.upsert── Hub(render + log, seq++) ◄──raw.event── Agent ◄─┘
```

Approval loop:

```
claude ──permission tool call──► Agent ──approval.request──► Hub ──approval.requested──► App(s)
claude ◄──────allow/deny──────── Agent ◄──approval.result─── Hub ◄──approval.respond──── App
```

## Technology choices

| Choice | Why |
|---|---|
| Go for hub and agent | Single static binaries for Windows and Linux, good concurrency for streaming, `tsnet` is a Go library. |
| `tsnet` | Hub is addressable as `tether` on the tailnet; `WhoIs` gives caller identity for free; no port exposed on the host's other interfaces. |
| Protobuf as the contract, JSON on the wire | One schema generates Go and Dart types so server and app can't drift. JSON (`protojson`) keeps frames readable while debugging. |
| WebSocket | Long-lived, bidirectional, works the same on Android and Windows. |
| SQLite (`modernc.org/sqlite`) | Pure Go, no CGO, so the agent cross-compiles to Windows easily. |
| `goldmark` with GFM | Parses tables, task lists and strikethrough the way Claude writes them. |
| Hub parses, agent forwards raw | One parser to maintain; agents stay thin and version-tolerant; raw events are kept so rendering can be re-run after parser fixes. |
| Spawning the `claude` CLI, not the Agent SDK | It uses the existing Claude Code login on each machine and behaves exactly like the user's TUI sessions. |
