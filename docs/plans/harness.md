# Tether as a harness

Status: positioning and gap list. It sets the order for the plans in [prompt-desk.md](prompt-desk.md) and [shared-workspace.md](shared-workspace.md).

## What Tether is

An agent **harness** is everything around a model that turns it into a working agent: the loop, the tools, the context it is given, permissions, memory, hooks, sub-agents, sessions, and the means to observe and improve it. Claude Code is one. Tether is a harness **around** Claude Code, not a replacement for its loop: it runs Claude Code sessions on many machines and adds what a single terminal harness cannot have, because it sees all of them.

The fair name for it is a **multi-device harness and control plane**: Claude Code stays the inner harness (the agent loop and its built-in tools); Tether is the outer one (where it runs, what it is told, what it may do, what it remembers, how you reach it).

## A harness, part by part

| Part of a harness | Claude Code alone | In Tether today | Next |
|---|---|---|---|
| Agent loop | Yes | Reused as is (headless, tmux, terminal) | |
| Tools | Built in, plus MCP | Hub MCP: sessions, files, skills, rules, guide; brain MCP | Jobs, workspace, GPU tools ([shared-workspace.md](shared-workspace.md)) |
| System prompt and standing instructions | `CLAUDE.md`, per machine | The lead prompt, machines online, skills offered, **rules** (everywhere, device, project), the **guide** | Rules suggested from your own history ([prompt-desk.md](prompt-desk.md#insights)) |
| Knowing itself | Docs outside the session | `tether_guide`: parts, data tables, state, tools, served by the hub | Keep it true with each release (a test checks it names the tables) |
| Context management | Compaction, `/clear`, resume | Chat context store, carry on move | Rewind, recap, a context meter, summary carry |
| Memory | Memory files | The second brain: memories and notes linked to code | Decisions saved from chats with approval |
| Skills | Skills folders | Learned from repeated requests, approved, versioned; served over MCP | Search, run by name, scripts as skills |
| Sub-agents and orchestration | Sub-agents in one session | The lead hands tasks to sessions on other devices, with reports | Jobs; GPU placement |
| Permissions and approvals | Prompts in the terminal | Approvals from anywhere, modes, audit | Per-project policy; scripts declare their effect |
| Sessions, checkpoints | Resume, fork | Resume, fork, continue on another device, remote projects | Rewind to a prompt; a live shared workspace |
| Hooks and automation | Hooks | Hooks used to track state and approvals | User-defined triggers and schedules (planned in the roadmap) |
| Observability | Logs | Timeline, usage and cost, audit log | Insights: stats and on-demand analysis |
| Evaluation and improvement | None | Routine finding | Insights recommend rules and skills; replay of a skill against a past task |
| Sandboxing and isolation | Permission modes, sandbox | Hub sessions in scratch folders, containers on the home server | Policy per device and project |
| Delivery to the user | Terminal | Phone and desktop app, notifications, deliverables | |

## What Tether adds that a single harness cannot

- **One view of every session on every device**, including terminal ones, and moving work between them.
- **Placement**: the right device for the job (the GPU box, the sandbox), chosen by you or by the lead.
- **Always-on state**: the hub holds chats, files, rules, skills and the data they are learned from while your laptop sleeps.
- **Learning from use**: what you repeat becomes a rule or a skill, with your approval.
- **Reach**: approve, steer and read from a phone.

## Order

The gaps that matter most, in order: **knowing itself** (done: the guide), **standing instructions** (done: rules), **seeing its own data** (Insights, measure), **checkpoints** (rewind), **skills that run** (search, scripts), **placement and long work** (devices with a GPU, jobs, the shared workspace), then **policy** and **user-defined automation**.
