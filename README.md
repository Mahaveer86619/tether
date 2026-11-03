# Tether

A self-hosted control plane for Claude Code. Tether puts every Claude Code session on every machine you own into one Flutter app, on your phone and on your Windows desktop, over Tailscale.

The Claude Code TUI is great at one session in one terminal. Tether is for when you have several: one on the laptop, a couple running in a sandbox on a home server, one you started this morning and want to check from your phone. You see them all live, read their output properly rendered, approve their tool calls, continue or fork them, and start new ones anywhere.

## What it does

- **Chat first.** Say what you want in one box. Tether picks the machine and folder (or you do), starts the work there, and keeps the conversation in one chat, even when the work spans several machines.
- **One place for every session.** Sessions on every node, including ones you started in a terminal, live and properly rendered: Claude Code's raw event stream is parsed into typed blocks (Markdown, tables, code, diffs, checklists, tool cards). Claude is never told how to format its answers.
- **A chat that leads.** The session you talk to can hand work to task sessions on your other machines and report back; they show as tasks in the chat.
- **Approvals and questions from anywhere.** Permission prompts, plans and Claude's questions come to the app; answer from the phone or the desktop.
- **Continue anywhere.** Resume a laptop session from your phone, fork it, or carry it on to the home server.
- **Files both ways.** Attach anything, any size, from the phone; files and results Claude makes are kept on the hub and open from any device.
- **It learns your routines.** Requests you keep making are found in your history and can become skills Claude runs instead of working them out again, only with your approval.
- **Your own server.** The hub runs on a machine you own, over Tailscale. Nothing is public and nothing leaves your tailnet.

What exists, what is pending and where each part is described: [docs/features.md](docs/features.md).

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

**Setting up:** the hub first, then the agent on each machine, then the apps; updates go in the same order. See [docs/running.md](docs/running.md#install-order).

## Tech

| Part | Stack |
|---|---|
| `tether-hub`, `tether-agent`, `tetherctl` | Go, `coder/websocket`, `modernc.org/sqlite` (pure Go), `goldmark` (GFM) |
| Wire contract | Protocol Buffers (`buf`) → Go + Dart code generation; JSON encoding on the wire |
| App | Flutter for Android and Windows, BLoC/Cubit view models, `get_it`, generated Dart protobuf types |
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
  tools/release/        writes a release's latest.json and SHA256SUMS
app/                    Flutter app (android, windows)
deploy/                 systemd user units and deploy.sh, Windows install scripts, CI runner setup
tools/release/          version.sh, build.sh, build-windows.ps1, manifest.sh
.github/workflows/      ci (tests on every push and PR), release (on vX.Y.Z tags)
docs/                   design docs
```

## Building, releasing, deploying

```sh
cd server && go test ./... && go build -o bin/ ./cmd/...     # the Go side
cd app && flutter test && flutter build apk                   # the app
make release                                                  # on the hub's machine: test, build, deploy
git tag -a vX.Y.Z -m "Tether X.Y.Z" && git push origin vX.Y.Z  # CI builds, publishes and deploys
```

Every part shares one version (`VERSION`). Apps and agents update themselves from the hub. See [docs/releasing.md](docs/releasing.md) for releases, signing, the self-hosted runner and updates, and [docs/running.md](docs/running.md) for a first install.

## Status

Version 0.17. The hub, agents and app work end to end on the author's setup: a laptop, a home server and a phone. Chats, sessions across machines, approvals, files of any size, generated pages, usage, in-app updates and skill learning are built; see [docs/features.md](docs/features.md) for the exact state and the pending list. The next big piece is a pass over every screen before 1.0, planned in [docs/ui-overhaul.md](docs/ui-overhaul.md). See also [docs/roadmap.md](docs/roadmap.md) and [docs/running.md](docs/running.md).

## Docs

Start at [docs/README.md](docs/README.md).
