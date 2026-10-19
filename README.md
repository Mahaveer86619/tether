# Tether

A self-hosted control plane for Claude Code. Tether puts every Claude Code session on every machine you own into one Flutter app, on your phone and on your Windows desktop, over Tailscale.

The Claude Code TUI is great at one session in one terminal. Tether is for when you have several: one on the laptop, a couple running in a sandbox on a home server, one you started this morning and want to check from your phone. You see them all live, read their output properly rendered, approve their tool calls, continue or fork them, and start new ones anywhere.

## What it does

- **One place for every session.** Lists sessions on every node, including ones you started in a terminal, with title, folder, branch, status and cost.
- **Live, properly rendered output.** Claude Code's raw event stream is parsed on the server into typed blocks (Markdown → headings, lists, tables, code; tool calls → diff, shell, checklist and file cards). Claude is never told how to format its answers.
- **Continue anywhere.** Resume a laptop session from your phone, or fork it into the home-server sandbox.
- **Approvals from anywhere.** Claude's permission prompts are routed to the app. Allow or deny from the phone or desktop.
- **Home server sandbox.** The mini PC runs sessions in isolated containers, with the NAS as their shared drive.
- **Nodes talk to each other.** A session on one machine can start or query a session on another through Tether's MCP tools.
- **Live dashboard.** Nodes, running sessions, current to-do lists, pending approvals, scheduled runs, spend.

## How it fits together

```
               Flutter app (Android + Windows)
                        │  WebSocket (protobuf/JSON), Tailscale only
                        ▼
  ┌──────────── tether-hub (mini PC, always on) ────────────┐
  │ session index · event log (SQLite) · renderer · scheduler│
  │ approvals · NAS file API · MCP server for agents         │
  └──────▲──────────────────────────────────▲───────────────┘
         │ outbound WebSocket               │ outbound WebSocket
  tether-agent (laptop, Windows)     tether-agent (mini PC, Linux)
   ├ starts `claude -p` stream-json   ├ runs sessions in sandbox containers
   └ indexes and mirrors TUI sessions └ NAS mounted as /workspace
```

Details: [docs/architecture.md](docs/architecture.md).

## Tech

| Part | Stack |
|---|---|
| `tether-hub`, `tether-agent`, `tetherctl` | Go, `coder/websocket`, `modernc.org/sqlite` (pure Go), `goldmark` (GFM) |
| Wire contract | Protocol Buffers (`buf`) → Go + Dart code generation; JSON encoding on the wire |
| App | Flutter for Android and Windows, Riverpod, generated Dart protobuf types |
| Home server | Ubuntu 24.04 mini PC, Docker sandboxes, NAS over SMB |

## Repository layout

```
proto/tether/v1/        wire contract (source of truth)
server/                 Go module
  cmd/tether-hub/
  cmd/tether-agent/
  internal/render/      stream-json and transcript lines → timeline items
  internal/hub/         routing, subscriptions, approvals
  internal/agent/       session index, headless runs, transcript mirror
  internal/store/       SQLite
  cmd/tetherctl/        terminal client for testing
app/                    Flutter app (android, windows), not started
deploy/                 systemd user units, Windows agent task
docs/                   design docs
```

## Status

The hub, agent and contract work end to end: sessions on the laptop and the home server are indexed, mirrored live, started (in tmux on Linux, headless on Windows), continued, forked and approved from `tetherctl`. Hooks give every Claude Code session, including ones you start yourself, live state and remote approvals; on Windows the app can even type into your own terminal sessions. The Flutter app ([app/](app/)) runs on Android and Windows. The Flutter app is next. See [docs/roadmap.md](docs/roadmap.md) and [docs/running.md](docs/running.md).

## Docs

Start at [docs/README.md](docs/README.md).
