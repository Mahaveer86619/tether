# Core-first v1

Status: plan. This is the source of truth for the v1 direction approved on 2026-11-28. It turns the hub, agent and their MCP/REST surface into the MVP; the Flutter apps become optional views.

GitHub work is tracked in milestone [v1: core-first harness](https://github.com/Mahaveer86619/tether/milestone/1):

- [#43 Core-first MVP: headless core on every device, apps optional](https://github.com/Mahaveer86619/tether/issues/43)
- [#46 Start every chat from the hub](https://github.com/Mahaveer86619/tether/issues/46)
- [#45 Main agent with parallel free-tier sub-agents](https://github.com/Mahaveer86619/tether/issues/45)
- [#44 Core-owned token budgets, model ranking and automatic fallback](https://github.com/Mahaveer86619/tether/issues/44)
- [#41 Herdr as an external Tether client](https://github.com/Mahaveer86619/tether/issues/41)
- [#42 Split core and app release tracks](https://github.com/Mahaveer86619/tether/issues/42)

## The decision

Tether core is the product. It must run on any device - a home server, laptop, desktop, phone or small always-on machine - and connect over Tailscale to other devices and the hub. A person must be able to install nothing but `tether-hub`, `tether-agent` and `tetherctl`, pair a device, start a chat, delegate work and read token status from a shell or any MCP client.

The Flutter Android/Windows apps are still useful, but they are no longer required and they do not own chats. They are views and controls for hub-owned state.

Herdr is an external harness (`github.com/herdrdev`), not a Tether app and not a vendored dependency. Herdr desktop/Android apps can replace the Tether apps as the person's window into Tether core. Tether core supplies devices, chats, sessions, jobs, permissions and budgets; Herdr supplies panes, terminal UI and its own agent-status view.

Full v1 is gated on [#44](https://github.com/Mahaveer86619/tether/issues/44): provider ranking, token budgeting and automatic fallback must live in Tether core and be visible from every device and user who is allowed to see it. A client-only solution is not enough.

## Core boundary

What must work without a Tether app:

1. Install and pair the hub and agents, including headless agents on devices the person is not sitting at.
2. Create a chat from `tetherctl` or an MCP client, choose a device/project/cwd, set the initial prompt, and stream events back to the caller.
3. Start and supervise a main agent session and parallel sub-agent sessions.
4. Give an agent the tools to delegate, wait, collect results and cancel.
5. Record usage, rank providers, enforce budgets and fall back when a provider is exhausted.
6. Expose chats, sessions, jobs, token status and provider settings over REST and MCP.
7. Update core independently of the apps.

The hub is the source of truth for chat/session/job identity, target device, permissions, grants, slots and budgets. An app, `tetherctl` or Herdr reconnecting must reattach to that state; it must not fork a second lead session.

## Hub-started chats

Today a chat can be created from an app and a session can be started on an agent, but v1 requires the hub to own that journey end to end:

- `POST /api/v1/chats` and an MCP tool create a chat with `node`, `cwd`/`project`, `profile`, `initial_prompt` and `mode` (`main` or `subagent`).
- The hub creates the lead session, sends the start command to the selected agent, and records the native session id when the agent reports it.
- Session state transitions, render blocks, approvals and tool cards come from the agent to the hub, then fan out to every authorized client.
- `set_chat_target`, pause, resume, stop and rewind are hub operations, not app-local operations.
- Existing app-created chats keep working during migration, then the app calls the same hub API.

A reconnect must resolve the hub's chat and session ids first. The app/Herdr is a view over them.

## Main agent and parallel sub-agents

A v1 chat has one main session and zero or more sub-agent sessions. The default main brain is Claude Code because it is the reasoning and planning layer; a chat that names `opencode-main` makes OpenCode CLI the lead instead. Sub-agent work is delegated to CLIs the person already has installed, initially Antigravity CLI and OpenCode CLI, because their free tiers and larger context windows suit codebase reading and bounded tasks. Tether does not wrap, bundle or replace those CLIs.

Core gains an **agent profile** object:

| Field | Meaning |
|---|---|
| `id` | stable profile id: `claude-main`, `opencode-main`, `antigravity-worker`, `opencode-worker` |
| `kind` | `main` or `subagent` |
| `command` | per-device command template, e.g. `claude`, `agy`, `opencode` |
| `model` / `args` | optional model or flags, resolved by core policy |
| `capabilities` | reasoning, long-context read, edit, test, review |
| `budget_policy` | which provider/budget this profile may draw from |
| `status_protocol` | how the CLI reports working/blocked/done and session id |

The main agent receives MCP tools such as `list_profiles`, `pick_model`, `create_chat`, `delegate_task`, `wait_for_subagents`, `collect_results`, `cancel_task` and `token_status`; `budget_set` is admin-only. Sub-agents receive only the tools their role needs. The hub limits parallelism by device capacity and token budget, and records each delegated task as a child of the chat.

Results return to the main agent as compact summaries with references to full artifacts in the chat context. A failed sub-agent ends its own task; it does not kill the chat or its siblings.

This mirrors Herdr's own model - `hc run --bg --name ...`, `hc send`, `hc wait --children all`, templates and OSC 7501 status - but Tether remains the authority across devices and users. Herdr can be one place where the main agent runs.

## Core-owned token routing and fallback

Token handling is not a client feature. The hub records a usage event for every model call it can observe: user, chat, session, task role, provider, model, tokens in/out, cache use, cost estimate, quota remaining and timestamp.

A provider/model registry holds capability and cost metadata: context window, free-tier availability, reasoning strength, speed, edit support, user rank and privacy notes. Big Pickle is the highest-ranked OpenCode free model and the default auto-pick for large-context work; DeepSeek V4.1 Flash, Hy4 Flash, Mimo V2.6 Flash, Jev 1.13, Beam, Flint 40B, Tidepool/Seaglass Alpha, Iceman and the Nemotron free trials are also in the catalog. For each task the hub ranks providers by:

1. role fit (`main` keeps Claude Code by default; sub-agents prefer large-context free tiers);
2. user preference and explicit pinning;
3. quota headroom and budget remaining;
4. capability fit for the task (context size, reasoning, edits);
5. observed latency and reliability;
6. estimated cost.

When a model is exhausted, rate-limited or unavailable, the hub picks the next ranked model, then (for a sub-agent) another eligible profile, and records the decision. Budget changes, quota warnings and fallback decisions are exposed through `token_status`, `pick_model` and `budget_set` MCP tools. The same state appears in `Welcome`, REST and `tetherctl models`, so all-device and multi-user views agree.

This work is a hard dependency for both main/sub-agent orchestration and full v1.

## Herdr integration contract

Herdr stays external. Tether core does not vendor, fork or depend on Herdr source. The contract is:

- **Tether -> Herdr:** hub REST/MCP exposes chats, sessions, jobs, agent profiles, token status and events. A small bridge can present these as MCP tools inside a Herdr pane.
- **Herdr -> Tether:** Herdr agents call those tools to start chats, delegate sub-agents and read budgets. Tether session state can be mirrored into Herdr with `pane.report_agent` / `pane.report_metadata` where a local Herdr pane represents a Tether session.
- **Presentation mapping:** Tether chat -> Herdr workspace/tab; Tether session/sub-agent -> Herdr agent/pane; Tether job -> Herdr terminal/program. The hub keeps the authoritative ids.
- **Events:** Herdr uses `session.snapshot` + `events.subscribe` and reconciles after `events_lost` or reconnect; Tether pushes equivalent hub events to its own clients. Neither side treats events as durable replay.
- **CLI underneath:** `herdr-core` (`hc`) exposes OpenRPC via `hc schema` and `hc connect` (NDJSON JSON-RPC over stdin/stdout, socket or named pipe) with `terminal.*`, `doc.*`, events and templates. A Tether agent profile can launch a CLI through `hc run --bg` when Herdr is present, without making Herdr mandatory.
- **Auth:** Tether tokens and user permissions remain on the Tether side; local Herdr sockets remain local to the device. No shared secret is implied by this contract.

The detailed contract belongs in `docs/architecture/protocol.md` when implemented; this plan records the boundary and supported surface.

## Separate release tracks

`v0.20.0` remains the last unified tag. From the v1 work onward:

- `core-vX.Y.Z` releases the hub, agent, `tetherctl`, MCP surface and protocol. `VERSION` is the core version.
- `app-vX.Y.Z` releases the optional Flutter apps. `app/pubspec.yaml` and `app/lib/core/version.dart` are the app version.
- A core-only release can be built and deployed without an app build; an app-only release can be published without redeploying the hub.
- Compatibility is explicit: the core feed advertises required/app-compatible versions and the app manifest advertises its required core version.
- No `1.0` tag is cut until token routing and fallback are complete.

The release scripts, CI, `latest.json`, appcast and release docs change with [#42](https://github.com/Mahaveer86619/tether/issues/42).

## Build order

1. Land this plan and the issue/milestone structure (GitHub prep, done with this plan).
2. Hub-owned chat creation and session identity (#46), because orchestration and token accounting need a stable chat/session object.
3. Agent profiles plus main/sub-agent delegation (#45).
4. Usage events, provider registry, budgets and fallback (#44). Full v1 waits here.
5. Herdr bridge and contract (#41), once the tools are stable.
6. Split release tracks and docs (#42, #43).

## Definition of done for full v1

- A core-only install on any device can start a Claude Code main chat, delegate parallel large-context sub-tasks to Antigravity CLI/OpenCode CLI, and survive app/Herdr restarts.
- Token status and budget decisions are synced to every authorized device and user.
- Herdr can replace the Tether apps as the client without forking Tether or Herdr.
- Core and app releases have separate tags and can ship independently.
- The docs no longer describe the Flutter app as required.
