# A shared workspace and long-running jobs

Status: plan. **Built:** jobs on a single device (start, stop, pause, resume, status, log streaming, restart policies, `lost` after a restart), the server address, jobs from chat over MCP, and device hardware in the agent's report and the lead's prompt; see [jobs.md](../architecture/jobs.md). Not built: workspace sync, moving a job between devices. It extends [remote-projects.md](remote-projects.md), which keeps a project in step between two devices after each turn, to a workspace that is in step in real time across any number of devices, and adds jobs that run on any device and can be paused and resumed.

## What changed in the plan

- **Workspaces are synced by default.** A project in a workspace (personal or shared, see [teams.md](teams.md#b-users-and-workspaces)) is held on the hub and kept in step on every device of the people in it, with no per-chat switch.
- **A new device imports.** A device a user adds to their account sees the user's workspaces and imports the projects they choose (or all); from then on it is kept up to date by the live sync below. Nothing is copied by hand.
- **It replaces *make this chat remote*.** The remote-projects feature ([remote-projects.md](remote-projects.md): a git mirror made per chat, after each turn, with a writer lease) goes away once workspace sync works: its sheet in the app, its hub routes and the per-chat mirror are removed, and a chat simply runs on whichever device it is sent to, with its project already there. The vault for `.env` and the `.git` single-writer rule below carry over.

## The need

- The hub is always on, so it can hold the one copy of a workspace.
- A desktop with a GPU is coming. Work should run on whichever device suits it (the GPU box for a model or a render, the laptop for a quick edit) without copying folders by hand.
- Servers and long scripts should be started, stopped, paused and resumed from the app, on any device, and survive the app being closed.

## Two parts

| Part | Answers |
|---|---|
| **Workspace sync** | Where are my files, and are they the same everywhere? |
| **Jobs** | Where is this server or script running, and can I pause it? |

They are separate on purpose: a job needs its files to be present, nothing more.

## Workspace sync

**Model.** A *workspace* is a folder tree the hub holds, with a **device copy** on each device that joined it. The hub is the meeting point, not a place work happens: edits made on a device flow to the hub and from the hub to the other devices.

```
 laptop copy ─┐                       ┌─ desktop (GPU) copy
              ├──▶  hub: the workspace ◀──┤
 minipc copy ─┘     (manifest + blobs)  └─ phone (browse, edit one file)
```

**How it stays in step.**

1. Each agent watches its copy (file-system events, with a periodic scan as the safety net, since events are lost on some systems) and keeps a **manifest**: path, size, modified time, content hash.
2. A change is sent to the hub as a **delta against the hub's version of that file**: the file's new content-defined chunks (rolling hash), so a one-line edit to a large file sends one chunk. Whole-file send for small files.
3. The hub keeps the manifest and the chunks (content-addressed, so an identical file on two devices is stored once), and pushes the change to the other devices over the connection they already hold. Devices that are offline catch up from their last-seen version when they return.
4. **Ordering.** Every change carries the version it was made from. If it is made from the hub's current version, it wins. If two devices changed the same file from the same version, the later one to reach the hub is kept and the other is saved beside it as `name.conflict-<device>-<time>`, and the app shows the conflict. No merging of file contents.
5. **Deletes and renames** are changes like the others, with a trash on the hub for 30 days so a mistaken delete is undone.

**What does not sync.** Folders that are rebuilt or huge or machine-specific: `.git` (see below), `node_modules`, `target`, `build`, `.dart_tool`, virtualenvs, caches, anything in the workspace's ignore list (a `.tetherignore`, as now). Secrets stay out: `.env` and the like keep going through the sealed project files, served only to allowed devices, so a device that is not trusted never receives them.

**Git.** The workspace can be a git repository. Syncing `.git` itself through a file syncer corrupts it when two devices write at once, so the hub treats it as a **single-writer** folder: the device that holds the *writer lease* (the lease in [remote-projects.md](remote-projects.md)) commits, and the others get the result of `git` operations as ordinary file changes after it finishes. Until a device holds the lease, its git operations are refused with a message saying who holds it.

**Large files.** Models, datasets and builds do not sync by default. A workspace marks folders as *big*: they sync on demand (a device asks for a file, or a folder, and the hub sends it with resume and a hash check, as the artifact store does), and a result a GPU job writes is pushed back when it is closed.

**Relation to the existing remote projects.** Remote projects stay as they are (turn-based, through git on the hub), and a workspace is the real-time option for a project. Moving a project to a workspace replaces the git mirror with live sync, and keeps the git single-writer rule above.

**Options considered.**

| Option | For | Against |
|---|---|---|
| Our own sync in the agent and hub (chosen) | One system, the hub is the center, uses the connection and trust Tether has, ties into leases, vault and the app | The most to build; conflict and rename edge cases are ours |
| Syncthing between the devices | Mature, no code | Peer to peer, no central copy, no hub tie-in, a second thing to install and pair, `.git` corruption risks |
| rsync/Unison on a timer | Simple | Not real time; no notion of the hub as the center |
| A network share (SMB/NFS) | Nothing to sync | Not over a phone or flaky links, nothing offline, slow for builds |

## Jobs

**The need.** Start a server or a script on a device and manage it from the app: see it, read its output, stop it, **pause** it and **resume** it, and have it survive the app closing. Move work to another device.

**What a job is.** A process the agent starts and supervises: a name, the device, a folder (usually a workspace), the command, its environment (secrets from the project's sealed files, not on the command line), a state, and its output. States: `starting`, `running`, `paused`, `exited`, `failed`, `stopped`.

**Control, honestly.**

| Action | How | Notes |
|---|---|---|
| Start, stop | The agent runs it in its own process group (a Windows Job Object on Windows) and signals the group; stop is a polite signal, then a kill after a grace period | Output goes to a log the agent keeps and streams to the hub |
| **Pause** | Linux/macOS: `SIGSTOP` to the group. Windows: suspend every thread of the Job Object's processes | Memory stays held; network connections may time out on the other side; a paused GPU process keeps its VRAM. The app says so |
| **Resume** | `SIGCONT` / resume threads | Same device, same process |
| **Move** | Stop on A (asking the job to **checkpoint** if it declares how), sync the workspace, start on B with the same command | A running process cannot be moved between machines. A job that checkpoints (a training script that saves state, a server that is stateless) *resumes* on B. One that does not *restarts* on B. The job's manifest says which it is |
| Restart on failure | An optional policy: never, on failure, always, with a limit | Reported as events in the app |

A job outlives the agent's restarts: the agent records its jobs and re-adopts or reports as lost what it finds after a restart. A job that was running when the device slept or restarted is shown as `lost`, with a *Start again* button.

**Servers.** A server is a job that declares a port. The hub can show the address and, over Tailscale, link to it from the app, so a dev server on the GPU box opens from the laptop. Nothing is exposed beyond the tailnet.

**GPU devices.** The agent reports what the device has (GPUs, memory) with its capabilities, as it reports `docker`, `go` and the rest. A job (and a task session) can ask for `gpu`, and the lead's prompt already lists machines with their capabilities, so Claude can send a GPU task to the right device. The same data fills a *Devices* card.

**Running a job from a chat.** The lead starts a job with a hub MCP tool (`start_job`, `job_status`, `job_logs`, `stop_job`, `pause_job`, `resume_job`), so "run the trainer on the desktop and tell me when the loss flattens" is a chat, and the job shows in the chat's Tasks strip and on a Jobs page.

## Build order

1. **Jobs, single device** (built): start, stop, status, log streaming, process groups, Windows and Linux, the Jobs page. Pause and resume. Tests with a fake long-running process.
2. **Device capabilities** (built): GPU and memory in the agent's report; shown in Devices and in the lead's prompt.
3. **Workspace sync, read path**: the manifest and content-addressed store on the hub, a device joining and pulling.
4. **Workspace sync, live**: watchers, deltas, ordering, conflict files, ignore rules.
5. **Jobs across devices**: move with checkpoint or restart. (The server address, restart policies and jobs from chat over MCP are built.)
6. **Big folders on demand, the git single-writer rule.**

## Tests

Temporary folders and fake agents, never a real workspace:

- **Sync**: two device copies and a hub in one process; edits, deletes, renames and a same-file conflict end with the expected files and one conflict copy; a device offline during ten edits catches up exactly; an ignored folder never leaves a device; `.env` never goes through the workspace.
- **Deltas**: a one-line edit to a large file sends one chunk; the result hashes equal on both sides.
- **Jobs**: a process that prints a counter is started, paused (the counter stops), resumed (it continues), stopped (the process group is gone, children too); a job whose agent restarts is reported `lost` rather than `running`.
- **Windows and Linux** run the same cases in CI (the Windows leg on the GitHub runner).

## Open questions

- Whether phones join a workspace as a copy (no: browse and edit single files through the hub).
- The size where a folder becomes *big* by default.
- Whether a paused job should release a GPU. A process cannot give its memory back while paused, so the app warns instead.
- Fetching big folders over Tailscale between two non-hub devices directly (peer to peer) once both are online, to spare the hub's link.
