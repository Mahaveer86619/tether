# Protocol (contract v1)

The source of truth is [`proto/tether/v1`](../proto/tether/v1): `tether.proto` (frames, commands, events) and `render.proto` (timeline items, Markdown blocks, tool cards). Go code is generated with `buf generate`; the Flutter app will generate Dart from the same files.

There are two hops:

- **Agent ↔ hub:** carries Claude Code output *raw*. Agents never interpret it.
- **Hub ↔ app:** carries rendered, typed timeline items. The app never sees Claude Code's raw format.

Claude is never instructed how to format replies. Whatever Claude Code emits is accepted as-is and turned into contract types by the hub (`server/internal/render`).

## Framing

Every WebSocket text message is one `Frame`, encoded with protojson. Exactly one body field is set:

```json
{ "v": 1, "id": "c9…", "seq": "812",
  "timeline": { "session": "6b01a2b8-…", "items": [ … ] } }
```

| Field | Meaning |
|---|---|
| `v` | Contract version. Breaking changes bump it; new fields are additive. |
| `id` | Set by the sender of a command. |
| `replyTo` | On `ack` / `error` (and the subscribe end-of-replay marker): the command's `id`. |
| `seq` | On `timeline` frames: the session's highest sequence number in the frame. |

Clients must ignore body types and fields they don't know.

## Connecting

The first frame on a connection is a hello carrying the shared token (`TETHER_TOKEN`):

- Apps send `clientHello {token, clientName, platform}` and get back `welcome {nodes, sessions, pendingApprovals}`: everything needed to draw the dashboard.
- Agents send `agentHello {token, status}`.

Afterwards the hub pushes `nodeStatus`, `sessionInfo`, `approvalRequested` and `approvalResolved` to every client as they change.

## App → hub commands

| Body | Does | Reply |
|---|---|---|
| `subscribe {session, afterSeq}` | Replays timeline items changed after `afterSeq`, then streams live changes. The hub also asks the owning agent to mirror the transcript, so history and terminal sessions load. | Timeline frames, then an empty `timeline` frame with `replyTo` set: end of replay. |
| `unsubscribe {session}` | Stops the stream. | `ack` |
| `createSession {node, cwd, prompt, model, permissionMode, name}` | Starts a new headless session on a node. | `ack {session}` with the new id |
| `sendMessage {session, text, fork}` | Sends a follow-up: pasted into the tmux window, written to the headless process, or, if no process is running, the agent resumes the session. With `fork`, continues in a new session id and leaves the original untouched. Refused with `terminal_active` while a session you started yourself is open (`host: terminal`). | `ack {session}` |
| `interruptSession {session}` | Stops the current turn; the session stays open. Works for tmux, headless and (on Windows) your own terminal sessions. | `ack` |
| `stopSession {session}` | Ends a session the agent hosts (tmux or headless). Refused with `terminal_active` for your own terminal sessions. | `ack` |
| `approvalDecision {approvalId, decision, message}` | Answers a permission prompt (`kind: TOOL`) or a folder-trust dialog (`kind: FOLDER_TRUST`). | `ack` |

### REST

The same commands are available over HTTP, with `Authorization: Bearer <TETHER_TOKEN>`. Bodies and responses are protojson.

| Method and path | Body | Response |
|---|---|---|
| `GET /api/v1/state` | | `Welcome` |
| `GET /api/v1/sessions/{id}/timeline?after=<seq>` | | `TimelinePage`: items changed after `seq`, ordered by `ord`, plus the session's latest `seq` |
| `POST /api/v1/sessions` | `CreateSession` | `Ack {session}` |
| `POST /api/v1/sessions/{id}/messages` | `{text, fork}` | `Ack {session}` |
| `POST /api/v1/sessions/{id}/interrupt` | | `Ack` |
| `POST /api/v1/sessions/{id}/stop` | | `Ack` |
| `POST /api/v1/sessions/{id}/archive` | `{archived}` | `Ack`. Marks a session done, or not, for every client. The flag (`SessionInfo.archived`) belongs to the hub: agent updates keep it, and it clears when the session starts working again. |
| `POST /api/v1/sessions/{id}/rebuild` | | `Ack`. Drops the session's timeline and re-renders it from the transcript the next time it is mirrored, e.g. after the renderer learns a new line type. `seq` keeps growing, so clients merge the rebuilt items by id. Refused (`busy`, 409) for a live headless run. |
| `POST /api/v1/approvals/{id}` | `{decision, message}` | `Ack` |

Errors are an `Error {code, message}` body with a matching status: `unauthorized` 401, `invalid` 400, `not_found` 404, `terminal_active` 409, `busy` 409, `node_offline` 503.

Errors come back as `error {code, message}` with `replyTo`. Codes: `not_found`, `node_offline`, `invalid`, `terminal_active`, `unauthorized`, `internal`.

## Sessions

`sessionInfo` carries the dashboard view of a session (`sessionRemoved {session}` means it no longer exists): title, node, cwd, branch, model, to-dos, last cost, `state` (`idle`, `running`, `awaiting_approval`, `ready`, `terminal_active`, `error`), `host` (`none`, `headless`, `tmux`, `terminal`) and, for tmux sessions, `attachCommand`. `terminalInput` is set on Windows terminal sessions the agent can type into. See [hosting.md](hosting.md).

Interactive (tmux and terminal) sessions have no `result` item at the end of a turn, because the transcript doesn't record one. Clients see the turn end when `state` changes from `running` to `ready`.

## Timeline items

A session is an ordered list of `TimelineItem`s. Clients keep a map keyed by `itemId`, **replace** an item whenever it arrives again, and sort by `ord` (stable, assigned on first sight). `seq` only says which updates a client has seen.

| Kind | Content |
|---|---|
| `user` | A prompt you or a client sent. |
| `markdown` | Assistant text parsed into blocks; `streaming: true` while still arriving. |
| `thinking` | Thinking text, when Claude Code exposes it. |
| `tool` | A tool card (below), updated as it runs and finishes. |
| `notice` | Slash commands, interruptions, compaction, errors. |
| `result` | End of a turn: status, turns, duration, cost. |

`parentToolUseId` is set on items produced inside a sub-agent, so clients can nest them under its card.

### Markdown blocks

`heading`, `paragraph`, `list` (ordered, start, items with optional `checked`), `code {lang, text}`, `table {align, header, rows}`, `quote`, `divider`, `image`. Inline text is a list of `Span {text, bold, italic, code, strike, link}`.

While text streams, the hub re-parses the whole text block on each update and coalesces updates to at most one every 100 ms per session. An unterminated code fence already renders as code. A table appears once its header and separator rows have arrived.

### Tool cards

| Tool | Card detail |
|---|---|
| `Bash`, `PowerShell` | `shell {shell, command, description}` |
| `Edit`, `MultiEdit` | `edit {path, unifiedDiff, added, removed}` |
| `Write` | `write {path, preview, lines}` |
| `Read` | `read {path, offset, limit}` |
| `Grep`, `Glob` | `search {pattern, path, glob}` |
| `TodoWrite` | `todos {todos}`; also copied to the session's `todos` for the dashboard |
| `Task`, `Agent` | `agent {description, subagentType, prompt}` |
| `WebFetch`, `WebSearch` | `web {url, query}` |
| anything else | `generic {inputJson}` |

`status` goes `PENDING` (input still streaming) → `RUNNING` → `SUCCEEDED` / `FAILED`. `output` holds the tool result; long output keeps the first 200 and last 100 lines, with `omittedLines` set.

## Item identity

The live stream and the transcript file describe the same session, so they must produce the same ids:

- assistant blocks: `<message id>:<block index>`
- tools: the `tool_use` id
- user text, notices, results: a prefix plus the line's `uuid`

This makes ingestion idempotent: the hub can feed a session from either source, or both, in any order. A transcript replay never resets a finished tool card.

## Agent ↔ hub

| Body | Direction | Payload |
|---|---|---|
| `agentHello` | agent → hub | token, node status |
| `sessionIndex` | agent → hub | sessions found on disk or run by the agent, with their state |
| `rawEvents` | agent → hub | `source` (`STREAM` or `TRANSCRIPT`), original JSON lines, and for transcripts the byte offset reached |
| `approvalRequested` | agent → hub | a permission prompt (from the hook or a headless run) or a folder-trust dialog |
| `approvalResolved` | agent → hub | a prompt was answered on the node itself, usually in the terminal |
| `nodeStatus` | agent → hub | updated status, e.g. running session count |
| `agentCommand` | hub → agent | `start`, `send`, `interrupt`, `mirror {session, fromOffset}`, `stopMirror` |
| `approvalDecision` | hub → agent | the app's answer |

The hub stores each session's transcript offset, so re-subscribing resumes mirroring where it stopped.
