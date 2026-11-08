# Tether 1.0: feature specification

For the design team. It describes everything the 1.0 app does, what the person using it sees and decides, and where the design is still open. It is written so it can be read without the rest of the docs; where a feature has a longer technical document, it is linked at the end of that feature, and you can ignore those links.

**Status words.** *Built*: it works today and is tested. *Partly*: it works with gaps, listed. *New*: designed, not built. The 0.x versions continue until every feature here is built and tested; 1.0 is when this document is true.

## Contents

1. [What Tether is](#1-what-tether-is)
2. [Who it is for, and what they need](#2-who-it-is-for)
3. [Words used in the app](#3-words-used-in-the-app)
4. [Platforms and the two ways to see a session](#4-platforms-and-the-two-ways-to-see-a-session)
5. [Features](#5-features): A First run and connection · B Home and chats · C The conversation · D Asking you things · E Terminal mode · F Files, results and guides · G Skills and routines · H Devices and sessions · I Notifications and updates · J Settings and your data
6. [Key journeys](#6-key-journeys)
7. [Screens](#7-screens)
8. [Every screen needs these states](#8-every-screen-needs-these-states)
9. [Voice and content](#9-voice-and-content)
10. [Not in 1.0](#10-not-in-10)
11. [Open questions](#11-open-questions)

## 1. What Tether is

Tether is one app that brings all of a person's machines together under an AI coding assistant. Today the assistant is Claude Code. A person with a laptop, a home server and a phone usually has Claude Code on one of them, and the others are cut off from it. Tether connects them: you say what you want in one place, from any device, and the work happens on the right machine, with you able to watch it, answer it, and receive what it makes.

It is a **wrapper**, not a replacement. The assistant keeps doing the work in its own tools; Tether adds what is missing around it: a way to reach it from anywhere, a place to see and steer it, a shared memory of what you keep asking for, and a way to get files and results back to the device in your hand.

Tether runs on the person's own machines, over their own private network (Tailscale). Nothing is public and nothing leaves that network.

The parts, in plain words:

- **The hub**: a small server on a machine that is always on. Everything connects to it.
- **Agents**: a helper on each machine that has the assistant. It starts and watches the assistant's work there.
- **The app**: on a phone (Android) and on Windows. The thing you are designing.

## 2. Who it is for

**The owner**: one technical person with several machines, who already uses Claude Code, wants to use it from the phone and across machines, and does real work with it (code, servers, hardware projects, data jobs). 1.0 must work well for this person first, and must not assume *this* person's habits (see feature A, first run).

**A second person** who is shown how to install it: comfortable with a terminal, not the author. 1.0 should let them get to a first working chat without help.

What they need, in their words:

- "Let me ask for something from my phone and have it done on the right machine."
- "Tell me when it needs me, and let me answer from wherever I am."
- "Give me the file it made, here, now, without me going to find it."
- "Show me what it is doing, in detail if I want and in a line if I don't."
- "Don't make me set up the same thing twice, or ask it the same thing twice."
- "Don't lose my work when the network drops."

## 3. Words used in the app

Use one word per thing, everywhere.

| Word | Means |
|---|---|
| **Chat** | A conversation you start and keep. It has a title and a place where it works. What you see most. |
| **Session** | One running or finished run of the assistant on one machine. A chat has one or more. Mostly hidden; shown as *task* when a chat started it on another machine. |
| **Task** | A session a chat handed to another machine to do one thing and report back. |
| **Device** | A machine with the assistant on it (laptop, server). The phone is *this device*. |
| **Hub** | The always-on server. Shown only where the person needs to know (connection, devices). |
| **Target** | The device and folder a chat works in. |
| **Skill** | A saved routine the assistant can run instead of working it out again. Approved by the person. |
| **Routine** | Something the person keeps asking for, found in their history; can become a skill. |
| **File** | Anything sent to or made by the assistant: attachment, result, build, table, page. |
| **Guide** | An interactive page the assistant builds for something a chat can't show (a wiring diagram, an explorer). |
| **Approval** | The assistant asks permission to do something. |
| **Question** | The assistant asks the person to choose or explain. |

## 4. Platforms and the two ways to see a session

**Platforms.** Android phone, Windows desktop (also usable on tablets and narrow windows). Three layouts: under 600 px (phone: one pane, bottom bar), 600 to 999 px (icon rail), 1000 px and wider (sidebar with recent chats). Each screen says what changes between them.

**Two ways to see a session** (new for 1.0):

1. **Chat mode**: what the app shows today. The conversation as messages and cards: formatted text, tables, code, tool cards, to-dos, approvals. Good for reading, for the phone, for people who don't live in a terminal.
2. **Terminal mode**: a view that looks and works like the assistant's own terminal interface (monospace, the same prompt line, slash commands, keyboard shortcuts, the live screen). Good for the desktop, for people who know the terminal tool, and for anything the chat view can't express. On the phone it is available with the on-screen keyboard plus a row of special keys (Esc, Tab, arrows, Ctrl, Enter).

A person switches between the two for the same session at any time, with one control, without losing their place. The mode is remembered per device. Both show the same session; neither is "the real one". See feature E.

## 5. Features

Each feature lists: what it is for, what the person sees and does, the states to design, platform notes, status, and open questions.

---

### A. First run and connection

#### A1. First-run setup *(New; today's setup assumes the owner's existing setup)*

**For.** Getting from "I installed the app" to "my first chat is working on my machine", for a person whose setup is not the author's.

**Why it is a feature.** Today Tether works because the author already has Claude Code logged in, Tailscale running and a hub deployed. A second person hits each of those as a dead end with no explanation.

**What they see and do.** A guided flow of at most five steps, resumable, each skippable where it can be:

1. **Welcome**: what Tether does in two sentences, and a choice: *"Set up my first device"* or *"Join a hub I already have"*.
2. **Join a hub** (the common case after the first): scan a QR from another paired device, or type an address and a pairing code, or use the owner token. See A2.
3. **Set up a hub** (the first time ever): the app explains it needs one always-on machine on the same private network, shows the install command for it (one line, copyable, per operating system), and waits for the hub to appear. No hub, no Tether; this step must be honest about that.
4. **Add this machine's assistant** (agent): checks the machine and shows a **checklist** (A3), fixes what it can, tells the person exactly what to do for the rest.
5. **First chat**: a suggested first message ("What's on this machine?") and a tour pointing at the three things that matter: the box, a chat, the devices.

**States.** Nothing yet; checking; each check passing, failing with a fix, or skipped; the hub not found; the private network (Tailscale) not running; the assistant not installed or not logged in; done.

**Platform.** Phone: one step per screen, large buttons, QR scanner full screen. Desktop: the same steps in a centred card, with the commands to copy beside it, since the hub and agents are installed from a desktop terminal.

**Open.** Does the app install anything itself on the desktop (the agent), or only show the command? Does 1.0 include an installer for the hub, or is a command line enough?

*Longer doc: [first-run.md](../plans/first-run.md).*

#### A2. Connecting to the hub *(Built)*

**For.** Making this device a known, trusted client of the hub.

**What they do.** Three ways, shown as one choice: **Scan a QR** (shown by another paired app), **Enter an address and a code** (a short code from "Add a device"), or **Use the hub's token** (for the first device; tucked away). On a private network the owner's own devices can also connect **without a token** ("Connect over Tailscale").

**States.** Not configured; connecting; connected; wrong code; code expired; hub unreachable; certificate not trusted (self-signed hub, shown by its fingerprint to confirm); revoked (the hub no longer knows this device).

**Platform.** QR scanning is phone-only; desktop shows the QR for others.

#### A3. Machine checklist ("doctor") *(New)*

**For.** Telling the person, for each machine, whether it is ready, and why not.

**What they see.** A list per device: *Assistant installed*, *Assistant logged in*, *Version new enough*, *Private network up*, *Agent running*, *Hooks installed* (how Tether sees the assistant's activity), *Terminal tools present* (on Linux), *Disk space*, *Can reach the hub*. Each is a green check, an amber warning or a red cross with one sentence and one fix (a button where the app can fix it, a copyable command where the person must). Reachable from first run, from Devices, and from any device that shows a problem.

**States.** Checking; all good; some warnings; blocked; device offline (can't check).

#### A4. Private network (Tailscale) looked after *(Built)*

**For.** Reaching the hub from anywhere without the person managing the VPN.

**What they see.** Nothing, normally. When the hub can't be reached and the hub is on the private network, a slim banner under the header: "Starting Tailscale so the hub can be reached…", or "Tailscale needs you to sign in" (with a Sign in button), or what is wrong with **Try again** and **Open Tailscale**. On the desktop the app starts the network itself; on the phone it asks the Tailscale app to connect and falls back to opening it. It goes away when the hub answers.

**States.** Checking/starting; needs sign-in; not installed (with a link); needs admin rights (desktop); failed with a reason.

*Longer doc: [app.md](../architecture/app.md#tailscale-in-the-background).*

#### A5. Connection status *(Built)*

**For.** Knowing whether you are talking to the hub, and what the app is doing about it.

**What they see.** A small line (sidebar bottom on desktop, header on the phone): connected, connecting, offline with a countdown to the next try, the last error in plain words, and **Retry**. Reconnects by itself on network change, on resume and after a drop; never loses what was typed (see C4).

---

### B. Home and chats

#### B1. Home *(Built; to be redesigned)*

**For.** Starting work and finding it again. The first thing seen.

**What they see, top to bottom.**
- **The start box**: "What should Claude work on?", a message box, an attach button, and a small **target chip** showing where it will run ("Auto · tether on laptop", with why).
- **Devices strip**: "2 online · 1 offline", opens Devices.
- **Needs you**: approvals, sessions waiting on a reply, recent failures.
- **Running now**: sessions working.
- **Your chats**, grouped by Today, Yesterday, Previous 7 days, Previous 30 days, Older; search; an Archived filter.

**Actions.** Type and send; attach; change the target; open a chat; archive, rename, copy a chat from its menu; search.

**States.** Not connected; connecting; empty (no chats yet); loading; hub older than chats (shows sessions instead); a long list.

**Platform.** Phone: one column; the start box is compact. Desktop: sidebar lists recent chats, the main pane has the box and the lists.

#### B2. Starting a chat and choosing where it runs *(Built)*

**For.** The person says what they want; Tether decides where, unless they say.

**What they do.** Type and send. The target chip is one of: **Auto** (Tether picks the machine and folder from the words and from where they have worked), **Choose** (a picker: device, then folder, best match first), **Let Claude work it out** (it starts in a scratch folder, works out the place, says why, and moves), or **No project** (a scratch folder on the hub).

**What they see after sending.** The chat opens at once; the title is written from the first message and can be edited in place; under it, where the chat runs and why, with **Change**.

**States.** Auto has a clear pick; Auto has no pick (Claude will ask); the chosen device is offline; changing the target mid-chat asks whether to carry the conversation over.

#### B3. The chat screen *(Built; to be redesigned)*

**For.** The place the conversation lives.

**What they see.** Header: back, title (tap to edit), where it runs (with why and **Change**), a count of linked sessions, a menu. Below: the **Tasks** strip (C-less: see B4) when the chat has handed work to other machines; then the timeline (C); then the composer.

#### B4. Tasks on other machines *(Partly)*

**For.** A chat that spreads work across machines, so the person sees each piece and its progress without opening each.

**What they see.** A strip under the header: "Tasks · 1 working · 2 done", open while anything works. Each task: the machine and folder, what it is doing now, a progress bar from its to-do list, Done or Failed, how long ago. Tapping opens that task's own conversation. In the timeline, when a task finishes, a **result card**: what it did, the files it changed, the files it made.

**Today.** The strip works. The chat lead reports task results only when it chooses to; making the hub add each finished task to the chat itself is New.

**States.** None; working; some done; failed (with the error); the machine went offline mid-task.

#### B5. The run card *(New)*

**For.** One look to see that work is happening and how far along.

**What they see.** A rounded card in the chat while a session works: a spinner, the icon of the current tool, a present-tense line ("Editing src/billing/invoice.ts"), a timer; below it the model name, "Step N of M" and a segmented progress bar (from the to-do list); the last four or five steps (finished ones in past tense with durations, the current one dimmed); buttons **Pause**, **Stop**, **Open run**. When done: a green check, "Done in 13s · 6 files changed", and the buttons go.

**Platform.** Phone: the card is compact; steps fold. Desktop: more steps visible.

#### B6. Chats list: search, archive, rename, copy *(Built)*

Search over titles and places (search over content arrives with history, H4); archive hides a chat (a new message brings it back); rename in place; **Copy conversation** puts the whole chat as text on the clipboard.

---

### C. The conversation

#### C1. The timeline *(Built; to be redesigned)*

**For.** Reading what happened, as it happens.

**What they see.** Your messages (with the files they carry), the assistant's replies as formatted text (headings, lists, tables, code with colour), **tool cards** (what the assistant did: ran a command, edited a file, read, searched), to-do checklists, thinking (folded), notices, results (cost and time of a turn). Consecutive tool calls fold into one line ("Ran 12 steps") that opens in place. A card's header says what it did in a few words (`go test ./internal/hub +1`), never the raw command; the whole command is inside. Long output, diffs and code show their first lines with "Show all N lines". The list sticks to the newest message; scrolling up leaves it where you are with a button to jump down.

**Interactions.** Tap a card to open it. **Select text across messages** and copy, or **Quote** it into the composer. Tap a file to preview or save it (F).

**States.** Loading history; empty; streaming (text arriving); working (spinner row); a long chat; a very long message (shown with "Show full message"); an error turn.

#### C2. The composer *(Built; to be redesigned)*

**For.** Saying the next thing.

**What they see and do.** A box that grows, an attach button, a send button; a button to stop when the assistant is working. Enter sends on the desktop; Shift+Enter makes a new line; a **full editor** for long text. Attachments appear as chips (waiting, uploading, ready, failed). A draft is kept per chat. A message sent while the assistant is busy goes into its queue and shows as **Queued** until it is taken in.

**Permission mode.** A small control shows the session's mode (ask each time, accept edits, plan, and so on) and switches it, with an optional "for a while" that reverts by itself.

**Slash commands.** In terminal mode the assistant's own slash commands work. In chat mode a **command palette** lists the useful ones (compact, clear, model, mode) *(New)*.

#### C3. Interrupt, fork, resume, move *(Built)*

**Interrupt**: stops the assistant's turn; the button becomes a spinner, the row says "Stopping…", and if it doesn't stop within 8 seconds the person is offered Esc again, Show screen and End session. **Fork**: continue from here as a copy, leaving the original alone; shown as "Forked here" with a link to the parent. **Resume**: send a message to a finished session and it picks up. **Continue on the hub**: carry a laptop session onto the always-on machine so it keeps going when the laptop sleeps. **Move**: change the chat's target and carry the conversation.

#### C4. Messages are never lost *(Built)*

A message is kept on the device until the conversation shows it. If sending fails it stays with **Retry** and **Discard**; if the app is closed it carries on at the next start; a retry is the same message, so it never arrives twice. Attachments upload in the background and resume after a drop.

#### C5. Quoting, copying, sharing from a message *(Partly)*

Select text and **Quote** (built). Message-level actions are New: long-press a message for **Copy**, **Save to device** (for its files) and **Fork from here**.

---

### D. Asking you things

The assistant stops and asks. These must be impossible to miss, impossible to get stuck behind, and fast to answer, from the phone's lock screen if possible (see I).

#### D1. Approvals *(Built)*

**For.** The assistant wants to run a command, edit a file, or use a tool you haven't allowed.

**What they see.** A card above the composer: what it wants to do, in words (not only the raw command), the command or the change one tap away, the machine, and the buttons **Deny**, **Allow**, and where it makes sense **Allow and accept edits** (for a plan: **Approve plan**, **Keep planning**). The same card appears on Home under "Needs you" and, when the app is closed, as a notification (I).

**States.** Waiting; answered; the session ended before it was answered; several at once (stacked, newest last); answered elsewhere (on another device or in the terminal: the card goes away).

#### D2. Questions *(Built; being redesigned)*

**For.** The assistant needs a decision or some words.

**What they see.** A card that takes the questions **one at a time**: a step bar, a header chip, the question, "Pick one" or "Pick any", the options as large tiles with their descriptions, and a free-text box. **Back**, **Next** and, on the last, **Answer**; **Skip** lets the assistant carry on without. A card taller than the screen scrolls inside a bounded area while the conversation stays visible above it.

#### D3. Prompts and dialogs *(Built)*

**For.** The assistant's own terminal asks something (a trust prompt, a survey, a menu) that has no formal request behind it.

**What they see.** The same card style: the prompt text and its options, picked with one tap. If the app can't tell what the dialog is, a **Screen & keys** sheet shows the terminal's screen and a row of keys to press (in terminal mode this is simply the terminal).

#### D4. Stuck-session help *(Built)*

A banner when a session waits with no card: **Show screen**, **Esc again**, **End session**.

---

### E. Terminal mode *(New)*

**For.** People who know the assistant's own interface and want it as it is, and every case where the chat view can't express what is going on. It is also what makes Tether a real **wrapper**: whatever the assistant can show in a terminal, the person can use, from any device.

**What they see.** A full-bleed dark monospace view with the assistant's live interface: its prompt line, its slash-command menu, its status line and mode indicator, its spinner, its approvals and menus, exactly as on the machine. Text is selectable and copyable. A **mode switch** in the header changes between Chat and Terminal for the same session; scroll position and the unsent draft survive the switch.

**Input.**
- **Desktop**: the physical keyboard goes straight to the terminal: typing, arrows, Tab, Esc, Ctrl combinations, paste. Mouse selects and copies; wheel scrolls.
- **Phone**: the on-screen keyboard, with a **key row** above it for what a phone keyboard lacks: Esc, Tab, Ctrl (sticky), arrows, Enter, and a "more" for Shift+Tab, Home, End, Page up/down. A **paste** and a **quick-reply** button (1, 2, 3, y, n). Rotating to landscape gives a wider screen. Pinch to change the text size.

**Which sessions have it.** Sessions the assistant runs in a real terminal (a terminal multiplexer on Linux, a console on Windows, or a person's own terminal that Tether can see) give the live view. Sessions the assistant runs without a terminal give a **terminal-styled rendering** of the same conversation: same look, same prompt line, no live screen. The person sees one control either way. Other assistants (see F-wrapper below) appear the same way.

**States.** Connecting to the screen; live; the session ended (the last screen stays, greyed); the machine offline; the screen is larger than the phone (scrolls and zooms); a session that can only show the styled rendering (a small note says why).

**Open.** Does the terminal view replace "Screen & keys" entirely? Is the styled rendering for sessions without a terminal worth building for 1.0, or is the live view for terminal sessions enough?

*Longer doc: [terminal-mode.md](../plans/terminal-mode.md).*

---

### F. Files, results and guides

The person must be able to get *anything the assistant makes* in the chat, and *anything they have sent*, without leaving it, and download it to the device in their hand.

#### F1. Sending files *(Built; Home box Partly)*

**For.** Giving the assistant a screenshot, a document, a dataset, a recording.

**What they do.** Attach from the composer (any size; images, documents, audio, video, archives), or paste an image, or share a file *into* Tether from another app on the phone (New). Files upload in the background with progress; the message goes at once and carries the files when they are up; an upload that fails shows why with Retry; leaving the screen doesn't cancel it.

**States.** Waiting; uploading with speed and time left; paused; failed; done; too large for the hub's disk (said plainly).

**Gap.** The Home start box still waits for the upload before sending.

#### F2. Receiving what the assistant makes *(New; the pieces exist)*

**For.** "Build me a new APK from the laptop" from the phone, and the APK arrives in the chat. Or: a spreadsheet, a PDF report, a CSV, a log, a zip, a screenshot, a generated image.

**What they see.** Wherever the file was made, a **file card** in the conversation: the file's type icon and name, size, which machine made it, when, and the buttons **Download** (to the device, with progress, pause and resume for big files), **Open / Preview** where possible (F3), **Share**, and for an Android app file **Install**. At the end of a turn that made files, one **result card** gathers them ("3 files made"). The card is there the moment the file exists, not after the session ends.

**Large files.** Downloads are resumable and run in the background with a notification showing progress; a person can leave the app.

**States.** Making (file still being written); ready; downloading; downloaded (with where it went); failed; the machine that made it is offline (the hub keeps a copy, so the file is still downloadable); removed.

**Open.** Should the person confirm before a big download on mobile data? Where do downloads go on Windows and on Android, and can the person choose?

*Longer doc: [deliverables.md](../plans/deliverables.md).*

#### F3. Preview in the chat *(New)*

**For.** Looking at a file without leaving the conversation.

| Kind | In the chat |
|---|---|
| Images | The picture; tap to zoom |
| Text, Markdown, logs | First lines; expand; search inside |
| Code, JSON, YAML, diffs | Highlighted; line numbers; expand |
| CSV, TSV | A table: first rows, sortable columns, row count |
| Audio, video | A player |
| Interactive guide (HTML) | A guide card (F6) |
| PDF, Word, Excel, PowerPoint, archives, binaries, installers | **A file card only**: no preview, with **Download** |

A preview opens in place (a card that expands), as a sheet on the phone, and beside the chat on a wide window. Pointing at a row or region ("what's wrong with row 12?") attaches that reference to the message.

#### F4. The attachments section *(New; today only a global Files screen)*

**For.** Finding any file in a conversation, fast.

**What they see.** A **Files** panel inside every chat (a button in the header, a sheet on the phone, a side panel on the desktop): everything sent in and made in this chat, newest first, in two tabs (**You sent** / **Made for you**), filter by type, search by name, each row a file card with its actions. Plus the existing **Files** screen for everything on the hub: search, filter by type, session and size, sort, download, copy link, delete, with downloads and uploads shown as bars with speed.

**States.** Empty ("Nothing yet"); loading; many files (paged); a file removed by retention.

#### F5. Downloads and the device *(Partly)*

A downloads tray: active, paused, finished and failed, each with its file card; pause, resume, cancel, open, show in folder (desktop). Android shows the system notification; Windows saves to a chosen folder and offers to open it.

#### F6. Interactive guides *(Partly: the pages exist; the in-chat experience is New)*

**For.** Things a chat can't show: a wiring diagram for a hardware project (click a pin, highlight a connection), an architecture map, a runbook with checkboxes that remember where you are, a data explorer with filters and a chart, a calculator, a timeline, a live status dashboard.

**What they see.** When the person asks for something better explored than read ("give me an interactive guide to wire this"), the assistant builds a small website and the chat shows a **guide card**: its title, one line on what it shows, **Open** and **Copy link**. Opening it uses the browser (later, a pane beside the chat). It is always the latest version; the history is kept.

**It needs the private network.** If the hub can't be reached the card says so and offers to bring the network up (A4).

**Look.** Guides share one stylesheet in Tether's look (palettes, light and dark), served by the hub, so every guide feels like part of the app.

**Safety (what the person should understand).** A guide cannot reach the hub, other files or the network; it is a sealed page.

**States.** Building; ready; hub unreachable; deleted; an older version.

*Longer doc: [previews-and-guides.md](../plans/previews-and-guides.md).*

---

### G. Skills and routines

#### G1. Routines *(Built)*

**For.** Showing what the person keeps asking for, so they can save the effort.

**What they see.** A list of cards: the usual wording ("progress?"), how many times in how many sessions, whether it only looks at things or changes them, how clean the runs were, where it ran, when last. Open one for how it was worded and the steps most runs take (a step shown by what it does, the full command one tap away). Filters: last 30 days or all history; include routines with only two runs. **Draft a skill** on a card.

**States.** Reading history; none yet ("A routine shows up once the same kind of request has come up in at least two sessions"); a skill already exists for it (the button becomes "Review the draft" or the skill's name).

#### G2. Skills *(Built; real-use gaps)*

**For.** Saving a routine so the assistant runs it instead of working it out.

**What they see and do.** **Draft a skill** starts a session that writes it (it opens so they can watch). The draft appears under **Skills** as "Waiting for your approval". Opening it shows its text, whether it changes things (with a warning that the assistant will confirm first), what it was learned from, and its **versions**. **Approve** puts it in use; **Dismiss** refuses it for good; **Remove** takes an approved skill out of use; **Go back to this** makes an earlier version current. When the assistant corrects a skill (a step failed), it makes a new version with a note on why; the person is told.

**Choosing skills well (New).** When a chat starts, Tether offers the assistant only the few skills that fit the request, not the whole library, and records whether the assistant used one and whether it worked. The person sees, on a message, "Used skill: v2-sync-progress", and can say "that was the wrong skill". Skills that keep failing are flagged for review.

**States.** Waiting for approval; in use; corrected (new version); failing (needs review); removed.

*Longer doc: [skills.md](../plans/skills.md), [agent-tools.md](../architecture/agent-tools.md).*

---

### H. Devices and sessions

#### H1. Devices *(Built; to be redesigned)*

**For.** Seeing every machine and app in the setup, and whether each is healthy and current.

**What they see.** In install order: **Hub** (version, the machine it runs on, whether this app is connected, "update" if older than the app), **Devices running the agent** (this device first; each with agent and assistant versions, how many sessions live and total, "update" if its agent is older than the hub, a machine **checklist** link (A3)), **Apps** (the apps connected now, with versions, "this app" marked). Then **Add a device**: a QR and a short code, and the order to install in.

**Actions.** Open a device; add a device; revoke a device; disconnect this app; update.

**States.** Hub unreachable; a device offline (last seen); an older agent; a revoked device; nothing but the hub.

#### H2. A device's page *(Built)*

Its sessions (live and past, by folder), its health (CPU, memory, disk), the assistant's version, **New chat here**.

#### H3. Sessions across devices *(Built)*

Sessions the person started in a terminal appear live (read-only unless they choose to continue); they can be watched, approved, forked, or continued. A session can be marked done; it returns if it starts working again.

#### H4. History *(Partly; no screen yet)*

**For.** Finding and reusing what was said, across sessions and devices.

**What they see (New).** A chat's **combined history** across all its sessions as one timeline with markers for where each session and device began; **search** across all history; "**synced up to** 12:04" per device; **export** a chat or everything as text/JSON for other tools. Readable offline from the cache.

#### H6. Activity *(Built; to be redesigned)*

A feed grouped by day of what happened across the setup: sessions started, forked, continued on the hub, finished or failed, and files saved; each opens its session or file. Empty state: "Nothing yet".

#### H5. Usage and limits *(Built)*

Per machine: the plan's limits (the window and the week, from the assistant itself), tokens used today and over seven days, and a per-session breakdown. Each machine uses its own login; Tether only reports.

---

### I. Notifications and updates

#### I1. Notifications *(New; only update and download notifications exist)*

**For.** Not having to watch the app. The assistant needs you or has finished; the phone tells you.

**Kinds.**
- **Needs you now**: an approval or a question. Interruptive; actionable (**Allow** / **Deny** from the notification where the platform allows; "Answer" opens the card).
- **Finished**: a chat or task completed, failed, or is waiting for input. Quiet.
- **Something is wrong**: a device went offline, the hub can't be reached for a while, a skill keeps failing.
- **Ready**: a file the assistant made is ready (with Download).
- **Update available** (I2).

**Controls.** Per kind on or off; quiet hours; which devices notify (so the desktop and the phone don't both buzz); whether the notification shows content or just "Claude needs you" (privacy on a lock screen); sound and vibration on the phone.

**How it reaches the phone** (a design constraint, not a visual one): the phone is not always connected to the hub; the notification path must work when the app is closed and the phone is asleep, without a third-party cloud. The chosen approach is in [notifications.md](../plans/notifications.md); the design needs: a permission request at the right moment, an explanation if the person refuses it, and a "test notification" button.

**States.** Not yet allowed; allowed; denied (with how to fix it in system settings); a notification for something already answered elsewhere (it clears).

#### I2. In-app updates *(Built)*

**For.** Keeping the app, the agents and the hub current without a store or a trip to the machine.

**What they see.** A banner: "Tether 0.18.0 is available", **What's new** (the release notes), **Skip this version**, **Update**. Android: the download progresses and the system installer opens (first time it asks to allow installs from Tether). Windows: **Restart to update**; the app swaps itself and starts again. A release can mark older versions as **required**: then the app shows one full screen with the notes and one button, and nothing else until it is done. Devices running the agent update themselves when idle; Devices shows each one's version.

**States.** None; available; downloading (progress); ready to install; installing; failed (with Retry); required.

---

### J. Settings and your data

#### J1. Appearance *(Built)*

Light, dark or system; seven palettes (including the design system's own, "Tether") and an accent colour; code colours follow the palette. Shared across the person's devices.

#### J2. Connection and devices *(Built)*

The hub address and how this device is connected; **Add a device**; the list of paired devices with revoke; disconnect.

#### J3. Workspaces and codebases *(Built)*

Where the person's projects live on each machine (so "start here" and Auto know them); the hub's saved copies of projects and the names (not values) of the secrets they hold; take a snapshot now.

#### J4. Notification and update preferences *(New with I)*

#### J5. Your data: remove it, or remove Tether *(New)*

**For.** A clean exit, or a fresh start.

**What they do.** **Remove Tether data**: choose what (attachments, skills, chats, history, everything) and where (all devices, or specific ones); see a summary with sizes; confirm by typing a phrase; watch a progress list per device. A device that is offline gets the order **when it next connects**. **Uninstall** is the same with each machine's agent, hooks and settings entries also removed. The person's own project files and the assistant's own history are never touched.

**States.** Nothing selected; summary; confirming; running per device (done, waiting for the device, failed); finished.

*Longer doc: [uninstall.md](../plans/uninstall.md).*

#### J6. About *(Built)*

Version of the app, the hub and each agent; release notes; licences.

---

## 6. Key journeys

Design these end to end; each crosses several features.

1. **First run, new person** (A1 to A3, B2): install the app → join or set up a hub → add the machine → doctor passes → first chat → first answer. Time to first answer: under five minutes after the hub exists.
2. **Ask from the phone, work on the laptop** (B2, B4, C1): type "run the tests in the billing project" → Auto picks the laptop and folder → the chat opens → a run card shows progress → one approval arrives → result card.
3. **Build and deliver** (F2): from the phone, "build a new APK of the app from the laptop" → the chat hands it to the laptop → a run card with steps → the APK appears as a file card with **Download** and **Install** → installed.
4. **The hub is unreachable** (A4, A5): open the app with the network off → a banner starts the network → the hub answers → the banner goes → the chat continues. Variant: sign-in needed.
5. **Approve from the lock screen** (I1, D1): a notification "Claude needs you on laptop" with Allow and Deny → one tap → the session continues.
6. **A routine becomes a skill** (G1, G2): notice "progress?" in Routines → Draft → watch it write → review → approve → next time the assistant uses it and says so.
7. **Switch to the terminal** (E): in a running chat, flip to Terminal mode → type a slash command with the key row → flip back; nothing lost.
8. **Get a structured file** (F2, F3, F4): "export the failing rows as CSV" → a table preview in the chat → **Download** → find it later in the chat's Files panel.
9. **Understand a design** (F6): "give me an interactive wiring guide for this circuit" → a guide card → Open → click through → ask for a change → a new version.
10. **Clean exit** (J5): remove data on a lost device from another one.

## 7. Screens

| Screen | Purpose | Features |
|---|---|---|
| Welcome / first run | Get set up | A1 |
| Connect | Pair this device | A2 |
| Machine checklist | Is each machine ready | A3 |
| Home | Start, see what's running, find chats | B1, B2, B6 |
| Chat | The conversation | B3 to B5, C1 to C5, D1 to D4 |
| Chat in terminal mode | The live terminal | E |
| Chat files panel | Files of this chat | F4 |
| Target picker | Choose where a chat runs | B2 |
| Command palette | Slash commands in chat mode | C2 |
| Full editor | Long messages | C2 |
| File preview | Look at a file | F3 |
| Files | Everything on the hub | F4, F5 |
| Downloads tray | Active and finished | F5 |
| Guide viewer | Open a guide | F6 |
| Routines and Skills | Find, draft, review, approve | G1, G2 |
| Skill review | Text, versions, decision | G2 |
| Devices and a device's page | Machines, apps, health | H1, H2 |
| History and search | Past conversations | H4 |
| Usage | Limits and tokens | H5 |
| Notifications settings | What and when | I1 |
| Update banner and screen | New versions | I2 |
| Settings | Appearance, connection, workspaces, data | J1 to J6 |
| Remove data | Wipe and uninstall | J5 |

## 8. Every screen needs these states

Design each, once, and reuse: **loading**, **empty** (with one next action), **error** (what went wrong in plain words, one fix), **offline** (the hub is unreachable: what still works from the cache, what doesn't), **partial** (some data, some failed), **long content** (a 3-question card, a 60-step run, a 40-character title, a device with 12 sessions, a 2 GB file), **narrow** (400 px) and **wide** (1400 px), **light** and **dark** in every palette, **large text**.

Cross-screen rules: nothing is cut off and nothing blocks scrolling (cards taller than the screen scroll inside a bound); text that can be copied can be selected, with a visible highlight; work you started (an upload, a download, a draft) continues when you leave the screen and its state is visible from where you are; background work (connecting, starting the network, updating) is a slim banner, never a silent wait and never a blocking dialog; colour carries meaning and is never the only signal (accent: actionable; amber: needs you; green: done; red: failed).

## 9. Voice and content

Short sentences. Plain words. The same word for the same thing (section 3). Say what is happening and what the person can do ("Tailscale needs you to sign in" with a button, not "network error 7"). Never show a raw command, path or id as a title; show what it does, with the detail one tap away. Don't blame the person; say what to do. Don't use the assistant's name in the interface except where it is the product being used (setup, "Claude needs you").

## 10. Not in 1.0

Several people sharing one hub with roles and permissions; other assistants besides Claude Code as a first-class choice (the interface is designed so they fit: see [agent-tools.md](../architecture/agent-tools.md)); the second brain (shared memory across sessions); automations triggered by webhooks or schedules; iPhone and macOS apps; a public (non-private-network) way to reach the hub.

## 11. Open questions

For the design team and the owner. Decisions are marked **(owner)**.

1. **Terminal mode on the phone (owner):** is the on-screen keyboard with a key row enough, or should there be a gesture layer (swipe for arrows, long-press for Ctrl)?
2. **Terminal mode for sessions with no terminal (owner):** build the terminal-styled rendering of the chat for 1.0, or show only live terminals?
3. **Notifications (owner):** the delivery path needs a small always-on service on the hub and, on Android, either a background connection (battery cost) or a self-hosted push relay. Which trade-off is acceptable?
4. **First run (owner):** does the app install the agent on a desktop itself, or only show the command?
5. **Downloads (owner):** on mobile data, confirm before large downloads? Default download folders?
6. **Guides (owner):** open in the browser, or inside the app on the phone?
7. **Skill choice:** how visible should "used skill X" be: on every message, or only in a details line?
8. **One shell for both modes:** do chat mode and terminal mode share one header and composer area, or are they two screens with a switch?
9. **Navigation:** the phone has a bottom bar of three (Home, Devices, Activity) and a menu for the rest; is that right once History, Files and Routines are real destinations?
10. **Density:** the desktop shows much more at once than the phone; should the desktop adopt a three-pane layout (chats, conversation, files/preview)?
