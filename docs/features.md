# Features

One map of everything Tether does or will do: what state each is in, which screens it touches, and where its details live. When you want a change, name the feature and the screen; this page says where to look.

**Status:** *Built* works and has tests. *Partly* works, with the gaps listed. *Planned* has a design in a doc, no code. *Idea* is only a sentence. A built feature may still be unproven on a device; the notes say so.

## 1. Sessions and chats

| Feature | Status | Screens | Details | Pending |
|---|---|---|---|---|
| See every session on every machine, including ones started in a terminal | Built | Devices, a device's page, chats | [sessions.md](sessions.md), [hosting.md](hosting.md) | |
| Live timeline: messages, tool cards, to-dos, diffs, long output folded | Built | Chat and session screen | [app.md](app.md), [protocol.md](protocol.md) | Run card for a working session ([ui-overhaul.md](ui-overhaul.md#run-card)) |
| Approvals, permission modes, Claude's questions, prompts | Built | Session screen (cards above the composer) | [hosting.md](hosting.md), [app.md](app.md) | |
| Interrupt, resume, fork, continue on the hub | Built | Session menu | [sessions.md](sessions.md) | Branch and merge ([plan.md](plan.md#fork-branch-and-merge)) |
| Chats: a title, a target (device and folder), sessions linked to it | Built | Home, chat screen | [chats.md](chats.md) | |
| Where a chat runs: auto, by hand, or Claude works it out | Built | New-chat box, target picker | [chats.md](chats.md#targets) | |
| A chat leads and hands work to task sessions on other devices | Partly | Chat screen (Tasks strip) | [chats.md](chats.md), [overview.md](overview.md) | Not run live yet; a finished task's result is now posted into the chat by the hub (a plain note until the result card is designed) |
| Follow a remote session live inside the chat and message it | Planned | Chat screen | [chats.md](chats.md) | Streaming a linked session's timeline into the chat |
| Terminal mode: the assistant's own interface, live, beside chat mode; on the phone with a key row | Planned | Chat screen | [terminal-mode.md](terminal-mode.md), [v1-spec.md](v1-spec.md#e-terminal-mode) | Everything; today only a text "Screen & keys" sheet |
| Outbox: a message is kept until the session shows it | Built | Composer | [app.md](app.md) | |
| Reconnect: heartbeat, backoff, resume, network change | Built | Connection line | [app.md](app.md) | Phone flapping seen once, cause unknown |

## 2. Files, attachments and results

| Feature | Status | Screens | Details | Pending |
|---|---|---|---|---|
| Attach files; they upload in the background and the message carries their ids | Built (session composer) | Session composer | [plan.md](plan.md#images-and-artifacts) | The start-a-chat box on Home still uploads in the foreground |
| Artifact store: any size, resumable, hash-checked, signed links | Built | Files | [plan.md](plan.md#images-and-artifacts) | |
| Files a message carries stay on it | Built | Chat timeline | [app.md](app.md) | Messages before 0.17.x have no link |
| Hub sessions in scratch folders, retention | Built | Home | [plan.md](plan.md#hub-scratchpad-and-virtual-sessions) | |
| Generated pages: a site Claude builds, opened from any device | Built (basic) | Files → Pages, session menu | [plan.md](plan.md#generated-pages) | [Interactive guides](previews-and-guides.md#interactive-guides) |
| Preview of results and attachments inside the chat | Planned | Chat screen | [previews-and-guides.md](previews-and-guides.md#previews-in-the-chat) | |
| Ask for a thing and get the file in the chat (an APK built on the laptop, a CSV, a report) with Download and Install | Planned | Chat screen | [deliverables.md](deliverables.md) | `present_file`, the drop folder, result card, Install |
| A chat's Files panel: everything sent and made, easy to find | Planned | Chat screen | [deliverables.md](deliverables.md#4-the-chats-files-panel) | Only the global Files screen exists |
| Codebase snapshots and the `.env` vault | Built | Settings | [plan.md](plan.md#codebases-on-the-hub) | |
| Session history kept on the hub, with export for a second brain | Partly | Not shown in the app | [plan.md](plan.md) | History views in the app |

## 3. Learning and automation

| Feature | Status | Screens | Details | Pending |
|---|---|---|---|---|
| Find routines you keep asking for | Built | Routines | [skills.md](skills.md) | Tuning on more history |
| Draft, approve, correct and roll back skills; Claude uses them through the hub | Built; not run with a real draft yet | Routines → Skills | [skills.md](skills.md) | Choose skills well for each request ([agent-tools.md](agent-tools.md#3-choosing-skills-well)); native `~/.claude/skills` copy; auto-create for read-only skills |
| What Tether gives the connected assistant: tools for the machines, files, notifications; engines behind one contract | Partly (Claude Code only; tools partly) | | [agent-tools.md](agent-tools.md) | Engine contract; `present_file`, `notify_user`, `node_info`; other LLMs |
| Second brain: memories, graph, recall | Planned | | [plan.md](plan.md#second-brain-on-the-mini-pc) | |
| Automations from webhooks and schedules | Planned | | [roadmap.md](roadmap.md#m5-hub-chat-skills-and-automations) | |

## 4. Devices, network and access

| Feature | Status | Screens | Details | Pending |
|---|---|---|---|---|
| Hub, agents and apps, install order, updates from the hub | Built | Devices | [running.md](running.md), [releasing.md](releasing.md) | CI on GitHub not switched on |
| Pairing with a code or QR; per-device tokens; revoke | Built | Settings, Devices | [plan.md](plan.md#connecting-devices), [security.md](security.md) | |
| First-run setup that does not assume the author's machine; the machine checklist ("doctor"); a hub installer | Planned | First run, Devices | [first-run.md](first-run.md) | All of it; today's setup relies on an existing Claude Code and a hand-installed hub |
| Notifications: needs you, finished, ready, something wrong | Planned | Settings | [notifications.md](notifications.md) | Only update and download notifications exist |
| Security for 1.0: scoped credentials for the assistant's calls, an audit log, rate limits | Planned | | [agent-tools.md](agent-tools.md#4-security) | |
| Tailscale looked after in the background | Built; confirmed on the phone (auto-connect works) and the laptop | Banner under the header | [app.md](app.md#tailscale-in-the-background) | Desktop start and sign-in paths are tested against a fake command line only |
| Usage and plan limits per machine | Built | Usage | [plan.md](plan.md#usage-tracking) | |
| Users, roles, sharing | Planned | | [plan.md](plan.md#users-roles-and-visibility) | |
| Remove data or Tether, per scope and per device | Planned | Settings | [uninstall.md](uninstall.md) | |
| Other LLM providers and your own API keys | Planned | Settings | | Needs a design doc |

## 5. The app itself

| Feature | Status | Screens | Details | Pending |
|---|---|---|---|---|
| One home: start-a-chat box, what's running, your chats | Built | Home | [app.md](app.md) | Visual overhaul |
| Navigation: one cubit, sidebar, rail, bottom bar, back | Built | All | [app.md](app.md) | |
| Six palettes, accent colour, syntax colours | Built | Settings | [app.md](app.md) | |
| In-app updates with notes and skip | Built | Banner, Devices | [releasing.md](releasing.md) | |
| Selecting text, quoting into the composer | Built | Timeline | [app.md](app.md) | |
| The full visual overhaul before 1.0 | Planned | Every screen | [ui-overhaul.md](ui-overhaul.md) | All of it |

## How to use this page

- To ask for a change: "Feature: Routines, screen: Routines page, change: ..." is enough.
- To plan a release: the *Pending* column is the list. Anything marked *Planned* needs its design doc written or read first.
- Update this page with the change, in the same commit.
