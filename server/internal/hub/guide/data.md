# Where Tether keeps its data

One SQLite file on the hub (flag `-db`, default `tether.db` in the hub's working folder; WAL mode: copy it with `sqlite3 <db> ".backup <copy>"`, never open the live file for writing). Many columns are **protobuf blobs** (the contract is `proto/tether/v1/*.proto`); decode them with the generated types (Go: `server/gen/tether/v1`), not as text. Tables with plain text columns are marked.

| Table | What | Notes |
|---|---|---|
| `sessions` | one row per session: `id`, `node`, `info` (blob: SessionInfo: title, cwd, state, branch, model, todos, last prompt, scratch, archived, parent...) | `next_seq`, `next_ord`, `transcript_offset` track the log |
| `items` | the timeline: `session`, `item_id`, `ord`, `seq`, `payload` (blob: TimelineItem: user message, assistant message, tool call with status and result, to-do list, run card, task report...) | the full event log, per session |
| `chats` | `id`, `info` (blob: Chat: title, target, links, archived), `updated_ms` | |
| `chat_sessions` | `chat`, `session`, `role`, `linked_ms` | which sessions belong to a chat and how they joined |
| `chat_messages` | `chat`, `session`, `item_id`, `role` (user or assistant), `text`, `ts_ms` | **plain text**: the conversation without tool calls. The best table for analysing what was asked and answered |
| `chat_notes` | `chat`, `kind`, `value`, `updated_ms` | one note per kind per chat (the title, later recaps); plain text |
| `usage` | `session`, `message_id`, `node`, `model`, `ts_ms`, `input`, `output`, `cache_write`, `cache_read` | **plain**: token counts per assistant message; cost is derived from model prices |
| `lineage_events` | `session`, `parent`, `kind` (fork, continue, move...), `fork_point`, `by_client`, `at_ms`, `detail` | **plain**: how sessions relate |
| `audit` | `at_ms`, `actor`, `kind`, `subject`, `detail`, `ok` | **plain**: who did what (commands, MCP calls, approvals, skill actions), append only. Approval decisions are kind `approval`, subject `allow` or `deny`, detail `tool=<name> session=<id>` |
| `notifications` | `at_ms`, `kind`, `title`, `body`, `chat`, `session` | plain |
| `artifacts` | files kept on the hub: name, mime, size, sha256, session, node, origin, created_ms | plain; the bytes are in the hub's data folder |
| `codebases`, `snapshots`, `codebase_env` | codebases the agents snapshot, and their sealed .env files | `info` blobs; env files are AES-GCM sealed, never read them |
| `project_files`, `project_nodes`, `chat_remote` | remote projects: the sealed vault files, which devices may receive them, and the sync state per chat | plain except `sealed` |
| `devices` | paired apps and agents: id, token hash, info (blob) | never expose token hashes |
| `nodes` | last status each agent reported (blob: NodeStatus: os, capabilities, versions) | |
| `kv` | small values by key: the skills library, `rules`, `insights` (saved analyses), workspace roots, update state | JSON for skills, rules and insights |
| `history_files`, `history_events`, `history_resets` | the history index of sessions (what was said, when) | plain; used for search and for finding repeated routines |

## Reading it well

- **Conversation text**: `chat_messages` (plain). **What was done**: the tool calls inside `items.payload`.
- A chat can have several sessions (moves, forks, tasks): join through `chat_sessions`. A long chat's real context is its *active session's* transcript, not all rows.
- Time is milliseconds since the epoch (`*_ms`, `ts_ms`).
- A long user message can arrive as "My message is long, so it is in the attached file ..." with the text in an attachment, so its length in `chat_messages` is short.
- Forked sessions copy history: the same request can appear in several sessions; count by chat, not by session, and dedupe.
- Private details (paths, hostnames, tokens, credentials) can be in messages and tool calls: mask before quoting or sending to a model.
- Skills and rules are better read through the API (`GET /api/v1/skills`, `GET /api/v1/rules`) or the MCP tools (`list_skills`, `list_rules`).

## Where else things live

- Each machine: Claude Code's own transcripts in `~/.claude/projects/<folder>/<session>.jsonl` (the source the agent mirrors from), and a `.tether/` folder in codebases the agent snapshots (`codebase.json`, `out/` for deliverables, `pages/`, `attachments/`).
- The hub's data folder: artifact bytes, the sealed-secrets key, git repos for remote projects, the update feed.
- The second brain has its own SQLite file (`TETHER_BRAIN_DB`).
