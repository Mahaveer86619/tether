# Skills: learning routines from your work

Status: plan, nothing built. It is the "workflow learning" step of [plan.md](plan.md#order), worked out with a first look at how the owner actually uses Claude.

## The idea

Some tasks come back. "How far is the v2 sync?" has been asked in at least five sessions, and each time Claude rebuilt the same routine: find the tmux session, read the log, query per-machine counts, check the dashboard, report a table. Tether notices the repeat, writes the routine down once as a **skill**, and from then on Claude runs the skill instead of working it out. If a step breaks, Claude fixes the skill, and the next run is better.

A skill is a Claude Code skill: a folder with `SKILL.md` (a name, a description that says when to use it, the steps) and optional scripts. Claude Code already loads skills from `~/.claude/skills/` and a project's `.claude/skills/`, so there is no new runtime.

## What the first look at the owner's work shows

From the titles of about 70 sessions on both machines (a first pass; reading whole transcripts is part of the work below):

| Kind of task | Roughly | Repeats? |
|---|---|---|
| Warehouse image sync (`fk-ims-wvs`): sync status, prod readiness, LSP data, tunnels | 16 | Yes: "check v2 sync status" in at least 5 sessions |
| Uploads and billing data in `fk-cn`: CSV upload errors, filters returning no rows, incident inputs, UI tweaks | 9 | Yes: the same upload pipeline, different files |
| Network and access (`router-traffic-fw`, Tailscale, NAS, Cloudflare tunnels): adding hosts to advertise lists, reachability | 9 | Yes: "add this to the advertise list" |
| Tether itself, on both machines | 12 | Release and deploy routines |
| Personal projects: BMO hardware, Metrolist build and upstream sync, resume (LaTeX), Syncthing | 12 | Metrolist sync and the resume build |
| Machine chores: copying a file between laptop and mini PC, fonts, startup apps, moving data to a drive | 7 | File copy: 3 times |

The strongest candidates: **v2 sync progress**, **diagnose an upload failure**, **add a host to the advertise list**, **build and sync Metrolist upstream**, **copy a file laptop to mini PC**, **build the resume**.

The sync sessions show what a skill would hold. Each one ended up running the same things: the tmux session `wvs-v2` and its log, a per-machine table of rows waiting and why, rows handled out of 1,672,819, images saved, speed per hour, the dashboard on the mini PC, and a read-only dry run for batches v1 hasn't processed.

## How Tether would learn

1. **Collect.** The hub already keeps each chat's messages and every session's timeline. A job reads finished turns: your request, the tool calls (command lines, files touched), the result, whether you accepted it or corrected it, the device and folder.
2. **Fingerprint.** Reduce each task to a signature: the request as a bag of words and word pairs (the local hashing embedder already decided in [plan.md](plan.md)), plus the set of steps with the variable parts masked (paths, ids, dates, addresses become placeholders), plus the device and folder.
3. **Detect repeats.** Cluster by **what was asked**: two tasks are the same routine when their requests share enough words, and the steps they share (counted by how rare they are, so `grep` and `sed` count for little) add to that. A group with at least 3 runs in 2 or more sessions in the last 30 days, mostly without failures, becomes a candidate. Follow-ups ("yes start", "check again"), pasted reports, summaries and messages over 300 characters are not asks. A request copied into a fork or a moved chat counts once. One-off tasks never become candidates.
4. **Draft.** A session on the right device writes the skill from the successful runs: the parameters (what varied), the steps, the expected output shape, and what to check first. Read-only steps and mutating steps are labelled apart.
5. **Ask.** The app shows the suggestion: the name, what it does, the runs it came from, and a dry run. Approve, edit or dismiss. Read-only skills can be set to create themselves; anything that changes data always asks. (Default: ask, as in plan.md.)
6. **Keep and sync.** The hub stores the skill as the source of truth (artifact store, with versions). Agents copy it into `~/.claude/skills/<name>/` or the project's `.claude/skills/`, by scope: global, project or device.
7. **Use.** When a chat starts, the hub matches your words against the skills in scope and lists the matches in the lead's system prompt ("skill `v2-sync-progress` fits this"). Chat target detection and skills use the same folder signals, so a skill tied to `fk-ims-wvs` also helps pick that folder.
8. **Correct.** A hub MCP tool, `update_skill`, lets Claude fix a skill when a step fails or you correct it. Each change is a new version with a note on why. The app shows the diff and can roll back. A skill that fails twice in a row is flagged for review rather than quietly kept.

## What the first run on the real history showed

Step 2 is built (`skills.Cluster`, `GET /api/v1/skills/candidates`, and `tools/skillscan` for a copy of a hub database). Run on 74 sessions and 546 tasks, it changed the design:

- **Steps are not the same each time.** The first version clustered on the commands and found fifteen "routines" that were mostly unrelated work sharing `grep`, `sed` and `python`, plus follow-ups and pasted text. A real "progress?" is answered by `date`, a shell function, `curl` of the dashboard or a `tail`, differently each day. So the request decides, and the steps are evidence for the skill's draft, not the test for a routine.
- **The result is small and right.** With 3 runs in 2 sessions: one routine, "progress?", 5 runs in 3 sessions, whose shared step is the query of the dashboard's `/api/state`. At 2 runs a few more show: "install latest apps" (adb pairing then install), "save everything to memory", "run this on the mini PC in tmux".
- **Real history is noisier than the test corpus.** Forks copy history, so the same request appears in several sessions; shell helper functions and PowerShell variables made unusable step names (they now read as `shell`); some tasks run to 50 steps. The corpus now reflects these.

## Safety

- Skills hold no secrets: credentials stay in the machine's own config or the hub's sealed store, and the skill names where to read them.
- A skill runs through the session's normal permission mode. Mutating steps still ask unless you have allowed them.
- Nothing is learned from sessions marked private, and nothing leaves the hub.
- Skills are deleted by the clean-up in [uninstall.md](uninstall.md).

## Tests, with confidence

Real sessions are never touched by tests. The corpus is the owner's patterns rewritten as small synthetic transcripts (the sync-progress routine, an upload diagnosis, a file copy), plus tiny custom datasets made for Tether.

- **Parsing.** Golden transcripts in, expected task records out: request, masked tool sequence, outcome. Includes the known transcript quirks (queued commands, pasted images, list prompts) from [sessions.md](sessions.md).
- **Masking.** Property tests: the same routine with different paths, dates and ids gives one signature; different routines don't collide.
- **Clustering.** A labelled set with known clusters and known one-offs; the suite fails below a set precision and recall, and the numbers are printed.
- **Drafting.** A fake model, recorded and replayed, so tests are deterministic. Checks that the draft has the parameters, labels mutating steps, and contains no literal secrets from the input.
- **Correction.** A scripted failing step: `update_skill` makes a new version, rollback restores the old one, and two failures flag the skill.
- **End to end.** A temporary hub and agent, a scratch folder, a scripted "Claude" that repeats a task three times and then finds the skill.

## Build order

1. Task records from the existing history (collect and fingerprint), with the test corpus. No UI. **Built.**
2. Clustering and a read-only list of candidates in the app (Routines), to check against what the owner would want. **Built**; see what the first run showed, above.
3. Drafting, approval, storage and sync to agents.
4. Matching in chat start; `update_skill` and versions; the diff view.
5. Auto-create for read-only skills.

## Open questions

- How many repeats before a suggestion feels useful rather than noisy; start at 3 in 30 days and tune on real data.
- Whether a skill should be per project by default; the first examples are all tied to one folder.
- Where a skill that spans two machines lives (the file-copy routine uses both).
