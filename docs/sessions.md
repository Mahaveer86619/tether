# Sessions

## Where Claude Code keeps sessions

Each session is a JSONL transcript at:

```
~/.claude/projects/<cwd with separators replaced by "-">/<session-id>.jsonl
```

Lines include `user`, `assistant`, `system`, `attachment`, `ai-title`, `last-prompt` and housekeeping records, with fields such as `sessionId`, `cwd`, `gitBranch`, `timestamp`, `uuid`/`parentUuid` and `message` (Anthropic message shape).

This format is internal to Claude Code and not a public API. The agent only relies on a small set of fields, ignores everything else, and records the Claude Code version per session. Headless runs use the documented `stream-json` output instead, which is the stable path.

Keep Claude Code versions close across nodes; mismatched versions can disagree on the transcript format.

## Session sources

| Source | How the agent sees it | What the app can do |
|---|---|---|
| Started by Tether | Agent owns the `claude -p` process and reads its stream-json | Everything: send, interrupt, approve |
| Started in a terminal, still running | Transcript file is being written | **Mirror** read-only, live, by tailing the file |
| Started in a terminal, finished | Transcript file is idle | Read history, **resume** or **fork** |

## Indexing

The agent scans `~/.claude/projects` on start and watches it for changes. For each transcript it reports: session id, title (latest `ai-title`), cwd, git branch, first and last timestamp, message count, and whether it looks live. Only metadata is sent at index time; full history is streamed when the app opens the session.

## Ownership and "is it live?"

Two processes writing one transcript would corrupt it, so the agent decides who owns a session before resuming it:

- **Owned by Tether:** the agent has the process, in tmux or headless.
- **Owned by a terminal:** hooks report the session live and it isn't one of the agent's tmux windows or headless runs (`host: terminal`). The app can watch and approve, but only offers Fork for sending. Without hooks, a transcript written in the last 90 seconds by something else is treated the same way (`terminal_active`). See [hosting.md](hosting.md).
- **Idle:** nobody is writing. Resume is allowed.

When unsure, the app defaults to **Fork** (`--resume <id> --fork-session`), which copies history into a new session id and never touches the original.

## Resume and move

- **Resume on the same node:** `claude -p --resume <id>` with stream-json in and out. After the run, `claude --resume <id>` in the terminal shows the same conversation, so you can switch back to the TUI.
- **Continue on another node** (for example laptop → mini PC sandbox): the hub copies the transcript into the target node's `~/.claude/projects/<target cwd>/`, then that agent resumes with `--fork-session`. The working folder has to exist there too, usually via the NAS or a git checkout.

## Headless run flags

```
claude -p
  --output-format stream-json --input-format stream-json
  --include-partial-messages --verbose
  --replay-user-messages
  --permission-prompt-tool stdio
  --session-id <id>                      (new sessions; id chosen by the hub)
  | --resume <id>                        (continue)
  | --resume <id> --fork-session --session-id <new id>
  [--model <m>] [--permission-mode <mode>] [--name <name>]
```

Never default to skipping permissions. The approval round-trip through the app is the safety net.
