# Tether docs

The docs are grouped by what you are doing: **product/** (what Tether is and what is next), **design/** (how it should look), **architecture/** (how it works), **plans/** (designed, not built) and **operations/** (running and releasing it).

Start with [overview.md](product/overview.md) for what Tether is made of and how a chat becomes work on a device, then [features.md](product/features.md) for what exists and what is pending.

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
| [hosting.md](architecture/hosting.md) | How sessions run (tmux, headless, your own terminal) and how hooks track their state and approvals |
| [sessions.md](architecture/sessions.md) | How Claude Code sessions are discovered, started, mirrored, resumed and forked |
| [chats.md](architecture/chats.md) | Chats: how they map to sessions, where they run (targets), the lead and its tasks, the context store |
| [security.md](architecture/security.md) | Trust boundaries, auth, sandboxing, approvals |
| [app.md](architecture/app.md) | The Flutter app: layers, error handling, caching, background sync, every view |

## Plans (designed, not built)

| Doc | What it covers |
|---|---|
| [terminal-mode.md](plans/terminal-mode.md) | A second way to see a session: the assistant's own interface, live, with a key row on the phone |
| [remote-projects.md](plans/remote-projects.md) | A chat made remote: the code kept in step on another device through a repo on the hub, secrets served from the vault, live progress |
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
