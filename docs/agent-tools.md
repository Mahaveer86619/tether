# The wrapper: engines, what Tether gives the assistant, skills, security

Status: plan, with what exists marked. This is the technical side of Tether being a layer above the assistant rather than a viewer for it.

## 1. Engines

Today there is one: Claude Code. Everything Claude-specific lives in the agent and the renderer:

| Concern | Claude Code today |
|---|---|
| Starting and resuming | `claude -p` in stream-json mode (headless), or the interactive interface in a terminal multiplexer, with `--resume` and `--fork-session` |
| Seeing activity | HTTP hooks in the assistant's settings; transcripts under its projects folder |
| Approvals | The permission hook (interactive) or the control protocol (headless) |
| Telling it about Tether | `--append-system-prompt` and a registered MCP server pointing at the hub |
| Usage | Its own usage output |

To make it a wrapper, these become an **engine contract** that the agent implements once per assistant: `Start`, `Resume`, `Fork`, `Send`, `Interrupt`, `Stop`, `Approvals`, `Events` (raw, rendered by the hub into the same timeline items), `Screen` (optional), `Usage`, `Register tools`, and a **capability set** (structured events, a terminal, resume, fork, approvals, skills, tool use). The app asks a session what it can do and hides what it can't (no terminal mode without a terminal; the styled view instead).

Other engines fit in two shapes: another **CLI** (Codex CLI, Gemini CLI, Aider) behind the same contract, and an **API engine** (a model reached by key or base URL, including a local server) where the agent runs the tool loop itself. The second is the large one and needs its own design doc: what a session is for a model with no tools of its own, where its tools come from (Tether's), how keys are stored (encrypted on the hub, scoped), and how cost is counted. It is not started.

## 2. What Tether gives the connected assistant

The point of the wrapper: the assistant on one machine can use all of the person's machines and remember what they keep asking. Delivered as tools on the hub's MCP server, each with a short, exact description, because every tool costs the assistant's context.

| Tool | Does | Status |
|---|---|---|
| `list_nodes`, `list_sessions`, `read_session` | See the machines and what is running or done | Built |
| `start_session`, `send_message`, `wait_for_session` | Hand work to another machine, follow it, get the result | Built |
| `set_chat_target` | Move a chat to the right machine and folder | Built |
| `save_artifact`, `read_artifact` | Share files through the hub | Built |
| `list_skills`, `read_skill`, `propose_skill`, `update_skill` | Use, propose and correct skills | Built |
| `present_file` | Put a file it made in the chat for the person to take ([deliverables.md](deliverables.md)) | New |
| `present_page` | Put an interactive guide card in the chat ([previews-and-guides.md](previews-and-guides.md)) | New |
| `notify_user` | Tell the person something now ([notifications.md](notifications.md)); rate-limited | New |
| `node_info` | What a machine can do (toolchains, versions, disk) | New |
| `remember`, `recall` | The second brain | Later |

Rule: add a tool only when it removes a round of guessing. Descriptions say *when* to use it and what it returns; results are short; large results are artifacts the assistant reads in pages.

## 3. Choosing skills well

**Problem.** The lead's prompt lists every approved skill with its description. That grows with the library, costs context on every message, and leaves the choice to the model reading a long list.

**Design.**
1. **A router on the hub.** When a chat starts or a message arrives, score the request against each skill's description and the requests it was learned from, using the same local hashed word vectors as routine detection (no model call, nothing leaves the hub). Take the top three over a threshold.
2. **Offer only those.** The prompt gets up to three lines ("Likely skill: `v2-sync-progress`: Use when asked how far the v2 sync is"), under a fixed token budget, and one line saying the rest can be found with `list_skills` (which takes a search term and pages). Zero matches adds nothing.
3. **Say which was used.** `read_skill` records the use against the turn. The app shows "Used skill: X" on the message.
4. **Learn from outcomes.** Each use records whether the turn ended well, whether the person corrected the assistant, and a thumbs down ("wrong skill") if given. Ranking weights a skill's recent success; a skill that fails twice in a row is flagged for review (already designed) and drops from the offer until reviewed.
5. **Hold the line on safety.** A skill that changes things still asks first; a worker session never sees the library at all (it was handed one task).

**Tests.** A corpus of requests with known right skills: the router's top-three contains the right one at a target rate and offers nothing for unrelated requests; the prompt stays under budget with 200 skills; a failing skill leaves the offer; usage is recorded once per turn.

## 4. Security

Tether is a remote control for shells on the person's machines, so it is built as one.

**Today.** Everything sits on a private network; every device has its own revocable token; the hub verifies each connection; a self-signed hub is pinned by fingerprint; signed, expiring links for files; generated pages run sealed; an `.env` vault is encrypted with a key held on the hub; approvals gate what the assistant may do; skills are checked for secrets and need the owner's approval; hooks and settings are backed up before they are changed.

**To do for 1.0.**
- **Least privilege for the assistant's own calls.** A session's MCP calls use a credential scoped to that session; a *task* session (one the lead started) cannot start further sessions or read the library (today only its prompt says so). The hub enforces what the prompt asks.
- **An audit log** on the hub: every MCP tool call, every skill change, every terminal opened, every wipe, with who and when; viewable and exportable. *Built for MCP tool calls and skill decisions* (`GET /api/v1/audit`, newest first, `kind`, `before`, `limit`): it records the tool and where and what it was aimed at (node, folder, session, chat, name), never the content. Terminals and wipes join it when they exist; the screen and export are for the design.
- **Untrusted content.** Files, web pages and tool outputs can carry instructions meant to steer the assistant. Tether does not read them, but it can keep an approval in the way: nothing a skill or a result says can approve itself, and an approval card always shows what will actually run, not what the assistant says it will run.
- **Rate limits** on notifications, session starts and file uploads per device.
- **Secrets.** Never in skills, prompts or logs; the doctor checks the hub's data folder is private to its user; tokens are shown once.
- **Revocation that bites.** Revoking a device drops its connection at once and invalidates its links.
- **Review.** A written threat model and one external look before 1.0.

## 5. Efficiency

- The hub's state the assistant sees (machines, skills) is small and built per message, not repeated history.
- Large things are artifacts read in pages, never pasted.
- History sync is incremental and resumable; the app reads history from the hub and caches it.
- Rendering is done once on the hub; every app gets the same items.
- Measure: the tokens Tether adds to a first message, kept in a test with a ceiling.

## 6. Connectivity from anywhere

The assumption stays: a private network (Tailscale) and one always-on hub. What the app does about it is in [app.md](app.md#tailscale-in-the-background). Not planned: a public relay, a hosted hub. If the hub is unreachable the app works from its cache (history, files already downloaded) and queues what the person types; it says so.

## Work items (engine side)

1. Hub posts a finished task's result into its chat.
2. `present_file`, the drop folder and the chat's artifacts endpoint ([deliverables.md](deliverables.md)).
3. The skill router and usage recording.
4. Scoped MCP credentials and the audit log.
5. Node capabilities and the doctor ([first-run.md](first-run.md)).
6. Notification rules and the `Notify` frame ([notifications.md](notifications.md)).
7. The terminal frames ([terminal-mode.md](terminal-mode.md)).
8. The engine contract written down and the Claude Code engine moved behind it, then a design doc for API engines.
