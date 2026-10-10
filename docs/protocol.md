# Protocol (contract v1)

The contract is defined in `proto/tether/v1/` and generated into Go and Dart. This doc describes it; the `.proto` files are the source of truth once they exist.

There are two hops:

- **Agent ↔ hub:** carries Claude Code output *raw*. Agents never interpret it.
- **Hub ↔ app:** carries rendered, typed events. The app never sees Claude Code's raw format.

Claude is never instructed how to format replies. Whatever Claude Code emits is accepted as-is and turned into contract types by the hub.

## Envelope

Every frame on either hop:

```json
{
  "v": 1,
  "id": "01J…",          // ULID, unique per frame
  "node": "laptop",
  "session": "6b01a2b8-…", // Claude Code session id, when relevant
  "seq": 812,              // per-session, assigned by the hub; absent on commands
  "ts": "2026-10-11T07:00:03Z",
  "type": "block.upsert",
  "payload": { }
}
```

Clients send `subscribe {session, after_seq}` on connect and the hub replays everything after `after_seq` before going live. Nothing is lost when a phone drops off mobile data.

Unknown `type` values must be ignored by clients. New fields are additive within v1; anything breaking bumps `v`.

## App → hub commands

| Type | Payload |
|---|---|
| `session.create` | `node`, `cwd`, `prompt`, optional `model`, `permission_mode`, `name`, `sandbox` |
| `session.send` | `session`, `text`, optional attachments (NAS paths) |
| `session.resume` | `session`, `fork` (bool), optional `node` to move it |
| `session.interrupt` | `session` |
| `approval.respond` | `approval_id`, `decision` (`allow` / `deny`), optional `remember` rule, optional `message` |
| `subscribe` / `unsubscribe` | `session` or `"*"` for dashboard-level events, `after_seq` |
| `files.list` / `files.get` / `files.put` | NAS path |
| `schedule.upsert` / `schedule.delete` | cron expression, node, cwd, prompt |

## Hub → app events

| Type | Meaning |
|---|---|
| `node.status` | Online/offline, health, Claude Code version |
| `session.indexed` | A session was found or updated (title, cwd, branch, last activity, owner) |
| `session.started` | Headless run began (model, tools, permission mode) |
| `session.state` | `idle`, `running`, `awaiting_approval`, `mirroring` (owned by a terminal), `ended`, `error` |
| `block.upsert` | Create or replace a render block by `block_id` (see below) |
| `tool.started` / `tool.output` / `tool.finished` | Tool card lifecycle |
| `todo.updated` | Current to-do list from `TodoWrite` |
| `approval.requested` / `approval.resolved` | Permission prompt lifecycle |
| `session.result` | Final status, turns, duration, cost |
| `error` | Problem with a command, with a code |

## Render blocks

Assistant text arrives as Markdown. The hub parses it with goldmark (GFM) into blocks:

| Block | Fields |
|---|---|
| `heading` | `level`, `spans` |
| `paragraph` | `spans` |
| `list` | `ordered`, `start`, `items[]` (each item: `checked?`, `blocks[]`) |
| `code` | `lang`, `text` |
| `table` | `align[]`, `header[]` (spans), `rows[][]` (spans) |
| `quote` | `blocks[]` |
| `divider` | none |
| `image` | `url`, `alt` |
| `thinking` | `text`, collapsed by default |

`spans` are inline runs: `{text, bold?, italic?, code?, strike?, link?}`.

### Streaming

Partial text arrives in pieces. The hub keeps the in-progress Markdown for the current message, re-parses only its last top-level block on each delta, and sends `block.upsert` with the same `block_id`. The app replaces that block in place. A half-written table or code fence is shown as a table or code block that is still growing, never as raw `|` or backticks.

## Tool cards

Built from each `tool_use` input and its matching `tool_result`:

| Tool | Card |
|---|---|
| `Bash` | Command, description, live output (truncated, full on demand), exit status |
| `Edit`, `MultiEdit` | File path and a unified diff computed from `old_string` / `new_string` |
| `Write` | File path, size, collapsible preview |
| `Read` | File path and line range |
| `Grep`, `Glob` | Pattern, match count, list of matches |
| `TodoWrite` | Checklist; also emitted as `todo.updated` for the dashboard |
| `Task` / `Agent` | Sub-agent card with its own nested blocks and cards |
| `WebFetch`, `WebSearch` | URL or query and a short result |
| MCP tools and anything unknown | Name plus pretty-printed input and output JSON |

Large tool output is truncated in the event (first and last N lines) with a `full_ref` the app can fetch.

## Agent ↔ hub

| Type | Direction | Payload |
|---|---|---|
| `agent.hello` | agent → hub | node name, OS, Claude Code version, capabilities (`sandbox`, `windows`) |
| `raw.event` | agent → hub | `source` (`stream-json` / `transcript`), the original JSON line |
| `session.index` | agent → hub | session metadata found on disk |
| `approval.request` | agent → hub | tool name, input, `approval_id` |
| `agent.run` | hub → agent | start, send, resume or interrupt a session |
| `approval.result` | hub → agent | decision |
| `health` | agent → hub | periodic metrics |

The hub stores every `raw.event` before rendering it, so improved parsers can re-render old sessions.
