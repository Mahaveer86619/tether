# Plan: orchestration, second brain and collaboration

Where Tether goes after M4 ([roadmap.md](roadmap.md)): what each idea means in practice, what has to be decided first, and in which order to build it. The order at the end marks what is built.

Every node uses only its own Claude login and usage. Work is never moved to another account to share usage.

Tailscale is a prerequisite: the hub, every node and every app are on one tailnet. The hub uses the tailnet to find machines and to trust its owner's own ones. A hub on a public address (TLS and pairing) is the fallback for machines that can't join the tailnet.

## Fork, branch and merge

Today **fork** runs `claude --resume <id> --fork-session`: a new session starts with a copy of the conversation, and the two never meet again. Nothing records that they're related.

Proposal (decided): keep fork, add **branch**, and record lineage for both. Branch replaces Claude Code's `/btw`: ask a side question, or try something on the side, without filling the main session's context. Unlike `/btw`, a branch is a full session with tools, and you can watch it and talk to it before it reports back.

| | Fork | Branch |
|---|---|---|
| Meaning | Go a different way for good | A side question or side task that comes back: the `/btw` replacement |
| Starts with | A copy of the history | A copy of the history |
| Ends | Never; it's a session of its own | **Merged** back, or abandoned |
| Code changes | In the same folder | In a git worktree, so the parent's files stay clean until the merge |

**Merge** (decided). Claude Code can't join two transcripts, so merging hands the whole branch to the main session, and the main session's Claude does the merging.

- **What's sent.** The hub sends the parent one message containing:
  - a summary of what the branch found, decided and changed, which Claude writes in the branch when merge is asked for;
  - the branch's full content since it split off: messages, tool calls with their results, and the diff of any files it changed.

  Long content goes into the artifact store as a file, and the message links to it.
- **Asking to merge is the decision to merge.** There's no extra confirmation. The main session takes everything and integrates it, code changes included, the way it would act on any instruction.
- **Tracked by the hub.** Branch and merge events are written to the hub's SQLite database in a `lineage_events` table:
  - which session, its parent and the split point;
  - the kind of event (fork, branch, merge or abandon);
  - who asked, from which device;
  - when;
  - the summary that was sent.

  The second brain ingests that table into its graph, so it can analyse how ideas branched and came back.

What this needs:

- `SessionInfo`: `parent`, `fork_point` (the transcript uuid it split at), `kind` (fork or branch), and `branch_state` (open, merged or abandoned). These are owned by the hub, like `archived`.
- The hub's `lineage_events` table, described above.
- Hub: `POST /sessions/{id}/branch` and `POST /sessions/{id}/merge`. Merge asks the branch for its summary, gathers its content since the split, and sends both to the parent.
- App: the session header shows "Forked from …" or "Branch of …". The parent gets a branch strip, with a **Merge** button.

It's worth doing: lineage is cheap and makes forks understandable on its own, and branch/merge builds on it.

## Second brain on the mini PC

The goal: your own data, stored locally, as one central brain. Sessions start with the memories that matter to them: global ones, the project's, and the task's.

```
brain/            (docker compose on the mini PC, own network, memory-limited)
  brain-api       remember, recall, link, ingest, suggest; storage behind interfaces
  postgres        documents, memories, graph (nodes, edges) and vectors (pgvector)
  worker          ingestion and pattern detection, on a queue
```

**Storage behind interfaces (decided).** The brain talks to storage only through a few interfaces, so the backend can change without touching the rest:

| Interface | Does | v0 (local) | Later (cloud) |
|---|---|---|---|
| `DocumentStore` | Raw sources: session summaries, files, artifacts' text | Postgres in the compose stack | Neon Postgres |
| `MemoryStore` | Memories with scope (global, project, task or session), source and time | Postgres | Neon Postgres |
| `GraphStore` | Links: memory ↔ project ↔ session ↔ file ↔ machine | Postgres tables | Neo4j Aura |
| `VectorIndex` | Nearest neighbours for recall | pgvector | pgvector on Neon |

Configuration picks the implementation; v0 ships only the local ones.

**Embeddings: local and light (decided).** They're only used for brain recall, so they don't need a large model:

- **v0:** a small custom embedder with no model download. It combines word and character n-gram feature hashing into a fixed-size vector, weighted by TF-IDF, plus BM25 keyword scores for hybrid ranking. It runs in milliseconds on the mini PC's CPU.
- **Upgrade path:** behind an `Embedder` interface, so a small local ONNX sentence model can replace it if recall needs it. Nothing leaves the machine either way.

**How sessions get memories:**

- **Markdown first.** When a session starts (and when it asks), the brain writes the relevant memories as markdown: a `.tether/memory.md` in the session's folder, with sections for global, project and task memories, each linking to its source. Claude reads it like any other file. Hub sessions get it in their scratch folder.
- **Recall on demand.** A brain MCP server offers `recall`, `remember` and `link` for a session that wants more, or wants to save something. The agent registers it on every node, the way it installs hooks today, and calls go through the hub.
- **Automatic ingestion from the hub.** The hub already has every session as parsed items, now with each message's source. When a session goes idle, the worker stores:
  - a summary of the session
  - its decisions
  - the files and artifacts it touched
  - the sequence of tool calls

  Each is filed under its project and task.

Workflow learning, which is the "ping script" case:

1. The worker spots repeated sequences across sessions, for example "run the ping check, read the log, restart the VPN".
2. It proposes an automation in the app.
3. If you approve, a session on the right node writes the script and a **skill**, and registers the trigger: a webhook from your existing Slack alert, or a schedule.
4. Later triggers ask for confirmation in the app, then run the skill on that node, live.

Still to decide while building:

- **Memory budget.** About 4.5 GB is free next to the staging stack; the compose stack gets hard memory limits.
- **What is ingested automatically** versus only when asked. Private sessions are never ingested.
- **Backups:** to the NAS once it's mounted.

## Hub scratchpad and virtual sessions

- **Hub session:** a session that runs on the mini PC in its own scratch folder (`scratch/<session>/`), with no device picked. It's the default for the quick-start box when the hub is reachable. Files you attach (images, audio, documents) and artifacts it produces are stored in that folder. Retention archives and then deletes old folders.
- **Orchestrator:** the hub session gets the hub MCP server from M4. Its tools include `list_nodes`, `run_on(node, prompt)`, `read_session` and `fetch_file`, so Claude on the mini PC can hand a task to the laptop, wait for it, and read the result. Each `run_on` creates an ordinary child session on that node, visible in the app, with its approvals routed as usual.
- **Virtual session:** one conversation in the app that spans the hub session and its child sessions on other nodes. It shows a merged timeline, with each child's turns tagged by device.

- **Global sessions:** a session can be made global.
  - The hub then keeps its complete transcript (it already receives every line when mirroring).
  - If its machine closes it or goes offline, it can be continued on the mini PC. The hub restores the transcript into a scratch folder there and resumes it.
  - Files only on the original machine aren't there, but the conversation and its context are.
  - Built with hub sessions, on top of the artifact store.

This is also the "remote working" setup: an always-on box, connected to the second brain, where servers can be tested and projects worked on while the laptop sleeps.

## Images and artifacts

A **central artifact store** on the hub is the core of the central scratchpad (decided). Everything a session reads, makes or is given lands there: images, files, audio, generated reports. Hub sessions use it as their working storage, the app browses it, and the brain indexes it. The store is built first, and hub sessions build on it.

When a session reads or makes an image (a screenshot it took, a chart, a photo from the phone), the app should show it inline, even after the local file is deleted.

- **Upload.** When the agent sees a tool call read or write an image file (`Read` of a `.png`, a screenshot saved by a command), it uploads the file to the hub. The hub stores it by content hash under `artifacts/<sha[:2]>/<sha>` (one copy however many sessions share it), and the tool card links to it.
- **Serve.** `GET /api/v1/artifacts/{id}` needs a token, or a signed link that expires after a while, so an image can open in a browser or another app. The app shows thumbnails in tool cards and opens the full image on tap.
- **Keep.** The hub keeps artifacts after the source file is gone, and the second brain indexes them with the session summary. Retention follows the session: archived with it, deleted only when the session is.
- **Attach.** Files the app sends to a session (from the composer) go into the same store, so both directions use one mechanism.

### Large files

Files of several GB have to work, over a phone's connection too. Nothing on the way holds a whole file in memory, and nothing caps its size except the hub's disk.

- **Store.** `POST /api/v1/artifacts` streams the body to a temp file while hashing it, then renames it into the store. There's no size limit. `X-Sha256`, if sent, must match, or the hub answers 422 and keeps nothing. A full disk is a 507.
- **Resumable upload.** `POST /api/v1/uploads` takes the same headers plus `X-Size`, and answers with an upload id. `PATCH /api/v1/uploads/{id}` with `Upload-Offset` appends a chunk. The offset must be where the file ends now: otherwise the hub answers 409 with the right one in `Upload-Offset`. A chunk cut off partway keeps what arrived, and `GET /api/v1/uploads/{id}` says where to go on. The chunk that completes the file has the hub hash the whole file, check `X-Sha256`, and file it. The answer carries the artifact, and `GET` keeps returning it, so a client that lost the answer can still find out. Uploads live in `<data dir>/uploads/` (the partial file plus its details), survive a restart, and are dropped after a day without a chunk. The app sends 4 MB chunks.
- **Download.** `GET /api/v1/artifacts/{id}/content` goes through `http.ServeContent` with the sha256 as a strong `ETag`, so `Range` and `If-Range` resume a download, and `?download=1` asks for `Content-Disposition: attachment`. The hub's `http.Server` has no read or write timeout, because either would cap a whole transfer. A signed link is checked when a request starts, so a long download doesn't fail when its link expires. The app downloads with its token instead.
- **Attach to a session.** An upload with `X-Session`, origin `attachment`, an optional `X-Note` and `X-Deliver: 1` makes the hub tell the session's node (`AgentCommand.fetch`) to put the file in `<cwd>/.tether/attachments/<name>`. The agent downloads into `<name>.part`, resumes with `Range` after a dropped connection, gives up only after 2 minutes with no bytes, and checks the sha256 before moving the file into place. A file already there with the same hash isn't fetched again. Files sent with a message skip `X-Deliver` and go with the message as before. The note is stored in the artifacts table's `note` column, added by the store's first migration (`PRAGMA user_version`). The hub MCP's `read_artifact` reads text 256 KB at a time from an `offset`, and for other files it says where an attachment sits in its session's folder.
- **Auto-capture.** Files a tool call reads or writes are kept up to 1 GB. Bigger ones are skipped and logged.
- **App.** Downloads use `background_downloader`. On Android that means a foreground service whose notification shows progress and has pause and cancel. Downloads resume across dropped connections and app restarts, check free space first (keeping 200 MB spare), are checked against the sha256 when done, and are then moved to Downloads/Tether (through MediaStore on Android). Uploads are read from disk in chunks; on Android the picker's copy in the app cache is cleared afterwards. A hub with a pinned self-signed certificate can't use background downloads, since only the app's own client knows the pin.

### Session backups

While an app is in use somewhere, the hub keeps a copy of every session, not just global ones, so a machine that goes away doesn't take its history with it.
- **When:** apps send `ClientPresence{active}` from their lifecycle. A desktop window that's only unfocused still counts as in use; minimized or backgrounded doesn't. Apps from before presence count as active while connected. While any app is active, the hub sends each online node `AgentCommand.backup` every 10 minutes, and at once when an app comes back after a longer gap.
- **What:** the request says how many bytes of each session's transcript the hub already has. The agent uploads the sessions whose transcript size differs, newest first, one run at a time. Each one gets its details (`meta.json`), its subagents' transcripts (`<session>/subagents/*.jsonl`) and the transcript, as artifacts with origin `backup` and paths `meta.json`, `subagents/<file>` and `transcript`. Files over 1 GB are skipped.
- **Dedupe:** the hub keeps one row per session and path. The same content again adds nothing; new content replaces the row, and the old blob goes if nothing else uses it. Backups aren't announced to apps and are left out of `GET /api/v1/artifacts` unless `origin=backup` is asked for. The transcript's backup sets `SessionInfo.backed_up_ms` and `backed_up_bytes`. Apps show "backed up 5m ago", and that is what the next request compares against, so an interrupted run catches up next time.
- **Restore:** "Continue on the hub" uses the newest copy, whether a global session's transcript or a backup.

## Usage tracking

Every node runs Claude Code under its own login, and every session uses only that login's usage. The hub never moves work to another account to save usage. It only reports what each node uses:

- **Tokens and cost per session:** from the `usage` fields on assistant messages in transcripts and stream-json. The hub totals them per session, node and time window.
- **Plan headroom** ("% left" in the current window): Claude Code shows this in `/usage`, but it isn't a stable API. If a hook or statusline input exposes it, the agent reports it. Otherwise the app shows totals against a budget you set per node.

## Connecting devices

### Who needs what

| Device | Runs | Signs in to Claude? | Connects to the hub as |
|---|---|---|---|
| Hub (mini PC or a VM) | `tether-hub` | — | — (it holds the admin token) |
| Laptop, mini PC, VM nodes | `tether-agent` and Claude Code | Yes, normally (`claude` then `/login`) | a **node** |
| Phone, desktop app, `tetherctl` | The app | No; it only talks to the hub | a **client** |

The phone never has Claude Code. It controls sessions that run on nodes, using each node's own login.

### Pairing with a QR code

Today every device needs the hub address and the one shared token typed in. Pairing replaces that with a short-lived code and a token per device:

1. On a device that's already connected (the desktop app's Settings → **Add a device**, or `tetherctl pair` on the hub), the hub creates a **pairing code**. The code is random, used once, and expires after 10 minutes.
2. The desktop app shows it as a QR code: `tether://pair?hub=<url>&code=<code>&fp=<certificate fingerprint>`. The code and address are also shown as text, for typing by hand.
3. The phone scans it from its setup screen and calls `POST /api/v1/pair {code, name, platform}`.
4. The hub checks the code and returns a **device token**. The phone stores it in secure storage. It never sees the admin token.
5. The desktop app shows "Pixel paired". Settings → **Devices** lists each paired device with when it was last seen, and **Revoke** cuts one off at once.

Agents pair the same way: `tether-agent pair <code>`, or the install scripts ask for a pairing code instead of the token. The node token is bound to the node's name, so one node can't pretend to be another.

What the hub stores:

- A `devices` table: id, kind (client or node), name, platform, the SHA-256 hash of its token, created, last seen and revoked. Only hashes are stored.
- The admin token stays in `tether.env`, for `tetherctl` on the hub and for recovery.
- Clients can do everything the app does today. Node tokens can only connect as their node. Once users exist (M6), each token belongs to a user.

### Two ways to reach the hub

**Over Tailscale (your setup).** The hub listens on its tailnet address, and every device is on the tailnet. The phone already is: it's the `mobile` node in `tailscale status`. The QR code carries `ws://<tailnet ip>:7420/ws`. Tailscale encrypts the traffic and keeps the hub off the internet, so plain `ws://` is fine here. Pairing only replaces typing the address and token. Later, `tsnet` can tell the hub which Tailscale user each connection belongs to.

**On a VM with a public `host:port`.** For users without Tailscale:

- **TLS is required.** The hub refuses to listen on a public address without it.
  - With a domain: `tether-hub -domain tether.example.com` gets a Let's Encrypt certificate itself (`autocert`). Alternatively, the hub runs behind Caddy or nginx.
  - Without a domain, which is the default, the hub makes a self-signed certificate. The QR code carries its SHA-256 fingerprint, and the app pins it, so there's no "trust this certificate?" prompt and no way to swap in another certificate.
- **Brute-force protection:**
  - pairing codes are long enough to guess only by brute force, and attempts are rate-limited per address;
  - failed token checks back off;
  - the admin token can be turned off for remote connections.
- The QR code carries `wss://host:port/ws`. The app's setup screen accepts either kind of URL.

In both cases the hub address and device token are all the app needs. Scanning a QR code is just the quickest way to get them onto a phone.

### Building it

1. **Hub:**
   - add the `devices` table;
   - add `POST /api/v1/pairing-codes` (needs a connected client), `POST /api/v1/pair`, and `GET` and `DELETE /api/v1/devices`;
   - check device tokens alongside the admin token.
2. **App:**
   - Settings gets **Add a device**, which shows the QR code and the code as text, and a **Devices** list with revoke.
   - The setup screen gets **Scan QR code** (camera on Android), plus manual entry of address and code.
3. **Agent:** `tether-agent pair <code>`, and the install scripts use it.
4. **Hub on a VM:** the `-domain` flag (autocert), self-signed certificates with pinning, and rate limits.
5. **Docs:** `security.md` and `running.md`.

## Users, roles and visibility

- **Identity:** each paired device belongs to a user.
  - Built: with `-trust-tailnet`, the hub trusts the owner's own tailnet machines by matching their addresses against `tailscale status`.
  - Next: map other Tailscale users to Tether users the same way, so each person's machines attach to their own account automatically.
- **Ownership:** each node and session has an owner.
- **Roles per node, service or session:** viewer (watch), collaborator (send messages, answer approvals, fork and branch) and owner (end, delete, change access).
- **Visibility:** sessions are **private** (only the owner sees them) or **shared** (visible to the team). Shared sessions can be forked or branched by collaborators; private ones can't, and are never ingested into the shared brain.
- **Services:** a watcher script with an agent attached, for example GitHub issue detection and auto-fix. It's owned by one user, runs on their node, and can be shared with others as viewer or collaborator.

## Codebases on the hub

The hub keeps a copy of every codebase a forked session works in, so work can carry on there with the laptop off.

- **Codebase:** a folder registered with the hub: `{id, node, path, name, git remote, branch, head}` in a `codebases` table. Workspace roots are scanned by the agent; any folder with `.git` or a project manifest (`go.mod`, `package.json`, `pubspec.yaml`, `pyproject.toml`, …) is a codebase, and a folder with none but codebases inside it is a container that is looked into, one level deep.
- **In the folder:** `.tether/codebase.json` holds the codebase id and the hub, and `.tetherignore` (gitignore syntax) says what is never copied. A default one is written if missing: `.git/`, `node_modules/`, build outputs, virtualenvs, `.dart_tool/`, `.tether/attachments/` and every `.env*` file. `.tether/` is added to `.git/info/exclude`, not to the repo's `.gitignore`.
- **Snapshot:** the agent walks the folder, hashes every file that isn't ignored, and sends the manifest. The hub answers with the hashes it doesn't have yet, the agent uploads only those into the content-addressed blob store, and the hub records the snapshot (`{id, codebase, session, parent, created, files, bytes, git head}`). Unchanged files cost nothing, so every snapshot is a full, browsable version: git-like history without git. Files over 50 MB are listed as skipped.
- **When:** on every fork, when a session is marked global or continued on the hub, and on demand ("Snapshot now"). Forks are kept on the hub: they become global, so their transcript is uploaded whenever they go idle.
- **Secrets:** `.env*` files are never copied. The agent parses them and sends each value to the hub, which encrypts it with AES-GCM under a key that exists only on the hub machine (`<data dir>/secrets.key`, mode 600) and stores it in a `codebase_env` table. No API, app screen or MCP tool returns a value: they show the file, the key names and a short fingerprint so changes are visible. Values only leave the vault to be written as a real `.env` (mode 600) when the hub machine's agent restores the codebase.
- **Continuing on the hub:** the hub machine's agent restores the latest snapshot into `~/.tether/codebases/<id>/`, regenerates the `.env` files, places the transcript and resumes the session there. Later snapshots update that working copy in place.
- **API:** `GET /api/v1/codebases`, `POST /api/v1/codebases/{id}/snapshot`, `GET /api/v1/codebases/{id}/snapshots`, `GET /api/v1/codebases/{id}/env` (names only). Agents use `POST /api/v1/codebases/{id}/manifest`, `PUT /api/v1/blobs/{sha}` and `PUT /api/v1/codebases/{id}/env`.

## Generated pages

Claude can build a small site to explain something by demonstration, and you open it from any device.

- **Making one:** the session writes it under `<cwd>/.tether/pages/<name>/`, with `index.html` as the entry. The agent's file hook uploads each file as an artifact with origin `page` and path `<name>/<file>`; the hub MCP's instructions tell Claude about this.
- **Hosting:** `GET /p/<token>/<file>` serves the newest version of each file of a page, where the token signs the session, page name and expiry, so relative links to CSS, scripts and images work. Responses carry `Content-Security-Policy: sandbox allow-scripts allow-forms allow-popups`, so a page runs as an opaque origin and can't reach the hub's API.
- **App:** a Pages tab on the Files page and a Pages entry in the session menu, each with Open (in the browser) and Copy link.

## Long prompts and Claude's questions

- **Long prompts** are still sent to the session as a file, but the chat shows the full text: the hub swaps the short note back for the message it stands for (`UserText.attachment_id` set), and the app shows the first lines with "Show full message".
- **Questions:** when Claude uses `AskUserQuestion`, the chat shows a card with each question and its options (single or multiple choice, plus a free-text answer). Answering sends the choices back to the session, the same way approvals are answered.

## Order

1. **Pairing** (built): device tokens, QR pairing, a Devices list with revoke, and TLS with pinning for a hub on a VM. Still to come: a `-domain` flag with Let's Encrypt.
2. **Lineage** (built): sessions record `parent`, `fork_point` and `lineage`; forks are kept as events in `lineage_events`; the app shows "Forked from", a forks menu and the split point.
3. **Usage tracking** (built): agents report tokens per message from transcripts; the hub totals them per machine and session; the app has a Usage page with the Claude plan limits.
4. **Central artifact store** (built): files sessions read or write, pasted images and long messages are stored on the hub, served with signed links that expire, shown in tool cards and message bubbles, and browsable on the Files page.
5. **Hub MCP and hub sessions** (built): the hub's `/mcp` server (nodes, sessions, artifacts, `wait_for_session`), registered with Claude Code by each agent; hub sessions in scratch folders, the default for quick start; attachments from the app; retention (archive after 14 days, delete after 60); global sessions that can be continued on the hub.
6. **Codebases, pages, long prompts and questions** (built): codebase snapshots on fork with the `.env` vault and restores on the hub; generated pages; long prompts shown in full; `AskUserQuestion` answered from the app.
7. **Branch and merge** on top of lineage: the `/btw` replacement.
8. **Brain v0:** the compose stack with storage behind interfaces (local Postgres first), the local light embedder, `memory.md` for sessions, the brain MCP, and session summaries ingested from the hub.
9. **Users and roles:** devices owned by users, private and shared sessions.
10. **Workflow learning:** automation suggestions that become skills and triggers with your approval.

After the core features work:

- **CI/CD:** one pipeline that tests the server and app on every push, builds releases (hub and agent binaries, the APK, the Windows app) on version tags, and deploys to the user's own machines over the tailnet.

Decided (2026-10-11):

- **Brain storage:** behind interfaces. v0 is a local Docker Compose service; Neon Postgres and Neo4j Aura can be plugged in later.
- **Embeddings:** local and light, a custom hashing and TF-IDF embedder, used only for the brain.
- **Memories reach sessions as markdown files**, plus the brain MCP for more.
- **Branch replaces `/btw`.**
- **The central artifact store is the core of the scratchpad.**

- **Merging a branch** sends its summary and full content to the main session, whose Claude integrates it, code included. Asking to merge is the decision; there's no extra confirmation. Lineage events are kept in the hub's SQLite database for the brain to analyse.
