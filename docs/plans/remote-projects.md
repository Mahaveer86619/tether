# Remote projects: the hub runs the work, devices follow

Built in 0.17.7 (the hub, the agents and a sheet in the chat). It extends [chats](../architecture/chats.md) and the codebase snapshots and `.env` vault in [plan.md](plan.md#codebases-on-the-hub).

## What the owner wants

1. Every chat lives on the hub. The hub can reach the other devices and hand Claude tasks to them one by one, and the app shows live progress so watching is easy.
2. A switch in the chat makes it **remote**: the project's code is copied to another device and kept in step with git while the chat goes on.
3. The files git should not hold (`.env`, `config.json`) come from a small credential store in Tether, served the first time a project is set up on a device, with a tool in the app to write them.

## What exists already

- Chats are stored on the hub with their sessions, targets (`auto`, `manual`, `claude`) and moves between devices. The leading session already hands work to sessions on other machines through the hub's MCP (`start_session` with `chat`), and the chat shows them as tasks.
- Sessions stream to every app live (timelines, states, approvals, notifications).
- Codebases are found on each device, snapshotted to the hub, and their `.env` files are kept sealed (AES-GCM, `secrets.key`); apps see key names, never values.

So (1) is mostly built. What is missing is the project's *code* on the other device, and a way to put the secrets there.

## Design

### Where the code lives: a repo on the hub per remote project

The hub keeps a bare git repository for each project made remote (`<data>/repos/<project>.git`) and serves it over HTTPS on the tailnet with `git http-backend`, behind the same token as the rest of the hub. The owner needs no GitHub account or deploy key, and a project without a remote of its own can still be shared. If the project already has an `origin`, the hub repo is an extra remote; it never pushes to `origin` by itself.

### One writer at a time

A remote chat holds a **lease** on its project: the device whose session is working. While it runs, its agent commits the working tree to a branch `tether/<chat>` at the end of every turn (and on idle for a while) and pushes it. Other devices are read-only mirrors and pull when asked or when the lease moves. Moving a chat to another device (already supported) passes the lease: the old device does a last push, the new one checks the branch out. Two sessions writing the same project at once is refused with a message, which avoids merge conflicts. Merging `tether/<chat>` back to the main branch stays the owner's choice (a button in the chat, or Claude does it when asked).

### The toggle

In the chat header: **Remote** with the device picker. Turning it on: the hub creates the repo if needed, the source device pushes, the target device clones and gets its secrets (below), and the chat moves there. Turning it off leaves the target's copy where it is and returns the lease. The toggle is only offered for projects with a project folder (not one-off chats; see `HubSnapshot.projectOf`).

### Credentials and config: the vault serves them

Extend the existing vault from `.env` files found in codebases to **project files**: a path in the project, its content, sealed on the hub. Rules:

- Written from the app (a **Setup** page for a project: add a file, paste or edit its contents, or import what the source device already has) and from `tetherctl`.
- On first setup of a project on a device, and whenever a file changes, the agent asks the hub for the project's files over the existing authenticated channel and writes them with mode 600. They are added to `.git/info/exclude`, never committed.
- The app never shows values by default (keys only, "reveal" needs a confirmation), as today. Values are not sent through the notification tunnel, and are sent to an agent only if the device is allowed to hold that project.
- A device must be **allowed** to run a project's secrets: a per-project, per-device switch, off until the owner turns it on in the toggle's first-time dialog.

### Live monitoring

The hub already broadcasts session and timeline changes. Added: a per-chat **tasks** summary (which device, what it is doing, last event, how long) kept up to date as the leading session starts and finishes remote sessions, shown on Home under Running and in the chat; and sync state for a remote project (pushed, pulling, behind, conflict refused) as one line per device.

## What is built

- **Hub repos** (`hub/repos.go`): `POST /api/v1/repos`, and `/git/<id>.git` served by `git http-backend` behind the hub's token. Repository ids are the folder name plus a short hash of its device and path.
- **`gitsync`** (`internal/gitsync`): `Snapshot` commits the folder to its own ref (`refs/tether/<branch>`) using a private index, so the person's branch, index and stash are untouched; `Push` sends it to `tether/<branch>` on the hub; `Pull` fetches it and checks it out, refusing (`ErrDirty`) if the folder changed since its last sync, and treating a former writer as unchanged while it still matches what it last pushed. Files deleted by the writer are removed on the follower.
- **Chat remote state** (`hub/remote.go`, table `chat_remote`): `POST /chats/{id}/remote` pushes from the chat's device, pulls on the chosen one, then moves the chat there with the existing move, which makes it the writer and the old device the follower. After every turn (`noteTurnEnded`) the writer pushes and the follower pulls. A sync that gets no answer in five minutes is marked failed.
- **Agents**: the `SyncProject` command runs `gitsync` against the hub with the agent's own token; after a pull it asks the hub for the project's setup files and writes them (mode 600, excluded from git) if the device is allowed.
- **Vault** (`hub/projectfiles.go`, tables `project_files`, `project_nodes`): setup files sealed with the hub's `secrets.key`, listed by key names only, served only to allowed devices.
- **App**: a cloud icon in the chat header opens the Remote project sheet: pick a device and whether it may receive the setup files, make it remote, watch it sync (it looks again every three seconds while working), stop; and add, replace or delete setup files, whose values are never shown.

Not yet: sync lines for remote projects on Home, importing the `.env` files a device already has, `tetherctl` commands for setup files, a per-device switch in the app after the first time, merging `tether/<chat>` back into the main branch.

## Order of work (as planned)

1. **Hub repos and transport** (Go): bare repos, `git http-backend` handler, token auth, agent push/pull of a branch, tests against a temp repo. Needs `git` on the hub and agents (the doctor already checks it).
2. **Lease and sync loop** in the agent: commit at end of turn, push, pull on lease change; refusal when a second writer appears.
3. **Project files in the vault**: schema (append a migration), API, agent fetch on setup, `tetherctl` commands.
4. **App**: Remote toggle with device picker and first-time dialog, project Setup page, sync lines, per-chat task summary.
5. **Docs and a live test** on the laptop and minipc, in scratch folders only.

## Decisions to confirm

- Hub-hosted bare repos (recommended) versus using each project's existing `origin` for transport.
- One writer with a lease (recommended) versus allowing parallel edits with merges.
- Secrets reach a device only when that device is allowed for that project (recommended).
