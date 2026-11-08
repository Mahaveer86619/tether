# App audit: what the app does today, and where it goes in the rebuild

Taken from the code on 2026-11-06 (every screen and cubit in `app/lib/presentation`), for the presentation-layer rebuild described in [ui-design.md](../design/ui-design.md). Each row is a thing a person can do. **New home** is the screen that carries it in the rebuild; **Gap** is what is missing or wrong today and gets fixed on the way. Nothing here changes what the engine does; the cubits, use cases and data layer stay, and the views on top of them are rewritten.

## Navigation (fixed 2026-11-06)

A destination is a place, not a step. Switching between places leaves nothing to go back to; screens opened on top of a place (a chat, a device) are steps that Back pops; with nothing open, Back goes Home, and from Home leaves the app. The older rule kept a browser-style history, so a chat, then Settings, then Home, then Back reopened the chat.

## Start and chats

| Feature | Today | New home | Gap |
|---|---|---|---|
| Start a chat: prompt, attach files, target chip with live "Auto" preview, pinned-skill chips | Home box | Home | Files upload in the foreground; no model or permission-mode choice for a new chat (that existed only in the unreachable `new_session` form) |
| Pick where a chat runs: Let Tether decide, Let Claude work it out, no project, a device and folder | Target picker (dialog on desktop, sheet on phone) | Target chip on Home and in the chat header | |
| Chats list: search, group by period, archived filter, rename, copy conversation, archive | Chats page, sidebar Recents | Chats | **No delete.** No way to unlink a session from a chat or make a chat from a loose session (use cases exist, no UI) |
| Chat header: inline rename, target and why, change target, linked sessions with roles | Chat page | Chat header | |
| Tasks the lead started: working, done, failed, progress | Tasks strip | Chat, run cards | Stays a strip until the run card exists |
| A chat with no session: write to carry on | Chat page | Chat | |
| Old hub without chats: sessions listed instead | Chats page | Chats | Keep |

## A session (the conversation)

| Feature | Today | New home | Gap |
|---|---|---|---|
| Timeline: messages, thinking, tool cards, diffs, to-dos, folded runs, forks marker, subagent items | Session page | Chat | |
| Composer: send, queue (outbox with retry and discard), attach, stop, quote, fork mode, draft saved per session | Session page | Chat | No way to edit a queued message |
| Approvals, "allow and accept edits", plan approvals, trust-this-folder | Cards above the composer; also on Home | Needs-you cards | |
| Claude's questions (multi-step) and terminal prompts | Question card, prompt card | Needs-you cards | |
| Permission mode with revert timer | Mode chip | Chat header | Not choosable when starting |
| Interrupt, "Esc again", end session, stuck banner | Header, banners | Chat header, run card | |
| Fork, forked-from, forks list; continue on the hub; keep a copy on the hub; mark done | Header and More menu | Chat menu | |
| Screen and keys (text view of the terminal, key chips, typing) | Sheet | Terminal mode | Real terminal mode is planned ([terminal-mode.md](../plans/terminal-mode.md)) |
| Attach files to a session, its files, its pages, copy resume command, copy id | More menu | Chat menu and Files panel | |
| Rename or delete a session | none | Chat menu | Missing |

## Home and monitoring

| Feature | Today | New home | Gap |
|---|---|---|---|
| Needs you: approvals, ready sessions, failures in the last 24 hours | Home | Home | |
| Running now | Home | Home | Run card |
| Devices strip | Home | Header chip and Devices | |
| History of events by day (started, forked, finished, failed, saved) | History | History | Does not show the hub's synced history or search it |
| Pull to refresh, retry now, connection line | Home, sidebar | Header | |

## Devices

| Feature | Today | New home | Gap |
|---|---|---|---|
| Hub card (version, runs on), device cards (online, versions, capabilities, "update" pill), apps list | Devices | Devices | |
| A device page: live sessions, history, New chat here | Device page | Devices | Health (CPU, memory) is not reported yet |
| Adding a device: guide, pairing code and QR, copyable command | Settings and Devices | Devices and first run | |
| Tailnet list | Devices, Settings | Devices | |
| Revoke a device, disconnect this device | Settings | Devices | |

## Files

| Feature | Today | New home | Gap |
|---|---|---|---|
| Files: search, kind chips, session and size filters, sort, upload, download with pause and resume, copy link, delete | Files | Files | |
| Viewer: image zoom, text, download, open in browser | Viewer | Preview in the chat and Files | No preview for CSV, PDF, audio, video |
| Pages a session made, open in browser | Files, session menu | Files, chat | |
| A chat's own files (sent, made) | none | Chat Files panel | The hub endpoint exists; the screen does not |
| Delivered results (APK with Install, CSV) | none | Chat | Drop folder and endpoint built; no card |

## Learning

| Feature | Today | New home | Gap |
|---|---|---|---|
| Routines found from history, with steps and how it was asked | Routines | Routines | |
| Skills: draft, review text, approve, dismiss, versions, roll back, pin to Home | Routines | Routines (Skills tab) | |

## Settings and system

| Feature | Today | New home | Gap |
|---|---|---|---|
| Connect: hub address and token, pairing code, QR, Connect over Tailscale | Settings, first screen | First run | No guided setup; assumes a hub exists |
| Appearance: mode, seven palettes, accent | Settings | Settings | |
| Workspaces (roots per device) and Codebases (snapshots, locked files) | Settings | Settings | |
| Usage: plan limits, tokens per machine, sessions this week | Usage | Usage (under More) | |
| Tailscale banner with Sign in, Open, Get, Try again | Banner | Banner | |
| Updates: banner with notes, skip, update; forced update screen | Banner | Banner, Settings | **No "Check for updates" button** |
| Notifications | only update and download | Settings | All of it ([notifications.md](../plans/notifications.md)) |
| Remove data or Tether | none | Settings | All of it ([uninstall.md](../plans/uninstall.md)) |

## Dead code to remove

- `new_session/` (the old "new session" form and its cubit): nothing opens it. Its useful parts (model, permission mode, "New project" in a workspace root) move into the new-chat box as options.

## Decisions taken for the rebuild

1. Rebuild every view with one set of components in `presentation/ui/`, from the tokens in [ui-design.md](../design/ui-design.md). Cubits, blocs and the layers below them stay.
2. Destinations: Home, Chats, Devices, History, Files, Routines, Settings (Usage moves into Devices and Settings). Phone bar: Home, Chats, Devices, More.
3. Dense, mono for what is executed, left accent rails for "needs you" (amber) and "running" (green), uppercase mono section labels, Inter for everything else.
4. Add what is missing where it fits: delete and unlink chats, rename sessions, a "Check for updates" button, model and permission mode on a new chat.
