# First run

Status: plan. Product view: [v1-spec.md](../product/v1-spec.md#a1-first-run-setup).

## The problem

Tether works today because its author already had Claude Code installed and signed in, Tailscale running, projects in known places and a hub deployed by hand. The setup was built on top of that and never had to ask for any of it. A second person meets each of those as an unexplained failure, and some of Tether's defaults (workspace roots, which sessions to index, what to sync) are the author's habits.

## What a person needs before Tether can work

| Need | Where | If missing |
|---|---|---|
| One always-on machine, on a private network | The hub's machine | Nothing works; say so first and show how |
| A private network (Tailscale) on every device | Hub, agents, phone, desktop | The app starts it or says what to do (done) |
| The assistant installed on each machine that should run work | Agent machines | Show the install command for that OS |
| The assistant signed in on each of them | Agent machines | Show the sign-in step; Tether never handles the credentials |
| The agent running, with hooks and the MCP entry installed | Agent machines | The installer does it; the doctor confirms |
| A way into the hub: pairing code, QR or token | Every app and agent | The flow below |
| A terminal multiplexer (Linux) for sessions the app starts | Linux agents | The doctor says, with the install line |

## The flow

Five steps at most, resumable, each skippable where it can be.

1. **Welcome.** Two sentences on what Tether is. Choose *Set up my first device* or *Join a hub I already have*.
2. **The hub.** *First time:* the app says it needs one always-on machine and shows a one-line install command for its OS, then waits and detects the hub appearing on the network. *Joining:* scan a QR, or enter an address and a code.
3. **This machine.** The agent installs (a command the app shows on desktop, or the person runs); the **doctor** (below) checks it and shows the checklist.
4. **Make it theirs.** Where do your projects live (suggest folders found, never assume)? Sync session history to the hub (a plain explanation; off by default for a second person, on by default for the owner's existing setup)? Notifications on?
5. **First chat.** A suggested first message and a short tour.

### The hub installer

A single command per OS, from the release (`install-hub.sh`), that: downloads the hub for the machine, creates its data folder and token, installs the service, opens nothing to the internet, starts it and prints the address and a pairing code. Idempotent; safe to run again; prints what it did. For a person without a spare always-on machine, the docs say plainly that a laptop that sleeps makes a poor hub.

### The doctor

`tether-agent doctor` runs the checks and prints them as text or JSON; the agent runs the same checks and reports them in its node status so the app can show them per device:

| Check | Pass | Fix offered |
|---|---|---|
| Assistant installed | `claude --version` runs, version supported | Install link and command |
| Assistant signed in | A quick no-op run succeeds | "Run `claude` once and sign in" |
| Private network up | The hub's address answers | The app's own banner |
| Agent running | It is, if the report arrives | Start command |
| Hooks installed | Tether's entries are in the assistant's settings, with a backup | Reinstall hooks (one button) |
| MCP entry installed | The assistant lists the hub's tools | Reinstall |
| Terminal tools | `tmux` present (Linux) | Install line |
| Disk | Free space over a threshold | Say how much |
| Clock | Within a minute of the hub (signed links depend on it) | Say so |

Each check returns pass, warn or fail, a sentence and an optional fix the agent can apply itself with the person's say-so. Nothing is changed silently.

## What stops being assumed

- **Workspaces:** no roots until the person gives some or accepts suggestions found by looking for git folders; Auto works from sessions they actually run.
- **History:** the first sync backfills only what the person allows.
- **Models and modes:** the assistant's own defaults; Tether adds nothing.
- **The author's machines and names:** no defaults anywhere in the app or the installers.
- **Skills:** none until the person approves one.

## Tests

- The doctor against a scripted machine for each failure (no assistant, not signed in, old version, no multiplexer, wrong clock) returns the right result and fix.
- The installer on a clean Ubuntu container and a clean Windows machine ends with a hub that answers and a pairing code that works; run twice, it changes nothing.
- A scripted first run with a fake hub: every step, every skip, closing and resuming mid-way.
- A review by someone who has never seen Tether, from "downloaded the app" to "first answer", timed; the target is five minutes once a hub exists.

## Build order

1. The doctor in the agent and its report in the node status; the checklist screen.
2. The hub installer.
3. The first-run flow in the app on top of them.
4. The "make it theirs" step and the removal of author defaults.
5. The timed review with a second person.

## Open

- Does the app install the agent itself on a desktop, or only show the command?
- A hosted guide for the hub machine (a page Claude can build) versus text in the app.
- A signed installer for Windows so the agent doesn't trip the system's protection.
