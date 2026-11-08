# Terminal mode

Status: plan. The design team's view of it is in [v1-spec.md](../product/v1-spec.md#e-terminal-mode); this page is how it is built.

## What it is

A second way to see the same session: the assistant's own terminal interface, live, on any device. Chat mode (today's screen) reads the conversation as messages and cards. Terminal mode shows the real screen and takes real keys. Both are views of one session; switching loses nothing.

It is also what makes Tether a wrapper in the full sense: anything the assistant can show in a terminal, the person can use from the phone or desktop, even what the chat view can't express.

## What exists

- The agent already reads the screen of every interactive session it can reach every 2 seconds (tmux `capture-pane`; on Windows `AttachConsole` and `ReadConsoleOutputCharacter`) to find dialogs ([hosting.md](../architecture/hosting.md#dialogs-on-screen)).
- `GET /api/v1/sessions/{id}/screen` returns the current screen as text; `POST /api/v1/sessions/{id}/keys` presses keys and types text (Enter, Escape, arrows, Tab, Shift+Tab, Space, Backspace, digits, single characters).
- The app has a "Screen & keys" sheet that shows that text and a row of keys.

What is missing: colour and attributes (the screen is plain text), streaming (it polls), a real terminal widget, a keyboard that works like a terminal, and a way to look like the terminal for sessions that have none.

## Two kinds of terminal mode

| Kind | For which sessions | What it shows |
|---|---|---|
| **Live terminal** | Sessions in a real terminal the agent can reach: tmux on Linux, a Windows console, a person's own terminal | The actual screen, with colour, updating as it changes; real keys |
| **Terminal-styled view** | Sessions with no terminal (headless runs, other assistants through an API) | The same conversation drawn like the terminal interface: monospace, the prompt line, the status line; input is the prompt line, slash commands are mapped to app actions |

The person sees one control (Chat | Terminal). Where only the styled view exists, a small note says why.

## Live terminal: how

**Output.**
1. *First version*: use the existing screen call with colour (`capture-pane -e` returns the screen with escape codes), refreshed at 2 to 4 times a second while the view is open, fed to a terminal emulator widget in the app. No protocol change beyond an `ansi` flag on the screen call.
2. *Streaming*: tmux control mode (`tmux -C`) sends `%output` events as bytes arrive, which the agent forwards. New frames: `TerminalOpen{session, cols, rows}`, `TerminalOutput{session, seq, bytes}`, `TerminalInput{session, bytes}`, `TerminalClose`. The hub relays only to apps that opened the terminal; the agent stops streaming when none are watching. Windows consoles stay on polling (diffed) since there is no output stream to attach to.
3. *Size*: the app **never resizes the real terminal** (a window is shared with whoever is attached, and a phone's size would squash a desktop session). It draws the real size, scrolls and zooms on small screens.

**Input.**
- Desktop: key events go as bytes (`TerminalInput`), including Ctrl combinations, arrows and paste (large pastes ask first).
- Phone: the on-screen keyboard plus a key row (Esc, Tab, sticky Ctrl, arrows, Enter, more: Shift+Tab, Home, End, Page up/down), paste, quick replies (1, 2, 3, y, n).
- A *mirrored* session (started in the person's own terminal) is read-only until they choose to type into it; the app says so.

**Emulator.** A terminal widget (the `xterm` package for Flutter is the starting point) that takes the bytes, handles the common escape sequences the assistant's interface uses (colour, cursor movement, alternate screen) and gives selection, copy and scrollback. It is a widget in the app only; no new dependency on the servers.

## Terminal-styled view: how

Built from the structured timeline the hub already has, so it works for every session and every assistant: user messages as the prompt lines, replies as plain text, tool calls as the assistant's one-line tool entries, approvals as its permission prompts, the status line from the session's mode, model and cost. Input is a prompt line; slash commands the app can honour (clear, mode, model, compact where it exists) are mapped; the rest say they need a live terminal. It is a renderer, not a new data path.

## Security

Terminal input is full control of a session, so it follows the same rules as sending a message and no weaker: only authorised devices; a hub audit line per open terminal and per paste over a threshold; large pastes and anything sent while a dialog is open need a tap to confirm; a read-only mode for mirrored sessions; the hub never stores terminal output (it is relayed, not logged) unless the person has history sync on for that device.

## Build order

1. Colour screen call and an emulator widget in place of the text sheet; the key row; the mode switch in the header; the draft survives the switch.
2. Desktop keyboard input and selection.
3. Streaming through tmux control mode; backpressure and "watching" accounting.
4. The terminal-styled view.
5. Windows console polling with diffs; mirrored-session read-only mode.
6. Other assistants appear through the styled view first, through a terminal if they have one.

## Tests

- Emulator: golden screens from recorded sessions (the assistant's prompt, a menu, a spinner, the alternate screen) render to the expected cells.
- Frames: a fake agent streams bytes in order with a gap and a resize; the app shows the right screen after each.
- Input: every key in the key row and the desktop map produces the right bytes.
- Safety: a mirrored session refuses input; a large paste asks; closing the view stops the stream.

## Open

- Does the terminal view replace "Screen & keys" entirely? (Proposed: yes.)
- Is the terminal-styled view worth it for 1.0, or is the live view enough?
- A gesture layer on the phone (swipe for arrows, long-press for Ctrl) after the key row has been tried.
