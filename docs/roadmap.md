# Roadmap

Each milestone ends with something usable.

## M0: Contract and fixtures

- `proto/tether/v1` with envelope, commands, events, blocks and tool cards. `buf generate` for Go and Dart.
- Recorded fixtures: real stream-json runs and TUI transcripts covering text, tables, code, Bash, Edit, Write, TodoWrite, sub-agents, approvals, errors and interrupts.
- Renderer in Go, tested against the fixtures with golden files.

**Done when:** every fixture renders into contract events with no "unknown" blocks except genuinely unknown tools.

## M1: One laptop session on the phone

- `tether-agent` on Windows starts `claude -p` in stream-json mode and forwards raw events.
- `tether-hub` on the mini PC, SQLite event log, replay by `seq`.
- Flutter Android app: session view rendering blocks and tool cards live, send messages, interrupt.
- Approvals round-trip to the app.

**Done when:** you can start a session on the laptop from the phone over mobile data, watch it work, approve a Bash command and read a rendered table in the reply.

## M2: Every session, every node

Done so far: session indexing, live mirroring, resume and fork; tmux hosting on the mini PC; hook-based state tracking and approvals for every session on both machines.


- Session indexing from `~/.claude/projects`, live mirroring of terminal sessions, resume and fork.
- Agent on the mini PC (host mode first).
- Windows build of the app with the multi-pane layout.
- Dashboard: nodes, running sessions, to-do lists, pending approvals.

**Done when:** a session started in the laptop TUI shows up live in the app, and after closing the terminal it can be resumed from the phone and then again from the TUI.

## M3: Home server sandbox and NAS

- Storage root with the `tether/` layout, Files view in the app (browse, upload, download). Starts on a local folder on the mini PC; switches to the NAS mount once its credentials are available.
- Sandbox containers for mini PC sessions.
- Move a session from the laptop into the sandbox.

**Done when:** a laptop session can be forked into a sandbox on the mini PC, working on a NAS folder, while the laptop is asleep.

## M4: Nodes talking to each other, schedules

- Hub MCP server: `list_nodes`, `start_session`, `read_session`, `nas_read`, `nas_write`.
- Scheduled runs on a node with results in `outputs/` and on the dashboard.
- Notifications for approvals and finished runs when the app is in the background (UnifiedPush via a self-hosted ntfy on the mini PC).

**Done when:** a laptop session can ask the sandbox to run a long job and get the result back, and a 7 am scheduled run shows its result on the phone.

## M5: Hub chat, skills and automations

- **Hub chat:** start a conversation without picking a device. It runs on the mini PC in a central scratchpad (one folder per session) and reaches the other nodes through the hub MCP server from M4. This is the default when the hub is reachable.
- **Ingestion:** the app attaches files, images and audio. They're stored with the session on the mini PC, and the session can read them. Artifacts the session produces are saved there too and can be opened from the app.
- **Retention:** scratchpad sessions older than a threshold are archived, then deleted.
- **Device awareness:** a skill, installed on every node, that tells Claude which nodes exist, what each one is for and how to reach it.
- **Custom skills from the app:** turn what was done in a session into a reusable skill (for example, "check the ping script and fix the VPN") and install it on chosen nodes.
- **Automations:** a webhook (such as an existing alert) creates a pending run. The app asks for confirmation, then the run starts on the chosen node with a skill and can be watched live.

**Done when:** a failing ping check posts to the hub, the phone asks "start the VPN fix?", and after confirming, the fix runs on the mini PC and is visible in the app.

## M6: Users and sharing

- **Users on one hub:** each user has their own login and token, and owns their own nodes.
- **Shared access:** a user can grant others access to a whole node, or just to one service on it.
  - A service is something like a script watcher with an agent attached, for example one that spots GitHub issues and fixes them automatically.
  - Grants can be view-only, can allow answering approvals, or can allow starting runs.
- **Credentials:** every session runs on the Claude login of the node it runs on, and uses only that login's usage. Collaborating means sending commands to someone's node with their permission, as the app does today. Usage is never pooled or moved between accounts.
- **Pairing:** devices join with a QR code and get their own revocable token. See [plan.md](plan.md#connecting-devices).
- **Shared memory:** the knowledge graph and session history act as a knowledge base that users opt in to, so sessions can draw on what others have learned.

**Done when:** a second user can watch and approve runs of a shared watcher service on the first user's mini PC, and start sessions on their own laptop, from one hub.

## Later

- Knowledge graph and vector memory on the mini PC (LangChain), shared by every session as a second brain.
- Adapters for other agents (Codex CLI, Gemini CLI, local models) behind the same contract.
- Custom dashboard sections defined by the user and generated by Claude, rendered as server-driven UI.
- Cost and usage analytics per node and project.
