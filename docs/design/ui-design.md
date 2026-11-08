# UI design: review of the generated designs, and the structure we build

Status: plan. This takes the design team's first output (`stitch_tether_developer_workspace`: a design system, home, chat, terminal and devices screens for phone and desktop, and a 3-pane desktop workspace) and decides, screen by screen, what we adopt, what we change and what we drop, so the app can be restructured to it. [v1-spec.md](../product/v1-spec.md) is the specification they drew from; [ui-overhaul.md](ui-overhaul.md) holds the rules and the checklist.

## 1. What the designs get right

Adopt as they are:

- **The identity.** Dark-first, dense, utilitarian; tonal layering instead of shadows; a 1 px outline for structure; emerald for what you can act on, amber for what needs you, red for failure, cyan as the second accent. Fits a tool for people who live in terminals, and is calmer than the current warm palette on an OLED phone.
- **Two typefaces with a job each.** Inter for the interface, JetBrains Mono for what is executed (commands, paths, ids, output). (Where the mockups drift from this, see section 3.)
- **The run card** (header with the current action and timer, a step list with durations, a segmented progress bar, Pause, Stop, Open run). It is the card we specified; the mockups show it better than the spec did.
- **Deliverables as cards in the chat** (an APK with Download and Install, a CSV with Preview and Download), and on the desktop a **Deliverables & artifacts** panel with hash, size and when.
- **The approval card with the change visible** (a diff, or the command, the machine, what it can touch, Deny and Allow). Right idea: the person decides on what will actually happen.
- **The machine card with a doctor checklist** (version, signed in, hooks, network, disk, each with a check) and **New chat here**; the connected-apps table with token fingerprint and **Revoke**; **Pair a new agent** with a code and one command.
- **The terminal key row** (Esc, Tab, sticky Ctrl, Alt, arrows, `/`, Enter, plus y, n, 1, 2, Paste, Clear) above the on-screen keyboard, and the desktop's hint line (Ctrl+C interrupt, Ctrl+L clear, Tab, Esc).
- **The 3-pane desktop**: machines and runs on the left, the conversation in the middle with a **Chat / Split / TTY** switch, deliverables and node health on the right.
- **Bounded scrolling** for logs and steps, middle-ellipsis for paths, the Tailscale strip as a slim banner.

## 2. What we change

### Information architecture

The mockups navigate the same things four ways at once, and that has to be settled before anything is built.

| Problem in the mockups | Decision |
|---|---|
| **Terminal** is a bottom tab, a sidebar entry, a top-bar entry *and* a Chat/Terminal toggle in the chat | It is a **mode of a session**, not a place. One control in the chat header (Chat · Terminal; on desktop also Split). No Terminal tab, no sidebar entry. A person who wants "the terminal" opens the chat they were last in and flips the control. *(Owner: if you want the tab, it opens the terminal of the current chat.)* |
| Desktop has a **top nav row** (Home, Workspace, Devices & Health, Terminal Mode) *and* the same list in the sidebar | One navigation: the sidebar. The top bar holds only the target chooser, the command palette, notifications and the account/device menu |
| **Home, Workspace, Active Sessions, Chat, Overview, Sessions, Nodes, Audits** all appear as places | Destinations are **Home, Chats, Devices, History, Files, Routines, Settings**. A chat's own views are Chat, Split, Terminal. *Audits* is dropped until the audit log exists ([agent-tools.md](../architecture/agent-tools.md#4-security)) |
| The phone bottom bar is Home, Chat, Terminal, Devices | **Home, Chats, Devices, More.** "Chats" opens the last chat (the list if none); More holds History, Files, Routines and Settings |
| "Active sessions" and "History" are two lists in the sidebar | One **Chats** list in the sidebar, grouped Today, Yesterday, Earlier, with a state dot for live ones; History is the searchable archive screen |

### The words

The mockups invent a vocabulary. We use ours ([v1-spec.md](../product/v1-spec.md#3-words-used-in-the-app)):

| In the mockups | In the app |
|---|---|
| "The Hub", "Coordinator node", "Fleet", "Mesh", "WireGuard mesh", "peer-to-peer", "WebRTC relay" | Hub, Devices, the private network (Tailscale). There is no WebRTC and no peer-to-peer layer |
| "Dispatch Agent", "Start Box", "Execute", "Run" | **Send** (the start box is "What should Claude work on?") |
| "Autonomous Agent Runtime", "Agent Orchestrator", "Electron Client" | Never shown. The app is Flutter |
| "operator@tether us-west-1 · master" | The device's name and the hub's address |
| "Allow & Proceed", "Authorize Run", "Block" | **Allow**, **Allow and accept edits**, **Deny**, as the assistant's own prompts say |
| Model names invented in the mockups (Claude 3.7 Sonnet) | The model the session actually reports |

### Typography

DESIGN.md says mono is for the execution layer. The mockups set section labels, chips, buttons, nav items, table headers and sentences in mono. Result: dense and hard to read, and it removes the contrast that makes commands stand out. **Rule: mono for commands, paths, ids, versions, numbers in tables and output; Inter for everything a person reads as language** (titles, labels, buttons, descriptions, section headings, nav). Section labels may be small caps in Inter.

### Touch, size and contrast

Measured on the design's own colours:

| Pair | Ratio | Needs | Verdict |
|---|---|---|---|
| Primary text on canvas | 17.4 | 4.5 | fine |
| Secondary text on canvas / card | 6.2 / 5.6 | 4.5 | fine |
| **Tertiary text on canvas / card / raised** | **4.1 / 3.8 / 3.3** | 4.5 | **fails** for the 11 px labels it is used on. Lighten it (about `#8b949e` at 80%, or `#7d8590`) or use it only for decoration |
| Dark text on emerald fill | 7.5 | 4.5 | fine |
| Amber and cyan on card | 8.1 / 8.1 | 4.5 | fine |
| **Red text on card / on raised (Deny)** | **4.6 / 4.0** | 4.5 | the destructive button fails; use `#f87171` or a filled red |
| **Subtle and strong border against canvas** | **1.6 / 2.3** | 3 for a control's edge | fine for cards (decoration), **not for inputs and key buttons**, which need `#6e7681` or a fill |

Touch targets: the mockups use 22 px chips and 36 px keys. Minimum for anything tappable is **44 px** on the phone (the chip may look 22 px and have a 44 px hit area); the key row stays 36 px visually with a 44 px hit height. Text below 12 px is not used for anything the person must read.

### Shape

4 px radius on cards, tiles, inputs and keys; full pills only for connection chips, as specified. This replaces the current 10 to 16 px.

### Light mode

The designs are dark only. The spec asks for light and dark in every palette. Decision: **"Tether" becomes the default palette with a designed light counterpart** (a cool grey ground, the same emerald, darker for contrast), and the existing palettes stay selectable. The design team should draw the light version of Home and Chat.

### Defects in the mockups to send back

- Desktop top bar: the **target selector overflows** its box and is clipped at the top of the window on every desktop screen.
- Phone header: "TETHER v1.0" collides with the screen title ("Ter…"), the logo is a **broken image**, and the connection chip ("Tailscale · 3") crowds the menu.
- Chips and the **target line truncate** to unreadable ("laptop · /va… Change", "Tasks: 1 working on server · 2 done on lapt…").
- The Home start box on the phone cuts the quick-run chips off the right edge.
- A **file-write approval contains a second question** (choose port :8080 or :3000). A question and an approval are different cards ([v1-spec.md](../product/v1-spec.md#d-asking-you-things)); do not combine them.
- The 3-pane desktop's left column duplicates the sidebar's list (Fleet registry and Active runs vs the sidebar's chats); decide one place for runs.
- Page titles read as button labels; no screen shows its own title in the content.
- No empty, loading, error or offline state is drawn for any screen. Each needs one ([ui-overhaul.md](ui-overhaul.md#the-rules)).
- No light theme, no tablet layout, no large-text layout.

## 3. What the designs show that is not real data (yet)

A mockup is not a spec. These elements need a data source, or they go.

| Element | Source in Tether | Verdict |
|---|---|---|
| Machine CPU, RAM, disk; online; Tailscale latency | The agent reports health; latency can be the hub's own ping | Real; ping per device is small work |
| Doctor checklist per machine | The doctor ([first-run.md](../plans/first-run.md#the-doctor)) | Real once the doctor is built |
| Running step list, progress bar, timer | The session's tool events and to-dos | Real |
| Context meter ("84.2k / 200k tokens") | Usage per session exists; the context window does not | Show tokens used; the window needs the engine to report it |
| Quick runners (`/fix-test`, `/review-git`, `/run-daemons`) | Pinned **skills** and the assistant's slash commands | Real, as a row of the owner's pinned skills and commands; none invented |
| Command palette (Ctrl+K) | New | Real and worth building: chats, devices, skills, actions |
| Notification bell | Notifications ([notifications.md](../plans/notifications.md)) | Placeholder until built |
| Deliverables panel, install, preview | [deliverables.md](../plans/deliverables.md) | Real once built |
| Connected apps with token fingerprint, revoke | Exists | Real |
| Pair a new node, with a one-line command and a code | The hub installer ([first-run.md](../plans/first-run.md#the-hub-installer)); the pairing code exists | The command shows the **owner's own hub address**, never a made-up domain |
| Fleet CPU load, "Success rate 97.8%", "Avg latency p95", "Total runs 142", "Mesh RTT graph", "Tunnel synced", "Fleet config", "Relay telemetry", "Subnet router reachable", "Execution hooks and tool jail", "Sandboxed runtime", "Auto-timeout 04:48" on approvals | Nothing | **Drop**, or defer until a feature produces them. They read as features that do not exist |
| "Split", "TTY" views | [terminal-mode.md](../plans/terminal-mode.md) | Real once terminal mode is built; Split is desktop only |
| "Audits" | The audit log | Defer |
| Pagination "Showing 4 of 18" | History | Real as a list with search, not a table with pages |

## 4. The structure we build

### Navigation

```
Phone (bottom bar)     Home · Chats · Devices · More (History, Files, Routines, Settings)
Tablet (icon rail)     the same, as a rail, with the chat list collapsed
Desktop (sidebar 280)  connection · Home · Devices · History · Files · Routines · Settings
                       Chats (grouped, live dots) · account / this device
Desktop top bar        target chooser · command palette (Ctrl+K) · notifications · account
```

A chat's header on every size: back (phone), title, where it runs with **Change**, **Chat · Terminal** (and **Split** on desktop), a menu. Under it: the Tasks strip when there are tasks.

### Desktop workspace (3 panes)

- **Left** (280): navigation and the chats list. Nothing else; runs are in the chat and on Home.
- **Center** (fluid, max 840): the conversation or the terminal or both (Split).
- **Right drawer** (440, collapsible, remembers its tab): **Files** (this chat's deliverables and attachments), **Inspect** (a diff or a file from a card), **Machine** (health of the device this chat runs on), **Terminal** when the center shows chat. Closes to give the center the room on narrow windows.

### Phone

One pane. Home is a scroll of Needs you → Running now → Chats. The chat is full width with the run card, steps, deliverables and the composer; Terminal is the same screen in the other mode with the key row. Files and the machine's health are sheets from the chat header.

### Home (both)

1. The **start box**: the prompt line, the target chip (Auto · laptop, with why), attach, send, and below it the owner's **pinned skills and commands** as chips.
2. **Needs you**: up to two approval or question cards in full; more collapse into "3 more waiting" opening a list.
3. **Running now**: run cards, compact.
4. **Chats**: grouped, searchable; on desktop a table with state, machine, files changed and last active (the mockup's table, without invented columns).

### Components to build (once, reused)

| Component | Notes |
|---|---|
| Status pill and **target chip** | 22 px visual, 44 px hit; dot + text, never colour alone |
| Card level 1 and level 2 | The two tonal levels from DESIGN.md |
| **Run card** | Header, step list, segmented bar, Pause, Stop, Open run; compact and full |
| **Approval card**, **Question card** | Restyle of the existing; one decision each |
| **File card**, result card, preview | [deliverables.md](../plans/deliverables.md) |
| **Machine card** with doctor checklist | Collapsed to the headline, expands |
| **Key row** and **terminal view** | [terminal-mode.md](../plans/terminal-mode.md) |
| Banner | One slim strip style for Tailscale, update, offline |
| Sheet and dialog | One look; always scroll inside a bound |
| Command palette | Ctrl+K |
| Empty, loading, error | One each, reused |

### Tokens

| Token | Value |
|---|---|
| Canvas / card / raised / overlay | `#0d1117` / `#161b22` / `#21262d` / `#2a313c` |
| Border subtle / strong | `#30363d` / `#484f58` (a control's edge uses a fill or a stronger line) |
| Text primary / secondary / tertiary | `#f0f6fc` / `#8b949e` / a lighter tertiary than `#6e7681` |
| Accent / second accent | `#10b981` (dark text on it) / `#38bdf8` |
| Green / amber / red | `#10b981` / `#f59e0b` / `#ef4444` (text uses `#f87171`) |
| Radius | 4 px; pills only for connection chips |
| Type | Inter (interface) and JetBrains Mono (executed) at the sizes in DESIGN.md; mobile sizes below 600 px |
| Spacing | 4, 8, 12, 16, 24; page margin 12 (phone) and 24 (desktop) |
| Elevation | Tonal layers and 1 px outlines; a shadow only on sheets and menus |

## 5. How we get there

Each phase ends with the app installed on the phone and the desktop and a screenshot comparison against its mockup, and with tests for the behaviour. Nothing in a phase changes what a feature does.

| Phase | What | Size | Needs |
|---|---|---|---|
| 0 | **Foundation**: the "Tether" palette (dark and a light counterpart), the tokens, 4 px shapes, Inter and JetBrains Mono bundled, the shared components | M | Decide light mode and the tertiary colour |
| 1 | **Shell and navigation**: the structure above, the command palette, the notification bell as a placeholder | M | The decisions in section 6 |
| 2 | **Home**: the start box with pinned skills, Needs you, Running now, the chats list | M | |
| 3 | **Chat**: header, run card, steps, deliverable cards, composer with mode and chips | L | The run card; `present_file` for deliverables |
| 4 | **Devices**: the machine card, doctor checklist, connected apps, pair a node | M | The doctor |
| 5 | **Desktop 3-pane** and the right drawer | L | Phases 1 to 3 |
| 6 | **Terminal mode** | L | [terminal-mode.md](../plans/terminal-mode.md) |
| 7 | **Files, History, Routines, Settings, first run** in the new style | L | [first-run.md](../plans/first-run.md) |

The palette, tokens and shapes (phase 0) can ship first and make every existing screen look like the design; the rest restructures screens on top.

## 6. Decisions

Settled by the owner on 2026-11-05.

1. **Terminal is a mode, not a tab**: Chat · Terminal · Split in the chat header.
2. **Light mode**: Tether stays dark-only by design; light uses the existing light palettes. The light side already in the palette stays but is not drawn by the design team.
3. **Default palette**: Tether is opt-in until phase 5, then becomes the default.
4. **Fonts**: bundle Inter and JetBrains Mono.
5. **Phone bottom bar**: Home, Chats, Devices, More; Chats opens the chat list.
6. **Pinned skills on Home**: pinned from the Skills screen.
7. **Desktop right drawer**: opens on demand.

## 7. Brief to send back to the design team

1. Fix the defects in section 2 (target selector, headers, truncation, broken logo, combined approval and question).
2. Settle navigation as in section 4: one sidebar, no Terminal tab, Chat · Terminal · Split in the chat header.
3. Use our words (section 2) and drop the elements in section 3's last row.
4. Set labels in Inter, mono only for what is executed.
5. Raise tertiary text and destructive red to 4.5:1, give inputs and keys a 3:1 edge, 44 px hit areas.
6. Draw the light version of Home and Chat, a tablet layout, and for each screen its empty, loading, error and offline states.
7. Draw the missing screens from [v1-spec.md](../product/v1-spec.md#7-screens): first run, connect, machine checklist, file preview, Files, chat Files panel, History and search, Routines and Skills, skill review, Notifications settings, Remove data, update screen.
