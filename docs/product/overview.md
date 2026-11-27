# Overview

What Tether has to work with, how a chat becomes work on a device, and how sessions across devices are managed. The details are in the linked docs.

## What it has to work with

| Piece | Where | Job |
|---|---|---|
| **Hub** (`tether-hub`) | the mini PC, a systemd user service | The one source of truth: SQLite (sessions, timelines, chats, artifacts, usage, history), the artifact store on disk, the renderer, the update server, and an MCP server at `/mcp`. Agents and apps connect **out** to it, so no laptop or phone needs an open port. |
| **Agents** (`tether-agent`) | every machine with Claude Code: `laptop` (a scheduled task the app starts) and `minipc` (systemd) | Run and watch Claude Code on that machine: start, resume and stop sessions, mirror ones started in a terminal, hold approvals, report health, back up transcripts, fetch attachments. Each uses that machine's own Claude login. |
| **Core** | `tether-hub`, `tether-agent`, `tetherctl` | The headless product. Runs on any device, pairs over Tailscale, and can start and drive chats from a shell or MCP client with no app installed. |
| **Apps** | Android and Windows (Flutter) | Optional views of hub state. Chats, live timelines, approvals, files, devices, usage. From v1 they do not own chat creation or session lifecycle. |
| **Claude Code** | on each agent machine | The main brain for reasoning and planning. Tether runs it headless (`claude -p`, stream-json) or in tmux, and installs hooks in `~/.claude/settings.json`. |
| **Sub-agent CLIs** | on agent machines | Antigravity CLI and OpenCode CLI are the first free-tier workers for large-context, bounded tasks. They are configured by core profiles, not bundled or wrapped. |
| **Hub MCP** | `/mcp`, registered with Claude Code on every agent machine | Lets a session see and use the rest of Tether: `list_nodes`, `list_sessions`, `start_session`, `send_message`, `read_session`, `wait_for_session`, `set_chat_target`, and the artifact tools. From v1 it also provides delegation and token-status tools. |
| **Herdr** | external (`github.com/herdrdev`) | An optional external harness. Herdr desktop/Android apps can replace the Tether apps as the view into core; Tether stays the source of truth. |
| **Tailscale** | the network | The hub listens on the tailnet; own devices connect without a token (`-trust-tailnet`). Nothing is public. |

The v1 goal is [core-first](plans/core-first-v1.md): the hub and agents are the MVP on every device, the apps are optional, and Herdr is an external client. Full v1 waits for core-owned token routing.

See [architecture.md](../architecture/architecture.md) for the diagrams and [security.md](../architecture/security.md) for trust.

## How a chat starts

Today the app's Home box sends `POST /chats`. From v1, the hub owns this journey and every client - app, `tetherctl`, Herdr or an MCP client - calls the same hub API:

1. A client creates a chat with a target device, folder/project, engine profile, initial prompt and mode (`main` or `subagent`).
2. The hub picks or confirms the **target** ([chats.md](../architecture/chats.md#targets)): *auto* scores the folders you work in against your words; *manual* is your pick; *claude* starts in a scratch folder and Claude works out the place and calls `set_chat_target`.
3. The hub creates the chat and its lead session, tells the target device's agent to start the configured main engine (Claude Code by default) there, and records the native session id when the agent reports it. The lead prompt lists the machines online and tells it to hand work elsewhere to task sessions.
4. The agent streams events back. The hub renders them into a timeline (messages, tool cards, to-dos, approvals), stores them, and fans them out to every authorized client. A title is derived from your first message.
5. The lead can spawn parallel **sub-agent sessions** through hub MCP tools. Claude Code stays the reasoning brain; Antigravity CLI and OpenCode CLI are the first free-tier workers for bounded, large-context tasks. The hub tracks each child and its token use.
6. Later messages go to the chat's active session, resuming it if no process is live. If its session was cleaned up, the chat moves to a new session at its target, carrying the conversation. Reconnecting clients reattach to the hub's chat; they do not fork a second lead.

## How sessions across devices are managed

- **One chat, many sessions.** A chat links sessions with roles: `main` (the first), `moved`, `fork`, `started` (started by Claude through `start_session`), `linked`. A session belongs to at most one chat.
- **Spawning.** The lead calls `start_session` with a device, a folder and `chat`. The hub tells that device's agent to start it. The new session is a **task**: its prompt says to do the one thing and end with a report. The chat shows it under Tasks with its device, folder and progress. The lead follows tasks with `wait_for_session` or `read_session` and reports back. In v1 the hub also exposes `delegate_task`, `wait_for_subagents`, `collect_results` and `cancel_task`, and limits parallelism by device capacity and token budget.
- **Where sessions run.** Linux: tmux windows. Windows: headless runs. Sessions you start in your own terminal are mirrored read-only; you can approve from the app and fork to continue ([hosting.md](../architecture/hosting.md), [sessions.md](../architecture/sessions.md)).
- **State and approvals** come from hooks, so a session you started yourself still shows as working or waiting, and its permission prompts and questions reach the app.
- **History** is kept on the hub, not only on the device. Agents upload transcripts incrementally, so the app reads history from the hub and a chat's timeline can span its sessions.
- **Files** go through the hub's artifact store. A file attached to a message uploads in the background, is linked to the message, and is delivered into the session's folder.
- **Updates.** Releases are built and deployed on the hub's machine ([releasing.md](../operations/releasing.md)). Apps and agents of 0.17 and later update from the hub.

## What is not built yet

The run-card UI, chats that follow a session on another machine live, the app's history views, automatic skills ([skills.md](../plans/skills.md)) and a clean uninstall ([uninstall.md](../plans/uninstall.md)). The v1 core work is [core-first-v1.md](../plans/core-first-v1.md): hub-owned chat creation, main/sub-agent orchestration, core-owned provider ranking and automatic fallback, a Herdr bridge, and separate core/app release tracks. See [roadmap.md](roadmap.md) and [plan.md](../plans/plan.md).
