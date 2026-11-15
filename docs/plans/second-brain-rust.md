# The second brain, in Rust, beside codebase-memory

Steps 1 and 2 (the memory store and recall, then the MCP server and its wiring) are built; the rest is plan. It replaces the Postgres stack in [plan.md](plan.md#second-brain-on-the-mini-pc) with one small Rust program, and says how it works with `codebase-memory-mcp`, which the owner already uses. The decisions in plan.md still hold: storage behind interfaces, local light embeddings, memories scoped global, project and task, markdown first, a brain MCP.

## What codebase-memory-mcp does (read from its docs and the installed 0.10.8)

- **One static C binary** (293 MB on the mini PC, because 150-odd tree-sitter grammars are inside it). `codebase-memory-mcp` runs an MCP server on stdio; `codebase-memory-mcp cli <tool> [args]` runs one tool and exits. Its data is under `~/.cache/codebase-memory-mcp/` (a config db and one SQLite graph per project, WAL mode). On the mini PC nothing is indexed yet (68 KB).
- **Indexing is a pipeline**: find files and folders; extract definitions with tree-sitter in parallel (functions, methods, classes, interfaces, types, routes); resolve calls, imports, inheritance, type use and HTTP routes with a cascade of strategies that give each edge a confidence (0.95 down to 0.3); enrich (tests, config links, files that change together in git); write it all to SQLite in one go; then compute communities (Louvain) and per-file hashes. It builds in memory first and caps itself at a fraction of RAM (it logs a 1.9 GB budget on the mini PC's 7.7 GB).
- **Staying current**: a watcher polls registered git projects, compares each changed file's hash and re-parses only that file.
- **Asking it**: about a dozen tools. `index_repository`, `index_status`, `search_graph` (names, labels, degree, optional semantic search), `search_code`, `trace_path` (callers and callees, a recursive query), `get_architecture`, `detect_changes` (uncommitted changes to affected symbols and tests), `query_graph` (a Cypher-like language), `get_code_snippet`, `manage_adr` (one architecture decision record per project, 8 KB), `ingest_traces`, `compare_graphs`.
- **What it does not have**: notes or memory of its own beyond the single ADR, no link to conversations, and it stores no source lines.
- **Cost**: indexing is the load (a few seconds for a mid-size project, minutes for the Linux kernel, memory up to its cap while it runs); idle it is a sleeping process.

## What to build

One Rust program, **`tether-brain`**: a single static binary, SQLite (WAL) for everything, no Docker and no Postgres, idle at a few MB and a low-priority thread pool while it works. It is the second brain of plan.md with a smaller body.

| Part | Does |
|---|---|
| **Memory store** | Notes and facts with a scope (global, project, task, session), a source (a chat, a file, a commit, you), a time, and tags. Full-text search with SQLite FTS5. |
| **Recall** | Hybrid ranking: BM25 plus the hashed-n-gram vectors from plan.md (a vector per memory, a few hundred bytes, scanned in memory; no ANN index needed below about a million memories). Behind the `Embedder` and `VectorIndex` interfaces. |
| **Ingest from Tether** | Reads the hub's history, chats and notes (the hub already keeps them, with full-text search), turns finished turns into summaries, decisions and touched files, and files them under project and task. Private sessions are skipped. |
| **Code links** | A note can point at a code symbol (`project`, qualified name, file, and the commit it was written at). The brain asks codebase-memory for the symbol's current neighbours (callers, callees, file) and returns them with the note, and marks a note **stale** when its symbol has moved or gone. |
| **MCP server** | `remember`, `recall`, `link`, `forget`, `notes_for(symbol or file)`, `project_brief`. Registered on every node by the agent, as the hub's MCP is today; calls go through the hub. |
| **Markdown out** | `.tether/memory.md` for a new session: global, project and task memories, each with its source. |

### How it works with codebase-memory-mcp

1. **Drive it, don't copy it (first).** The brain launches `codebase-memory-mcp cli …` (or keeps one stdio MCP client open) for graph facts, and keeps its own notes in its own database keyed by project and qualified name. The two stores stay independent: indexing never touches notes, and notes never slow indexing. Deleting a project's graph does not delete its notes; they go stale instead.
2. **A tool that answers both.** `project_brief(project)` returns the graph's architecture summary (from `get_architecture`) next to the project's memories and its recent decisions. This is what a new session reads first.
3. **Its ADR is the bridge.** `manage_adr` holds one record per project; the brain reads it as a document, and writes decisions it finds in chats as proposals for the owner to accept into the ADR.
4. **Rust code-graph indexer (second, only if needed).** If driving the C binary proves too heavy on the mini PC, or you want it in the same program, `tether-brain` gets a native indexer: `tree-sitter` with the grammars for the languages you use (Go, Rust, Dart, TypeScript, Python, Kotlin, SQL), the same graph in SQLite, hash-based incremental updates, and calls resolved by import map and then by name. That is a project of its own (weeks, not days), and the C tool already covers it, so it is held back until the first three steps show it is worth it.

### Why Rust, and what "efficient" means here

- A single static binary, `rusqlite` with the bundled SQLite, `tokio` only for the MCP and HTTP edges, a rayon pool for ingestion, so it can be run under `nice` and a memory cap (`MemoryMax=300M` in its systemd unit).
- Idle cost is what matters on a 7.7 GB machine that also runs staging services and the hub. Ingestion runs when the hub is idle and yields; recall is a few milliseconds.
- The graph tool is the heavy part, and it is already built; a Rust rewrite of it is optional, not a prerequisite.

## Built so far: the memory store (`brain/`)

A Rust crate, `tether-brain` (library and command line). SQLite in WAL mode; memories with scope (global, project, task, session), kind, source, tags and links to symbols or files; keyword ranking (FTS5 with BM25) and likeness ranking (256-dimension hashed vectors, one signed byte each) merged by reciprocal rank fusion, with narrower scopes winning ties; `notes_for`, staleness marks, and `brief`, the markdown a session reads first. `tether-brain bench N` measures it.

Measured on the mini PC (4 cores, idle, 20,000 synthetic memories with a project and task context): about 29 ms per recall, 2,850 memories stored per second, an 18 MB database, 7.7 MB peak memory, a 3 MB binary. Real stores are smaller, so single-digit milliseconds is what to expect. The laptop gave noisy and slower figures (a loaded Windows machine), so the mini PC's are the ones that count. Possible speed-ups if ever needed: keep vectors in one contiguous table so a scan is a memory sweep, and cache the prepared statements.

## Built so far: the MCP server and its wiring

- **`tether-brain mcp`** speaks MCP on standard input and output; **`tether-brain serve --listen 127.0.0.1:7433`** speaks it over HTTP (one JSON-RPC message or batch per POST, answered in the response). One handler (`mcp.rs`) answers both. Tools: `remember`, `recall`, `project_brief`, `notes_for`, `mark_stale`, `forget`. `remember` takes the narrowest scope it is given (task, then project, then global) unless told, and links to symbols and files.
- **The hub forwards it.** `tether-hub -brain http://127.0.0.1:7433` serves it at `POST /brain/mcp` behind the hub's own token (`GET /brain/healthz` says whether it is there), so every device reaches it the way it reaches the hub's MCP server.
- **Agents register it.** When an agent registers the hub's MCP server with Claude Code it asks the hub whether a brain is there: if so it registers `tether-brain` (user scope, same token handling), and if not it removes it, so no device lists a server that cannot answer.
- **On the mini PC** it runs as a user service (`deploy/linux/tether-brain.service`: loopback only, `Nice=10`, `MemoryMax=300M`, read-only filesystem except its own folder). `deploy/linux/enable-brain.sh <binary>` installs the program and service and adds `-brain` to the hub's flags; `brain/build.sh` builds the Linux binary in Docker. It needs a hub that knows `-brain`, which is the release after 0.17.9. The service is already running there on its own (1.6 MB of memory) and answers over HTTP and stdio.

## Order of work

1. **Memory store and recall** (`remember`, `recall`, `forget`, scopes, FTS5 plus hashed vectors) as a library and a CLI, with tests and a size/speed benchmark on the mini PC.
2. **MCP server and Tether wiring**: registered by the agent on each node, routed through the hub, `.tether/memory.md` for new sessions.
3. **Ingest** from the hub's history and chats, with a review list in the app (what was learned; accept, edit, forget).
4. **Code links** through codebase-memory: `notes_for`, `project_brief`, stale detection; index the projects you work in.
5. **App**: a Brain page (search, a project's memories, stale notes, proposed decisions).
6. **Measure**, then decide on the native Rust indexer.

## Decisions to confirm

- SQLite and one Rust binary instead of Postgres in Docker (recommended: far lighter, and it is what plan.md's interfaces were for).
- Drive codebase-memory-mcp rather than rewrite it first (recommended).
- Where notes live: in the brain's own database (recommended), not inside codebase-memory's per-project database, which its updates and reindexing may rewrite.
