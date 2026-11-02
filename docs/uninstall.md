# Uninstall and clean start

Status: plan, nothing built.

## What it is for

- A **clean uninstall**: Tether gone from every machine, with the user choosing what data goes with it.
- A **fresh start**: keep Tether installed but delete what it has gathered, on every connected device or one.

The point is that the user can leave or reset without hunting for files on four machines.

## What Tether keeps, and where

| Data | Where | Scope name |
|---|---|---|
| Attachments and artifacts (files, images, pages) | hub: `artifacts/`, `uploads/`, `hub.db` rows | `attachments` |
| Skills (see [skills.md](skills.md)) | hub store, and copies in each machine's `~/.claude/skills/` and project folders | `skills` |
| Chats, titles, notes, stored context | hub: `hub.db` | `chats` |
| Session history and timelines, transcript backups | hub: `history/`, `hub.db`; agents' upload state | `history` |
| Codebase snapshots and the `.env` vault | hub: `staging/`, `secrets.key` | `codebases` |
| Usage records | hub: `hub.db` | `usage` |
| Hub settings, devices and tokens | hub: `hub.db`, `tether.env` | `settings` |
| Agent state, token, logs, hooks, MCP registration, scratch folders | each machine: `~/.tether/`, entries in `~/.claude/settings.json` and Claude's MCP config | `device` |
| App cache, drafts, outbox, saved connection | each app's storage | `app` |

Never deleted: the user's project folders and Claude Code's own transcripts in `~/.claude/projects`. Removing Tether takes out only what Tether added to Claude's settings (hooks and the MCP entry), restoring the backup the install made.

## What the user sees

Settings gets **Remove Tether data**:

1. Pick a scope: individual checkboxes, or the presets **Attachments**, **Skills**, **History and chats**, **Everything**.
2. Pick the devices: all, or specific ones (each device and app is listed with its last-seen time).
3. A summary of what will go, with sizes ("4.2 GB of attachments, 38 chats, 6 skills"), and for a device, what it will change on that machine.
4. Confirm by typing a phrase. Only the admin token or the owner's app can do this.
5. A progress list per device: done, waiting for the device to come online, failed.

**Uninstall** is the same screen with the `device` and `app` scopes added and a final step that removes the binaries, the service or scheduled task and, last, the hub's own data.

## How deletion reaches every device

The hub keeps a table of **wipe orders**: id, scope, target (all, or a device id), created, and per device: delivered, done, error. An order is a fact in the database, so it survives restarts and offline devices.

- A device that is online gets the order at once, as a command.
- A device that is offline gets it **when it next connects**: on connect the hub sends every open order addressed to it before anything else. This is the "delete whenever it gets connected" rule. It applies to apps too (the order arrives in the welcome).
- A device acts, then reports `done` with counts. The hub marks it and shows it in the progress list.
- The hub wipes its own data last, after it has recorded the orders, so a hub that is reset can still tell reconnecting devices what to do. A fresh start keeps the orders table; an uninstall of the hub hands the unfinished orders to the user as a list ("these devices have not been cleaned").
- **Specific device:** an order with a target. **Everything everywhere:** an order with no target, which also applies to devices paired later until the owner cancels it.
- An order can be **cancelled** before a device has acted on it. After that it can't be undone, and the confirmation says so.

## Safety

- Dry run first: the summary comes from the same code that deletes, run read-only.
- The hub refuses a wipe that would remove data in use (a running session's folder, an upload in progress) unless the user stops those first or chooses to.
- Scope names are fixed; nothing is deleted by pattern from user input.
- Deleting `secrets.key` makes the codebase vault unreadable, so `codebases` and `settings` are listed together with a warning.
- Every order and its outcome is logged on the hub until `settings` is wiped.

## Without the app

For when the hub or the app can't be reached:

- `tether-agent uninstall [--keep-data]` removes this machine's agent, hooks, MCP entry, scheduled task or service, and (unless kept) `~/.tether`.
- `tetherctl wipe --scope ... [--device ...]` creates an order from the hub's machine.
- The Windows app's installer removes the app and its saved data.

## Build order

1. The data inventory: one function per scope that lists and sizes what it holds, with tests on a scratch data directory.
2. Deletion per scope on the hub, behind a dry run.
3. The orders table, delivery on connect, and the agent and app handlers.
4. The Settings screen and progress list.
5. `tether-agent uninstall`, `tetherctl wipe` and the installer step.

Tests use temporary data directories and fake devices only. None run against real sessions or the live hub.
