# Herdr bridge contract

Herdr is an optional, external harness. Tether core owns chats, sessions, agents, permissions and token budgets; Herdr owns panes, terminal UI and agent-status display. The bridge is a small stdio MCP server that runs beside Herdr and calls Herdr's public CLI. It does not vendor, wrap or fork Herdr code, and Tether does not depend on Herdr being installed.

## Pieces

| Name | Owns | Surface used by the bridge |
|---|---|---|
| Tether hub | Chat/session/task identity, targets, profiles, budgets, permissions, events | `POST /mcp`, `GET /api/v1/state`, WebSocket `subscribe` for richer clients |
| `tether-herdr` | Mapping and reconciliation between the two | stdio MCP to the local agent; HTTP to the hub |
| Herdr app | Panes, tabs, agent state, metadata display | `herdr pane report-agent`, `herdr pane report-metadata`, `herdr workspace/tab/pane ...` |
| herdr-core (`hc`) | Long-lived terminals and program status | `hc run --bg`, `hc send`, `hc wait --children all`, `hc schema`, `hc connect` |

The hub remains authoritative. A Herdr pane is a view of a Tether session, not a second place where a chat is created. Reconnecting clients reattach through the chat id; they never start a new lead.

## Mapping

| Tether | Herdr | How the bridge uses it |
|---|---|---|
| Chat | Workspace/tab | The pane is bound with `-chat <chat-id>`; `create_chat` records the chat in pane metadata (`tether_chat`). |
| Session or delegated task | Agent/pane or pane agent state | `report-agent` maps Tether's running/approval/ready/error states to Herdr `working`/`blocked`/`idle`/`unknown`, and stores the session id as `agent_session_id`. |
| Job or watch terminal | Terminal/program | With `-watch`, `hc run --bg --name tether-<short-id> tetherctl chat-watch <chat>` (or `tetherctl watch <session>` for a task) opens a recoverable terminal that follows hub state. |

The pane metadata tokens are prefixed `tether_`: `chat`, `session`, `task`, `profile`, `model`, `node`, `state`, `decision`, `reason`, `tokens` and `terminal`. Values are display-only; semantic state always comes through `report-agent`.

## Setup

Build `tether-herdr` with the hub binaries (`make dist-go` or `make dist`), put it on `PATH` in the Herdr pane, and set the hub credentials:

```sh
export TETHER_HUB=wss://hub.example/ws
export TETHER_TOKEN=<device-token>
export HERDR_PANE_ID=$(herdr pane current --pane --current | jq -r '.result.pane.pane_id')

# In the pane that represents a chat:
tether-herdr -chat <chat-id> -watch
```

Register it as a stdio MCP server with the agent in that pane. With Claude Code, for example:

```sh
claude mcp add tether -- tether-herdr -chat <chat-id>
```

Other MCP clients accept the same command. The bridge forwards `tools/list` and `tools/call` to the hub, so the agent sees the full core toolset: `list_profiles`, `pick_model`, `token_status`, `budget_set` (admin), `create_chat`, `delegate_task`, `wait_for_subagents`, `collect_results`, `cancel_task`, and the existing session/artifact tools. An agent can ask core to start a chat, delegate sub-agents and read token status without ever seeing a Tether app.

To use herdr-core directly from a pane, `hc --skill` is the agent's manual. Tether profile commands stay on core's side: Herdr never supplies a CLI command to a Tether chat.

## Authentication and trust

- Tether: `TETHER_TOKEN` is sent only to the hub as `Authorization: Bearer ...`. It never goes into Herdr metadata. `TETHER_HUB_FINGERPRINT` pins a self-signed hub certificate, exactly as for `tetherctl`.
- Herdr: the CLI uses the local Herdr socket or named pipe under the user's account. The bridge inherits `HERDR_SOCKET_PATH`, `HERDR_PANE_ID`, `HERDR_TAB_ID` and `HERDR_WORKSPACE_ID` when started inside a pane. No Herdr secret is copied into Tether.
- `-watch` starts `tetherctl` inside `hc`; that child inherits the hub environment so it can follow the session. It is opt-in because it creates a new terminal.
- `-source` and `-agent` control the Herdr report owner. Keep one bridge per pane, or give each a distinct `--source`, so two bridges do not fight over lifecycle authority.

## Events and reconnection

Neither side treats events as durable replay. The bridge uses `GET /api/v1/state` as its bootstrap and reconciliation point, then polls it every `-poll` interval (5 seconds by default, `0` disables mirroring). It reports an agent state only when a session's Tether state changes; metadata is refreshed on each poll so a missed Herdr update is repaired.

On bridge restart or a hub reconnect:

1. Call `GET /api/v1/state` again and rebind `-chat`/`-session` to the now-active session ids.
2. Re-report every watched session's current state and metadata; do not replay old timeline items.
3. In Herdr, treat incoming events as invalidation signals: call `herdr api snapshot` on another connection and reconcile current state instead of replaying buffered events onto a stale cache. On `events_lost`, resubscribe and reconcile again.

Clients that need live timelines can subscribe over the Tether WebSocket with `after_seq` and reconcile from the hub's timeline pages. The bridge stays deliberately small: hub state is the source of truth, Herdr state is a projection.

## Supported versions

| Component | Minimum | Notes |
|---|---|---|
| Tether hub | `0.20.0` | Needs hub-started chats, core profiles and `POST /mcp`. Older hubs do not have `create_chat` or `token_status`. |
| Herdr app | `0.9.0` | Needs `pane.report_agent`, `pane.report_metadata` and `herdr api snapshot`. Check with `herdr --version`. |
| herdr-core | `0.1.x`, protocol generation 1 | Needs `hc run --bg` and `hc schema`. Check with `hc --version` and `hc schema`; JSON API clients ignore unknown fields and handle unsupported methods as ordinary errors. |

Herdr's client and server builds may differ; only the API generation matters. If a method is missing, the bridge logs it to stderr and the MCP tools still work. Tether keeps no build dependency on either Herdr binary.

## Troubleshooting

- **No pane state changes**: check `HERDR_PANE_ID` (or pass `-pane`), and confirm `herdr pane report-agent --help` exists in that pane.
- **No tools over MCP**: confirm the hub URL, token, and `curl -H "Authorization: Bearer $TETHER_TOKEN" <base>/mcp` behaviour; the bridge forwards hub errors as MCP errors.
- **Watch terminal does not open**: `-watch` needs both `hc` and `tetherctl` on `PATH`; the child inherits the hub environment.
- **Stale agent state after Herdr restart**: run `herdr api snapshot` and restart the bridge; it rebinds from hub state rather than replaying events.
