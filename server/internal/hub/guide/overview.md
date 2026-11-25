# Tether: what it is and how its parts work

Tether is a self-hosted control plane for Claude Code. One **hub** (always on, on the user's own machine) knows every Claude Code **session** on every device; an **agent** on each device runs and mirrors sessions; the **app** (Android, Windows) is a client of the hub. Everything runs over the user's Tailscale network.

## Parts

- **tether-hub** (Go): keeps the session index, the event log and chats in SQLite; renders raw Claude Code events into typed timeline items (markdown, tables, code, diffs, checklists, tool cards); routes commands to agents; handles approvals; stores files (artifacts), project vault files and git repos for remote projects; serves the MCP server you are using now at /mcp; updates apps and agents.
- **tether-agent** (Go, one per device): starts and resumes `claude` sessions (in tmux or headless), indexes and mirrors sessions the user started in a terminal, installs hooks, syncs project folders for remote projects, and dials out to the hub (no inbound ports).
- **App** (Flutter): chats, devices, files, routines (skills), usage; sends commands to the hub.
- **tether-brain** (Rust, optional): the second brain (memories and notes linked to code) served over MCP.

## Words

- **Chat**: what the user sees: a title, messages, a target (device and folder). One *active* session is where messages go; others are linked (roles: main, moved, fork, started, linked). The session the user talks to **leads** the chat and hands work to **task** sessions on other devices.
- **Session**: one Claude Code conversation on one device, in one folder.
- **Node**: a device running an agent (the *hub's own machine* is a node too).
- **Project**: a folder a chat or session works in; the app groups chats and terminal sessions by project.
- **Remote project**: a chat whose project is kept in step on another device through a git repo on the hub; one writer at a time; secrets (.env) travel through a sealed vault, only to devices allowed.
- **Skill**: a saved routine (SKILL.md) learned from repeated requests, approved by the user, read with `read_skill`.
- **Rule**: a standing instruction the user saved (for example no comments in code); the hub adds the ones that apply to your system prompt; `list_rules` re-reads them.
- **Artifact**: a file kept on the hub (any size), shown in the app's Files.

## What you can do from a session

See the `tools` topic. Write files the user asked for into `.tether/out/` in your working folder and Tether delivers them to the chat. Write a web page under `.tether/pages/<name>/` with `index.html`.

## Guide topics

`tether_guide` topics: `overview`, `data` (where Tether keeps what, with the tables and how to read them), `features` (what is built and what is planned), `tools` (the MCP tools).
