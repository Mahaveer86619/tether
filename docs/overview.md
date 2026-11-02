# Overview

What Tether has to work with, how a chat becomes work on a device, and how sessions across devices are managed. The details are in the linked docs.

## What it has to work with

| Piece | Where | Job |
|---|---|---|
| **Hub** (`tether-hub`) | the mini PC, a systemd user service | The one source of truth: SQLite (sessions, timelines, chats, artifacts, usage, history), the artifact store on disk, the renderer, the update server, and an MCP server at `/mcp`. Agents and apps connect **out** to it, so no laptop or phone needs an open port. |
| **Agents** (`tether-agent`) | every machine with Claude Code: `laptop` (a scheduled task the app starts) and `minipc` (systemd) | Run and watch Claude Code on that machine: start, resume and stop sessions, mirror ones started in a terminal, hold approvals, report health, back up transcripts, fetch attachments. Each uses that machine's own Claude login. |
| **Apps** | Android and Windows (Flutter) | Talk only to the hub. Chats, live timelines, approvals, files, devices, usage. |
| **Claude Code** | on each agent machine | Does the work. Tether runs it headless (`claude -p`, stream-json) or in tmux, and installs hooks in `~/.claude/settings.json`. |
| **Hub MCP** | `/mcp`, registered with Claude Code on every agent machine | Lets a session see and use the rest of Tether: `list_nodes`, `list_sessions`, `start_session`, `send_message`, `read_session`, `wait_for_session`, `set_chat_target`, and the artifact tools. |
| **Tailscale** | the network | The hub listens on the tailnet; own devices connect without a token (`-trust-tailnet`). Nothing is public. |

See [architecture.md](architecture.md) for the diagrams and [security.md](security.md) for trust.

## How a chat starts

1. You type in the box on Home (optionally attaching files and choosing where). The app sends `POST /chats`.
2. The hub picks the **target**, a device and folder, in one of three ways ([chats.md](chats.md#targets)): *auto* scores the folders you work in against your words; *manual* is your pick; *claude* starts in a scratch folder and Claude works out the place and calls `set_chat_target`.
3. The hub creates the chat and its first session, and tells the target device's agent to start `claude` there with your message and a system prompt. The prompt makes this session the chat's **lead**: it lists the machines online and tells it to hand work elsewhere to task sessions.
4. The agent streams Claude Code's events back. The hub renders them into a timeline (messages, tool cards, to-dos, approvals), stores them, and pushes them to every app. A title is derived from your first message.
5. Later messages go to the chat's active session, resuming it if no process is live. If its session was cleaned up, the chat moves to a new session at its target, carrying the conversation.

## How sessions across devices are managed

- **One chat, many sessions.** A chat links sessions with roles: `main` (the first), `moved`, `fork`, `started` (started by Claude through `start_session`), `linked`. A session belongs to at most one chat.
- **Spawning.** The lead calls `start_session` with a device, a folder and `chat`. The hub tells that device's agent to start it. The new session is a **task**: its prompt says to do the one thing and end with a report. The chat shows it under Tasks with its device, folder and progress. The lead follows tasks with `wait_for_session` or `read_session` and reports back.
- **Where sessions run.** Linux: tmux windows. Windows: headless runs. Sessions you start in your own terminal are mirrored read-only; you can approve from the app and fork to continue ([hosting.md](hosting.md), [sessions.md](sessions.md)).
- **State and approvals** come from hooks, so a session you started yourself still shows as working or waiting, and its permission prompts and questions reach the app.
- **History** is kept on the hub, not only on the device. Agents upload transcripts incrementally, so the app reads history from the hub and a chat's timeline can span its sessions.
- **Files** go through the hub's artifact store. A file attached to a message uploads in the background, is linked to the message, and is delivered into the session's folder.
- **Updates.** Releases are built and deployed on the hub's machine ([releasing.md](releasing.md)). Apps and agents of 0.17 and later update from the hub.

## What is not built yet

The run-card UI, chats that follow a session on another machine live, the app's history views, other LLM providers, automatic skills ([skills.md](skills.md)) and a clean uninstall ([uninstall.md](uninstall.md)). See [roadmap.md](roadmap.md) and [plan.md](plan.md).
