# Hosting and tracking sessions

Tether never replaces Claude Code's own terminal UI. Sessions run as real Claude Code processes, and the agent hosts and watches them the way a terminal multiplexer like herdr would, so the app is just another client.

## Where sessions run

Each session reports a `host`:

| Host | What it is | What the app can do |
|---|---|---|
| `tmux` | Interactive Claude Code in a window of the agent's `tether` tmux session. Default on Linux and macOS when tmux is installed. | Everything: send messages, interrupt, approve. You can also attach from any terminal with the session's `attachCommand`, e.g. `tmux attach -t tether:claude-3ec9b0cd`, including over SSH from the phone. |
| `headless` | `claude -p` in stream-json mode, owned by the agent. Used on Windows, which has no tmux, or with `-host headless`. | Everything, plus live token streaming. There's no terminal to attach to; continue it later in a terminal with `claude --resume <id>`. |
| `terminal` | A session you started yourself in any terminal, seen through hooks. | Watch it live, see its state, approve its permission prompts, interrupt it. On Windows the agent can also type messages into it (see below); elsewhere, fork it to continue from the app. |
| `none` | No live process. | Read the history; send a message to resume it (in tmux or headless). |

The agent's tmux windows survive agent restarts and upgrades: the systemd unit uses `KillMode=process`, and windows are matched back to sessions through the pane option `@tether_session`.

### Input into tmux sessions

Messages are delivered as one bracketed paste followed by Enter, so multi-line text arrives as a single message. Interrupt sends Escape.

### Folder trust

Interactive Claude Code asks "Do you trust this folder?" the first time it opens a directory (headless mode doesn't). The agent watches new tmux windows for that dialog and turns it into an approval of kind `FOLDER_TRUST`. When answered, it moves the selection and confirms while watching the screen. Keys sent while the TUI is still starting are dropped, so a blind keypress isn't reliable.

### Dialogs on screen

Some of Claude Code's dialogs fire no hook: feedback surveys (like the auto-mode survey), pickers, and menus. Unanswered, they leave a session waiting with nothing in the app to act on, and a message typed then lands in the dialog. To catch them, the agent reads the screen of every interactive session it can reach every 2 seconds: tmux panes with `capture-pane`, and Windows consoles with `AttachConsole` plus `ReadConsoleOutputCharacter`.

- **Parsing** (`agent/prompt.go`):
  - It strips box borders, then looks at the last 24 lines for one of two shapes. The first is a vertical menu with the `❯` cursor on one option, numbered or not. Description lines may sit between numbered options, and a `✔` mark is dropped. The second is a one-line survey like `1: Bad  2: Fine  3: Good  0: Dismiss`.
  - The title is the nearest text above the options.
  - Lists without a cursor, such as a numbered list in Claude's answer, aren't dialogs.
- **Cards:** a dialog becomes an approval of kind `PROMPT`, with its options, the cursor's option and the screen. It is withdrawn when the dialog leaves the screen, and replaced when a different one appears. Dialogs a hook already reported (tool permissions) aren't asked twice. The folder-trust watcher keeps its first 20 seconds.
- **Answers:** an option is picked by moving the cursor (re-reading the screen after each key, since the TUI drops keys while redrawing) and pressing Enter. A survey option is picked by pressing its key. Deny presses Esc. `ApprovalDecision.option` is 1-based, and 0 takes the option under the cursor, so an older app's Allow picks the highlighted option.
- **The way out:** for anything the parser misses, `GET /api/v1/sessions/{id}/screen` returns the current screen. The hub asks the node and waits up to 4 seconds. `POST /api/v1/sessions/{id}/keys` presses keys (Enter, Escape, arrows, Tab, Shift+Tab, Space, Backspace, digits) and types text. The app has "Screen & keys" in the session menu and on every prompt card, and a banner when a session waits for approval with no card. Headless runs have no terminal; their questions come through the control protocol.

### Permission modes

Every session shows its permission mode: default ("Ask first"), acceptEdits, plan or auto.
- **Where the mode comes from:** the transcript's `permissionMode` field (the init line and user lines, not subagents'), or the last switch made from an app. It's kept on `SessionInfo.permission_mode`, which agents' own reports don't touch.
- **Switching:** `POST /api/v1/sessions/{id}/mode` with `{mode, revertAfterMs}`. The hub shows the new mode at once and sends the node `AgentCommand.set_mode`, then the node does one of three things:
  - A headless run gets a `set_permission_mode` control request.
  - An interactive session (tmux, or a Windows console the agent can attach to) gets Shift+Tab presses, Claude Code's own mode cycle. The agent presses until the mode line at the bottom of the screen shows the mode, up to 6 times. It refuses while a dialog is open.
  - With no live process, nothing happens yet. The next resume (`SendInput.permission_mode`) and every fork start in the mode the session shows.
- **When a switch fails:** the agent answers with `ModeResult`. On an error, the hub puts the old mode back and shows why on the session. While a switch is unanswered, older transcript lines can't put the old mode back. That lasts up to 30 seconds, because an agent from before modes never answers.
- **For a while:** with `revertAfterMs`, the hub stores when to go back, and what to, on the session. It's kept with the session, so it survives a restart. Every 15 seconds the hub checks for modes that are due and switches them back. A node that's offline is tried again later.
- **In the app:** a chip in the session header shows the mode, and "· 12m left" when it goes back. It opens a picker (Ask first, Accept edits, Plan, Auto; for good, 15 min or 1 hour). Edit approvals in the default mode offer "Allow, accept edits". A plan approval (`ExitPlanMode`) offers "Approve plan", "Approve, accept edits" and "Keep planning".

## Typing into your own terminal (Windows)

On Windows the agent finds the Claude Code process behind each hook request (the hook's loopback connection → `GetExtendedTcpTable` → owning PID). It can then type into that process's console with `AttachConsole` + `WriteConsoleInput`, exactly as if you had typed there. Such sessions report `terminalInput: true`, and the app's composer works for them.

- The text is typed first and Enter is sent on its own a moment later (300 ms, more for long messages). Claude Code reads a burst of keys as a paste, and an Enter inside a paste is only a newline. A message sent while Claude is busy goes into Claude Code's own queue, just like typing it there.
- Line breaks are typed as Ctrl+J, Claude Code's newline key, so a multi-line message is submitted once.
- Interrupt types Escape into the console.
- This needs the agent to have no console of its own, which is why the Windows agent is built as a GUI-subsystem program (`-H=windowsgui`). Claude processes it starts get `CREATE_NO_WINDOW`, so nothing pops up.
- Other systems don't allow typing into another process's terminal (`TIOCSTI` is disabled on modern Linux). There, run sessions in tmux.

## Interrupting and ending

| | Interrupt (stop the current turn) | End (close the session) |
|---|---|---|
| `tmux` | Escape in the pane | Types `/exit`; kills the pane if it is still there after 5 s |
| `headless` | stdio control `interrupt` | Closes stdin; kills the process after 5 s |
| `terminal` | Escape typed into the console (Windows only) | Refused: it's your terminal; close it there |

Claude Code fires no Stop hook when a turn is interrupted, so the agent marks interactive sessions `ready` itself.
- **Confirming the stop:** after Escape, the agent re-reads the screen every 300 ms until the spinner's "esc to interrupt" is gone. If that hasn't happened within 6 seconds, it reports `CommandResult{command: "interrupt"}` with an error, which the hub shows on the session. A session without a readable screen is marked ready after a second, as before. Failing to deliver the interrupt at all is reported the same way.
- **In the app:** the interrupt button turns into a spinner, and the working row reads "Stopping…" until the session stops. If it's still busy after 8 seconds, a banner offers Esc again, Show screen (for sessions with a terminal) and End session (confirmed first, for sessions the agent hosts).

## Removing sessions

When a transcript is deleted, the agent reports it in `sessionIndex.removed` at the next scan. On every (re)connect it also sends a full index, and the hub forgets that node's other sessions. Live sessions are never removed this way, since their transcript may not exist yet. Clients receive `sessionRemoved` and drop the session and its cached history.

## State tracking with hooks

The agent installs HTTP hooks into Claude Code's user settings (`~/.claude/settings.json`). They POST each event to the agent on `127.0.0.1:7421`. Existing settings and hooks are kept, a backup is written once to `settings.json.tether-backup`, and `tether-agent uninstall-hooks` removes Tether's entries again. Run the agent with `-hooks=false` to skip this.

| Hook event | State |
|---|---|
| `UserPromptSubmit`, `PostToolUse` | `running` |
| `PermissionRequest`, `Notification` (`permission_prompt`) | `awaiting_approval` |
| `Stop`, `Notification` (`idle_prompt`) | `ready` |
| `SessionEnd` | closed (`host` becomes `none`) |

A terminal that is closed without exiting Claude Code never sends `SessionEnd`. On Windows, where the agent knows each session's process, it checks on every scan whether that process still exists and closes the session if not.

Because hooks fire for every Claude Code session for that user, sessions you start yourself show the same live states as Tether's own.

### Approvals from anywhere

A `PermissionRequest` hook is held open while the request goes to the app. Claude Code shows its normal prompt in the terminal at the same time, and **whichever answers first wins**:

- Answered in the app: the hook returns `allow`/`deny`, and the terminal shows "Allowed by PermissionRequest hook".
- Answered in the terminal: the next hook event from that session (or the hook request being cancelled) withdraws the approval from the app.

If the agent isn't running, the hook request fails, Claude Code treats that as a non-blocking error, and the terminal prompt works as usual. Headless sessions answer prompts through the stdio control protocol instead, and the hook steps aside for them.

Claude's questions (`AskUserQuestion`) arrive the same way, as a permission request for that tool, and are sent to the app as `kind: QUESTION`. The answer goes back as `allow` with `updatedInput`: the original questions plus `answers`. Claude Code then carries on as if they had been picked in its own picker.

## Without hooks

Sessions that started before the hooks were installed, or on a machine running with `-hooks=false`, fall back to a heuristic. A transcript written in the last 90 seconds by something other than the agent is shown as `terminal_active`, and the app can only mirror or fork it.
