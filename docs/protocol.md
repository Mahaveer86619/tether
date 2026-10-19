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

- Apps send `clientHello {token, clientName, platform}` and get back `welcome {nodes, sessions, pendingApprovals}`: everything needed to draw the dashboard. The welcome also says who the app is: `deviceId` (its paired device, empty for the admin token or a trusted tailnet) and `clientIp` (the address it connected from). Every `nodeStatus` carries `ip`, the address its agent connects from, so the node whose `ip` equals `clientIp` runs on the app's own machine. `GET /api/v1/state` fills both fields for the caller too.
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
| `approvalDecision {approvalId, decision, message, answers}` | Answers a permission prompt (`kind: TOOL`), a folder-trust dialog (`kind: FOLDER_TRUST`) or Claude's questions (`kind: QUESTION`, from `AskUserQuestion`; `inputJson` holds the questions). For a question, `answers` maps each question's text to the chosen option labels, joined with ", ", or to the user's own words; the agent adds them to the tool's input as `answers`, which is how a host answers it. Allowing with no answers tells Claude the user didn't answer. | `ack` |

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
| `POST /api/v1/approvals/{id}` | `{decision, message, answers}` | `Ack` |
| `POST /api/v1/pairing-codes` | | `PairingCode {code, expiresMs, certFingerprint}`: one-time, 10 minutes |
| `POST /api/v1/pair` | `PairRequest {code, kind, name, platform}` | `PairResult {device, token}`. The only call without a token. `kind` is `client` (an app) or `node` (an agent, bound to `name`). |
| `GET /api/v1/devices` | | `DeviceList` |
| `GET /api/v1/sessions/{id}/lineage` | | `LineageEvents`: forks (and later branches, merges and abandons) the session is part of, as child or parent, oldest first. Kept in the hub's `lineage_events` table for the second brain. |
| `GET /api/v1/workspaces` | | `Workspaces {roots}`: the folders on each node that new projects are created in |
| `PUT` / `DELETE /api/v1/workspaces` | `WorkspaceRoot {node, path}` | `Workspaces`. Adds or removes a root. |
| `GET /api/v1/usage` | | `UsageSummary`: each node's plan limits (`PlanUsage`) and tokens for the last 5 hours, today and 7 days; the week's sessions, most tokens first |
| `PUT /api/v1/preferences` | `Preferences {themeMode, palette, accent}` | `Ack`. App settings shared by every client; sent to all of them as a `preferences` frame, and included in `Welcome`. |
| `GET /api/v1/tailnet` | | `Tailnet {devices, error}`. Every machine in the hub's `tailscale status`, with the Tether node and apps connected from it. |
| `DELETE /api/v1/devices/{id}` | | `Ack`. Revokes the device and closes its connections. |
| `GET /api/v1/pages?session=` | | `PageList`: pages sessions made under `.tether/pages/<name>/`, newest first, each with a 7-day signed `url` to its `index.html` |
| `GET /p/{session}/{name}/{exp}/{sig}/{file}` | | The page's newest version of that file. No token: the signature is the credential. Served with `Content-Security-Policy: sandbox …`, so the page runs as an opaque origin. |
| `GET /api/v1/codebases` | | `CodebaseList`: each codebase with its latest snapshot and its `.env` files as paths and key names; never values |
| `POST /api/v1/codebases/{id}/snapshot` | | `Ack`. Asks the codebase's node for a fresh snapshot. |
| `GET /api/v1/codebases/{id}/snapshots` | | `SnapshotList`, newest first |

Agents also use: `POST /api/v1/codebases/found` (`FoundCodebases`, what a scan of the workspace roots found), `POST /api/v1/codebases/{id}/manifest` (a `SnapshotManifest`; answers `MissingBlobs`), `PUT /api/v1/blobs/{sha}` (one file, checked against its hash), `POST /api/v1/codebases/{id}/snapshots` (records the snapshot), `POST /api/v1/codebases/{id}/error`, and `PUT /api/v1/codebases/{id}/env` (`EnvFiles`, sealed into the vault). To restore, the hub machine's agent reads `GET /api/v1/snapshots/{id}/manifest`, `GET /api/v1/blobs/{sha}` and `GET /api/v1/codebases/{id}/env/files`; the last one only answers requests from the hub's own machine.

Errors are an `Error {code, message}` body with a matching status: `unauthorized` 401, `invalid_code` 401, `invalid` 400, `not_found` 404, `terminal_active` 409, `busy` 409, `rate_limited` 429, `node_offline` 503.

Agents send `usageReport` frames with token usage per assistant message, read from the transcripts they index: input, output, cache writes and cache reads. They send what's new after each scan, and everything again on each new hub connection. The hub keeps one row per message in its `usage` table, holding the largest count seen per field.

`CreateSession.createCwd` makes the agent create the folder before starting: a new project in a workspace root. On tmux it also accepts Claude Code's folder-trust prompt for that folder, since the user just made it.

Agents also send `planUsage` frames: what `claude -p /usage --no-session-persistence --settings '{"disableAllHooks":true}'` prints for their Claude login.
- It runs every 5 minutes and on connect.
- It's local, so it uses no tokens. The flags keep it out of the session list and stop it firing hooks. (`--bare` would skip hooks too, but also the subscription login.)
- The hub keeps the latest report per node: the "Current …: N% used · resets …" lines as `limits`, plus the raw text, since the format isn't a stable interface.

Sessions carry their lineage, owned by the hub like `archived`: `parent` (the session they split off from), `forkPoint` (the parent's last timeline item at that moment) and `lineage` (`fork`; later `branch`).

User messages carry `source`, set by the hub: the name of the app or tool that sent it through the hub, or `terminal` when it was typed in the session's terminal. It's stored with the message, survives a rebuild, and is part of the history the second brain will read.

A QR code for pairing carries `tether://pair?hub=<ws url>&code=<code>&fp=<certificate sha256>`; `fp` is only there for a hub with a self-signed certificate.

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
