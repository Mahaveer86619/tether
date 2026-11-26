# Users, teams and projects

Status: step A built (projects, project chats, the sidebar by project); step B planned. It makes **projects** a real thing (today a project is only a folder that chats happen to work in), puts a **project chat with spawned sessions** at the centre of the app, and adds **users** so several people can share one hub and one workspace. It replaces the short "Users, roles and visibility" notes in [plan.md](plan.md#users-roles-and-visibility).

## What is wanted

1. Several users on one hub, each with their own login and devices.
2. A **workspace** several users share, holding **projects**.
3. In each project, every user has **their own project chat**, and from it they **spawn sessions** (tasks on any device). The spawned sessions are listed under the project in the app's sidebar (on the phone, the matching list).
4. **One-off chats** (a quick question, no project) stay, but are clearly less important in the UI.

## Two steps, because the second is large

| Step | What | Needs users? |
|---|---|---|
| **A. Projects and project chats** | A project becomes an object; a chat belongs to a project or is a one-off; spawned sessions nest under their chat in the sidebar; one-offs move to a quiet section | No: it works for the one user you have |
| **B. Users and workspaces** | Users, invites, per-user devices and chats, membership and roles, who sees what | Yes |

A first, so the structure is right before people are added to it, and B only has to put an owner on objects that already exist.

## A. Projects and project chats

**A project** is `{id, name, workspace, folders, created}`. A project has one or more **folders**: a device and a path each (the same project on the laptop and on the GPU desktop). Today's folder-derived projects (see the sidebar since 0.18) become *unfiled folders*, with **Add to projects** turning one into a project, which is what the menu on a session card already offers.

**A project chat** is a chat with a project and an owner (the user, in step B). It is the conversation you work in. It leads: it **spawns sessions** on the project's devices (the lead and task mechanism that exists), and each spawned session shows under it with its device, state and last result. A project can have more than one chat per user (a new thread of work), each with its own spawned sessions.

**One-off chats** have no project. They are for quick questions and scratch work, which is the *Chats* list today.

**What the sidebar shows.**

```
 Tether                          «
 [ New chat ]
 ── Projects ───────────────────
 ▾ warehouse-sync
     ● Fix the upload failure        <- my project chat (live)
        ├ laptop   running tests     <- a spawned session
        └ minipc   done
     ○ Plan the v3 rollout
 ▸ tether
 ▸ resume
 ── Unfiled folders (3) ─────────   <- sessions in folders not yet projects
 ── One-offs ────────────────────   <- small, faint, collapsed past the newest 5
     What is a monad
```

- **Projects come first** and take the space. A project opens to its chats, and a chat opens to its spawned sessions. A needs-you or running marker rolls up to the project and the chat, so you see from the closed list that something wants you.
- **One-offs are last, smaller and fainter**, show the newest few, and the rest are behind *All chats*. They are not hidden: they have a clear place, just lower.
- **New chat** asks for a project (the last one used is preselected, with *No project* as the one-off option), so the structure fills itself.
- **Phone**: the drawer has the same order. The home screen's *Needs you* and *Running now* cards stay on top across all projects.
- **Spawned sessions are not top-level**: they do not appear in the One-offs list or as chats. You reach one from its project chat, or from Devices.

**Data.** Chats gain `project` (empty for a one-off); a project table is added; a chat's spawned sessions are already its linked sessions (role `started`), so no new link is needed. Folder-based grouping stays as the fallback for unfiled folders. The wire contract gets a `Project` message and `Chat.project`; older apps ignore both and show chats as they do now.

## B. Users and workspaces

**Users.** A user is `{id, name, role}`. The hub's owner is the first user and an admin. Others join by **invite**: the admin makes an invite code (as pairing codes work today), the person enters it in the app, and gets a user and a first device token. Every device and every token belongs to one user (the hub already stores devices; they gain `user`). The admin token stays for recovery and `tetherctl`. Later, Tailscale identity can map to a user so a person's own machines attach to their account (planned in [plan.md](plan.md)).

**Workspaces: personal and shared.** Every project lives in a workspace, and the person chooses which when they make a project (and, in the app, which one they are looking at):

| Workspace | Who | Holds |
|---|---|---|
| **Personal** | one user; made for each user when they join; private | their own projects, chats and files |
| **Shared** | a set of users with roles (`{id, name, members: [{user, role}]}`) | projects the members work on together |

A user can be in any number of shared workspaces. A single-user hub has only the personal one and needs no setup. The sidebar shows the current workspace at the top with a switcher; new chat and new project ask which workspace when the user belongs to more than one.

**Workspaces are synced by default.** Both kinds keep their projects' files on the hub and in step on the user's devices ([shared-workspace.md](shared-workspace.md)), so a new device a user adds to their account **imports the workspace** (all of it, or the projects they pick) and then keeps it up to date on its own. This replaces *make this chat remote*: a project in a workspace is already where its files are, and a chat can run on any of the user's devices with its folder in place.

**Roles, at the workspace and the project:**

| Role | Can |
|---|---|
| Admin | everything: users, invites, devices of the hub, deleting projects |
| Member | create projects, chat and spawn in projects they belong to, add their own devices |
| Viewer | read a project's chats the owner shared, no sending |

**Who sees what.** The rule is: *you see your own, and what is shared with you.*

- A **project chat is private to its user by default**. Another member of the project can be shown it (read, or collaborate) when its owner shares it. A project's members see each other's *project* and its spawned-session *list*, not each other's conversations, unless shared.
- **One-offs are private to their user.**
- **Files and the vault** (project files, `.env`) belong to the project: a member sees key names and gets values only on a device they allowed, as now, with the allowance recorded per user.
- **Skills and rules** have a scope of *me*, *the project* or *the workspace*; the workspace scope needs admin.
- **The audit log** records the user with every action.

**Devices and whose Claude account runs the work.** This is the part that needs care. A session runs on a device under that device's operating-system user and **that user's Claude login**. So:

- A device belongs to the user who paired it. Their sessions run there under their account.
- A device can be **lent** to a workspace or to named users. A lent device runs other people's sessions **under its owner's Claude account and machine**, so lending is an explicit, revocable choice with a warning that says exactly that, and every session shows whose device it ran on.
- A device that is not lent never receives another user's prompt, folder or file.
- A shared GPU desktop is the lend case. Its owner decides who may spawn on it.

**Enforcement.** One check, `can(user, action, object)`, used by every REST route, MCP call and WebSocket message, and **every list is filtered before it is sent**: `Welcome`, the chat list, sessions, approvals, notifications and the push stream carry only what the user may see. A user's agent connection reports only its own device. This is the largest part of B: today the hub trusts any client token with everything.

**MCP and the lead.** A session's MCP calls run as the user who owns its chat: `list_sessions` shows that user's sessions and the devices they can use; `start_session` can only target allowed devices; `list_rules` and `list_skills` are filtered by scope.

**Migration.** The existing data all gets the first user as its owner, in one migration. Older apps paired before users exist become that user's devices. Nothing changes for a one-user hub.

## Build order

0. **Home is clean.** The new-chat screen has no cards (no *Needs you*, *Running now*, no project chips): the greeting and the box. Needs-you and running show as markers in the sidebar instead. **Built.**
1. **A1.** Project object and a chat's project; *Add to projects* makes a project; the new-chat project picker. (Hub, app.) **Built**: the project is kept beside the chat in plain JSON routes rather than in the contract, so `Project` and `Chat.project` are not in the .proto ([chats.md](../architecture/chats.md#projects)).
2. **A2.** The sidebar and the phone drawer as above: projects with chats and spawned sessions nested, unfiled folders, quiet one-offs; roll-up of needs-you and running. **Built** ([app.md](../architecture/app.md#sidebar)).
3. **B1.** Users and invites; devices and chats get an owner; every list filtered by user; the `can` check; the audit log records the user.
4. **B2.** Workspaces and project membership; sharing a project chat; roles.
5. **B3.** Lending a device; scopes for rules and skills; a per-user view of usage and cost.
6. **B4.** Tailscale identity mapped to users.

## Tests

- **A:** a chat made in a project lists under it; its spawned sessions are under the chat and nowhere top-level; a one-off is in the one-off list and not in any project; a folder not made a project is unfiled; older-app frames still parse.
- **B:** two users on one hub (fake agents): neither sees the other's chats, sessions, approvals, files or notifications in any REST, MCP or socket output; a shared chat shows to the member it was shared with and no one else; a device that is not lent is never sent another user's start command; a lent one is, and the session shows whose device it was; a viewer cannot send; revoking a member or a lend takes effect on the open connection; the migration gives the first user everything.
- A fuzz-style test over every route: with no rights, each returns forbidden and no data.

## Decisions made

- **A project chat is private to its user, and can be shared** (read or collaborate).
- **Each user's sessions run on devices under their own Claude login.** No lending of one person's account to another. A shared pool of accounts and devices is a later feature, to be designed on its own: it needs a way to pool credentials and meter use, which this plan does not cover.
- **One workspace by default**, with several as an option later.
