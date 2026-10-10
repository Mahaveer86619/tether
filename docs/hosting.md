# Hosting and tracking sessions

Tether never replaces Claude Code's own terminal UI. Sessions run as real Claude Code processes, and the agent hosts and watches them the way a terminal multiplexer like herdr would, so the app is just another client.

## Where sessions run

Each session reports a `host`:

| Host | What it is | What the app can do |
|---|---|---|
| `tmux` | Interactive Claude Code in a window of the agent's `tether` tmux session. Default on Linux and macOS when tmux is installed. | Everything: send messages, interrupt, approve. You can also attach from any terminal with the session's `attachCommand`, e.g. `tmux attach -t tether:claude-3ec9b0cd`, including over SSH from the phone. |
| `headless` | `claude -p` in stream-json mode, owned by the agent. Used on Windows, which has no tmux, or with `-host headless`. | Everything, plus live token streaming. There's no terminal to attach to; continue it later in a terminal with `claude --resume <id>`. |
| `terminal` | A session you started yourself in any terminal, seen through hooks. | Watch it live, see its state, approve its permission prompts. You can't type into it; fork it to continue from the app. |
| `none` | No live process. | Read the history; send a message to resume it (in tmux or headless). |

The agent's tmux windows survive agent restarts and upgrades: the systemd unit uses `KillMode=process`, and windows are matched back to sessions through the pane option `@tether_session`.

### Input into tmux sessions

Messages are delivered as one bracketed paste followed by Enter, so multi-line text arrives as a single message. Interrupt sends Escape.

### Folder trust

Interactive Claude Code asks "Do you trust this folder?" the first time it opens a directory (headless mode doesn't). The agent watches new tmux windows for that dialog and turns it into an approval of kind `FOLDER_TRUST`. When answered, it moves the selection and confirms while watching the screen. Keys sent while the TUI is still starting are dropped, so a blind keypress isn't reliable.

## State tracking with hooks

The agent installs HTTP hooks into Claude Code's user settings (`~/.claude/settings.json`). They POST each event to the agent on `127.0.0.1:7421`. Existing settings and hooks are kept, a backup is written once to `settings.json.tether-backup`, and `tether-agent uninstall-hooks` removes Tether's entries again. Run the agent with `-hooks=false` to skip this.

| Hook event | State |
|---|---|
| `UserPromptSubmit`, `PostToolUse` | `running` |
| `PermissionRequest`, `Notification` (`permission_prompt`) | `awaiting_approval` |
| `Stop`, `Notification` (`idle_prompt`) | `ready` |
| `SessionEnd` | closed (`host` becomes `none`) |

Because hooks fire for every Claude Code session for that user, sessions you start yourself show the same live states as Tether's own.

### Approvals from anywhere

A `PermissionRequest` hook is held open while the request goes to the app. Claude Code shows its normal prompt in the terminal at the same time, and **whichever answers first wins**:

- Answered in the app: the hook returns `allow`/`deny`, and the terminal shows "Allowed by PermissionRequest hook".
- Answered in the terminal: the next hook event from that session (or the hook request being cancelled) withdraws the approval from the app.

If the agent isn't running, the hook request fails, Claude Code treats that as a non-blocking error, and the terminal prompt works as usual. Headless sessions answer prompts through the stdio control protocol instead, and the hook steps aside for them.

## Without hooks

Sessions that started before the hooks were installed, or on a machine running with `-hooks=false`, fall back to a heuristic. A transcript written in the last 90 seconds by something other than the agent is shown as `terminal_active`, and the app can only mirror or fork it.
