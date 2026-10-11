# Plan: orchestration, second brain and collaboration

Where Tether goes after M4 ([roadmap.md](roadmap.md)): what each idea means in practice, what has to be decided first, and in which order to build it. Nothing here is built yet.

## Fork, branch and merge

Today **fork** runs `claude --resume <id> --fork-session`: a new session starts with a copy of the conversation, and the two never meet again. Nothing records that they're related.

Proposal: keep fork, add **branch**, and record lineage for both.

| | Fork | Branch |
|---|---|---|
| Meaning | Go a different way for good | A side trip that comes back, like a long `/btw` |
| Starts with | A copy of the history | A copy of the history |
| Ends | Never; it's a session of its own | **Merged** back, or abandoned |
| Code changes | In the same folder | In a git worktree, so the parent's files stay clean |

**Merge** can't join two transcripts, because Claude Code has no such operation. Instead, Claude writes a short report of what the branch found or changed. That report is sent into the parent session as a message ("Branch *X* finished: …"). If the branch changed code, its worktree branch is merged with git first and the report says so.

What this needs:

- `SessionInfo`: `parent`, `fork_point` (the transcript uuid it split at), `kind` (fork or branch), and `branch_state` (open, merged or abandoned). These are owned by the hub, like `archived`.
- Hub: `POST /sessions/{id}/branch` and `POST /sessions/{id}/merge`. Merge asks the branch for its report, then sends that report to the parent.
- App: the session header shows "Forked from …" or "Branch of …". The parent gets a branch strip, with a **Merge** button.

It's worth doing: lineage is cheap and makes forks understandable on its own, and branch/merge builds on it.

## Second brain on the mini PC

A separate Docker Compose project on the mini PC, reached by every node through the hub.

```
brain/            (docker compose, own network, memory-limited)
  brain-api       Python, FastAPI + LangChain/LangGraph: remember, recall, link, ingest, suggest
  postgres        pgvector for embeddings, plain tables for the graph (nodes, edges)
  worker          ingestion and pattern detection, on a queue
  (embeddings)    a small local model via Ollama, or an embeddings API
```

How sessions use it:

- **A brain MCP server.** The agent registers it in every node's Claude Code config, the way it installs hooks today. Its tools are `remember`, `recall`, `link`, `record_workflow` and `suggest_automation`. Calls go through the hub, which checks the user's token.
- **Automatic ingestion from the hub.** The hub already has every session as parsed timeline items. When a session goes idle, the worker stores:
  - a summary of the session
  - the decisions made in it
  - the files it touched
  - the sequence of tool calls

Workflow learning, which is the "ping script" case:

1. The worker spots repeated sequences across sessions, for example "run the ping check, read the log, restart the VPN".
2. It proposes an automation in the app.
3. If you approve, a session on the right node writes the script and a **skill**, and registers the trigger: a webhook from your existing Slack alert, or a schedule.
4. Later triggers ask for confirmation in the app, then run the skill on that node, live.

Decisions to make before building:

- **Memory budget.** About 4.5 GB is free next to the staging stack. Neo4j alone wants 1 to 2 GB, so start with Postgres + pgvector for both vectors and the graph, and move later if graph queries need it.
- **Embeddings:** local (private, uses CPU and RAM) or an API (better quality, data leaves the box).
- **What is ingested automatically** versus only when asked. Private sessions are never ingested.
- **Backups:** to the NAS once it's mounted.

## Hub scratchpad and virtual sessions

- **Hub session:** a session that runs on the mini PC in its own scratch folder (`scratch/<session>/`), with no device picked. It's the default for the quick-start box when the hub is reachable. Files you attach (images, audio, documents) and artifacts it produces are stored in that folder. Retention archives and then deletes old folders.
- **Orchestrator:** the hub session gets the hub MCP server from M4. Its tools include `list_nodes`, `run_on(node, prompt)`, `read_session` and `fetch_file`, so Claude on the mini PC can hand a task to the laptop, wait for it, and read the result. Each `run_on` creates an ordinary child session on that node, visible in the app, with its approvals routed as usual.
- **Virtual session:** one conversation in the app that spans the hub session and its child sessions on other nodes. It shows a merged timeline, with each child's turns tagged by device.

This is also the "remote working" setup: an always-on box, connected to the second brain, where servers can be tested and projects worked on while the laptop sleeps.

## Usage tracking and pooling

What can be measured:

- **Tokens and cost per session:** from the `usage` fields on assistant messages in transcripts and stream-json. The hub can total them per session, node, account and time window today.
- **Plan headroom** ("% left" in the current window): Claude Code shows this in `/usage`, but it isn't a stable API. If a hook or statusline input exposes it, the agent reports it. Otherwise the hub estimates it from token totals against a budget you set per account and window.

Pooling means delegating, not sharing logins:

- Each account's usage stays on its owner's machines, under the owner's own Claude Code login.
- The hub picks where a task runs: on a node whose owner opted in, with the most headroom. It sends the task there the same way the app sends a message today, and the owner can require approval per task or per service.
- Check Anthropic's terms and your Team plan's admin settings before pooling across people. Seats are per person, so a teammate's account should only run work its owner has agreed to run. For shared, unattended services (an issue-fixing watcher, say), an API key billed to the team is the clean option.

## Users, roles and visibility

- **Identity:** everyone is already on the tailnet, so the hub can use Tailscale identity (`tsnet` `WhoIs` gives the login of each connection) instead of hand-made tokens.
- **Ownership:** each node and session has an owner.
- **Roles per node, service or session:** viewer (watch), collaborator (send messages, answer approvals, fork and branch) and owner (end, delete, change access).
- **Visibility:** sessions are **private** (only the owner sees them) or **shared** (visible to the team). Shared sessions can be forked or branched by collaborators; private ones can't, and are never ingested into the shared brain.
- **Services:** a watcher script with an agent attached, for example GitHub issue detection and auto-fix. It's owned by one user, runs on their node, and can be shared with others as viewer or collaborator.

## Order

1. **Lineage:** record `parent` and `fork_point` for forks; show "Forked from" in the app.
2. **Usage tracking:** tokens and cost per session and account; a usage view in the app.
3. **Hub MCP and hub sessions:** M4's MCP server, scratch folders, attachments, retention.
4. **Branch and merge** on top of lineage.
5. **Brain v0:** the compose stack, the brain MCP (`remember`, `recall`), session summaries ingested from the hub.
6. **Users and roles:** Tailscale identity, ownership, private and shared sessions.
7. **Pooling and workflow learning:** headroom-aware delegation; automation suggestions that become skills and triggers with your approval.

Open questions:

- **Brain store:** Postgres-only first, or Neo4j from the start?
- **Embeddings:** local or API?
- **Pooling:** opt-in per task, or standing permission per service?
- **Merge:** report only, or report plus git merge by default when the branch changed code?
