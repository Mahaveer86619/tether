# Tether docs

The docs are grouped by what you are doing: **product/** (what Tether is and what is next), **design/** (how it should look), **architecture/** (how it works), **plans/** (designed, not built) and **operations/** (running and releasing it).

Start with [overview.md](product/overview.md) for what Tether is made of and how a chat becomes work on a device, then [features.md](product/features.md) for what exists and what is pending.

## Getting started

| Doc | What it covers |
|---|---|
| [getting-started/](getting-started/README.md) | Which path to take, and what every setup needs |
| [using-releases.md](getting-started/using-releases.md) | Install from a GitHub release: hub, agents, apps, pairing, updating, troubleshooting |
| [from-source.md](getting-started/from-source.md) | Clone, build, test and run every part |
| [contributing.md](getting-started/contributing.md) | Where things live, conventions, branches and pull requests |

## Where things stand

| Doc | What it covers |
|---|---|
| [v1-spec.md](product/v1-spec.md) | **The feature specification for the design team**: every 1.0 feature, what the person sees and decides, key journeys, screens, states, open questions |
| [features.md](product/features.md) | Every feature, its status, the screens it touches, what is pending. The page to point at when you want a change |
| [app-audit.md](product/app-audit.md) | Every thing the app does today, by screen, where it goes in the rebuild, and what is missing |
| [ui-design.md](design/ui-design.md) | Review of the design team's first designs: what we adopt, change and drop, the structure we build, the decisions needed, and the brief to send back |
| [ui-overhaul.md](design/ui-overhaul.md) | The pass over every screen before 1.0: the rules, the screen list, the shared parts, the run card |
| [pipeline.md](product/pipeline.md) | What to build next, in order, with sizes, dependencies and the decisions needed from you |
| [roadmap.md](product/roadmap.md) | Milestones and what "done" means for each |

## How it works

| Doc | What it covers |
|---|---|
| [overview.md](product/overview.md) | The pieces, how a chat starts, how sessions on different devices are managed |
| [architecture.md](architecture/architecture.md) | Components, who connects to whom, data flow, technology choices |
| [protocol.md](architecture/protocol.md) | The wire contract between hub, agents and app: envelope, events, commands, render blocks, tool cards |
| [herdr-bridge.md](architecture/herdr-bridge.md) | How an external Herdr pane uses Tether's MCP/REST tools and mirrors hub state into agent panes |
| [hosting.md](architecture/hosting.md) | How sessions run (tmux, headless, your own terminal) and how hooks track their state and approvals |
| [sessions.md](architecture/sessions.md) | How Claude Code sessions are discovered, started, mirrored, resumed and forked |
| [chats.md](architecture/chats.md) | Chats: how they map to sessions, where they run (targets), the lead and its tasks, the context store |
| [security.md](architecture/security.md) | Trust boundaries, auth, sandboxing, approvals |
| [jobs.md](architecture/jobs.md) | Jobs: processes agents supervise (stop, pause, resume, logs, secrets), and device hardware |
| [app.md](architecture/app.md) | The Flutter app: layers, error handling, caching, background sync, every view |

## Plans (designed, not built)

| Doc | What it covers |
|---|---|
| [terminal-mode.md](plans/terminal-mode.md) | A second way to see a session: the assistant's own interface, live, with a key row on the phone |
| [second-brain-rust.md](plans/second-brain-rust.md) | The second brain as one small Rust program beside codebase-memory-mcp: memories, notes linked to code, recall |
| [remote-projects.md](plans/remote-projects.md) | A chat made remote: the code kept in step on another device through a repo on the hub, secrets served from the vault, live progress |
| [token-pool.md](plans/token-pool.md) | Tracking tokens and the 5-hour, day and week limits, learning when you use Tether, scheduling long work into your free time, and a pool where free frames are offered and booked between users |
| [teams.md](plans/teams.md) | Projects as real objects with a project chat and spawned sessions in the sidebar, one-off chats kept quiet, then users, workspaces, roles and lent devices |
| [core-first-v1.md](plans/core-first-v1.md) | **The v1 direction**: core as the MVP on every device, apps optional, Herdr as an external client, hub-started chats, main/sub-agents, token routing and split release tracks |
| [harness.md](plans/harness.md) | What Tether is as a harness, what a harness has, what Tether has and adds, and the order of what is missing |
| [prompt-desk.md](plans/prompt-desk.md) | Rewind a chat to an earlier prompt, saved rules, searching and running skills (scripts included), insights from your own data, context management |
| [shared-workspace.md](plans/shared-workspace.md) | A real-time workspace held on the hub and kept in step on every device, and jobs (servers, long scripts) that run on any device and can be paused and resumed |
| [deliverables.md](plans/deliverables.md) | Asking for a thing and getting the file in the chat: builds, exports, reports, with Download and Install |
| [first-run.md](plans/first-run.md) | Setup that assumes nothing about the owner's machine: the doctor, the hub installer, the guided flow |
| [notifications.md](plans/notifications.md) | What notifies, and how it reaches a sleeping phone |
| [agent-tools.md](architecture/agent-tools.md) | Engines behind one contract, what Tether gives the assistant, choosing skills, security for 1.0 |
| [previews-and-guides.md](plans/previews-and-guides.md) | Previews of files and results inside the chat, and interactive guides: websites Claude builds for things a chat can't show |
| [skills.md](plans/skills.md) | Learning routines into skills: built so far, what it showed, what is next |
| [uninstall.md](plans/uninstall.md) | Removing Tether's data or Tether itself, per scope and per device, including devices that are offline |
| [plan.md](plans/plan.md) | Longer plans: pairing, fork/branch/merge, the second brain, hub sessions, artifacts, usage, users and roles |

## Running it

| Doc | What it covers |
|---|---|
| [running.md](operations/running.md) | Building, deploying the hub and agents, and using `tetherctl` |
| [releasing.md](operations/releasing.md) | Versions, tagging a release, CI (self-hosted runner on the hub's machine), deploy with rollback, signing, how apps and agents update |
| [GITHUB-SETUP.md](operations/GITHUB-SETUP.md) | One-time GitHub setup for the repo owner, with `deploy/ci/github-bootstrap.sh`, and the signing key decision |
| [home-server.md](operations/home-server.md) | Mini PC sandbox and NAS setup, plus the current state of that machine |

## Keeping the docs true

- A change that alters what the app or hub does updates the doc it belongs to in the same commit, and the row in [features.md](product/features.md).
- A plan says *Status: plan* at the top and moves its text into the doc of the thing it became when it's built.
- No doc holds private details (addresses, users, tokens). Those live in the git-ignored `.local/`.
