# Usage tracking, scheduled work and the token pool

Status: partly built. Device sharing by the hour, booked slots and jobs queued for free time are in [jobs.md](../architecture/jobs.md); tracking, patterns, budgets and suggestions are still a plan. It builds on the usage data the hub already keeps, the usage-limit wait ([chats.md](../architecture/chats.md#tasks-and-the-usage-limit)), the users and workspaces in [teams.md](teams.md) and the deferred jobs of [shared-workspace.md](shared-workspace.md). Insights ([prompt-desk.md](prompt-desk.md#insights)) supplies the task-size estimates.

## What is wanted

1. **Track tokens and limits properly**: what each user, session and model spends, and where each user stands in the plan's **5-hour window**, the **day** and the **week**.
2. **Schedule work into the empty time**: learn when each person uses Tether, find the quiet frames, and run deferred jobs there, sized so they fit the budget that is left.
3. **Suggest it**: when a request looks long, offer to run it in the owner's free time instead of now.
4. **Shared devices**: a user shares a device (a GPU desktop) with another user for jobs in its free time, with a warning when the owner is likely to be using it then.

## 1. Tracking

**What exists.** The `usage` table keeps tokens per assistant message (input, output, cache read and write, model, time, session). The agent reads the plan's own limits with `claude -p /usage` (`server/internal/agent/plan.go`): lines like "Current week (all models): 9% used · resets Oct 18, 7:29pm". Nothing is kept over time, nothing is per user, and nothing predicts.

**What is added.**

| Data | Where it comes from | Kept as |
|---|---|---|
| Spend per message | `usage` (exists) | per user and per model, with a cost *estimate* from a price table, labelled as one |
| Plan limits over time | the agent's `/usage` read, every few minutes while a session works and hourly otherwise | `limit_samples`: account, window (`session5h`, `week`), percent used, resets-at, time read |
| Limit hits | the usage-limit detection (a session that stopped at "5-hour limit · resets 3:20am") | `limit_events`: account, window, reset time, session, time |
| Activity | message, approval and session events (the audit log and `chat_messages` times) | `activity`: user, hour of week, count, week number |

The percentages are the account's, as Claude reports them: Tether does not guess the plan's size. It learns the **cost of a percent** from the samples (tokens spent between two readings, over the percent that moved), per model family, which turns a task's token estimate into an estimate of percent of the window and of the week.

**Windows.** The 5-hour window starts at the first message after a reset and ends at the reset time the plan reports; the week resets at its own time. Both are read, not computed, so a changed rule on Anthropic's side shows up in the samples. A hub with several accounts (one per user) keeps each separately.

## 2. Patterns and free frames

**Pattern.** For each user, a table of 168 hour-of-week slots (in their time zone), each holding the share of recent weeks in which they were active in that slot, weighted toward recent weeks (an exponential average over about 6 weeks). *Active* is any message, approval or interactive session event in the slot. The result is a probability per slot, `P(active)`.

**Free frame.** A run of slots where `P(active)` is low (default under 15%), at least an hour long, with a plan window that has room. Frames are shown to the owner on a week grid (the *Schedule* page), with the odds.

**Honesty about the data.** With less than 3 weeks of activity there is no pattern: the page says so, uses only the hours the owner marks as free by hand, and starts guessing when there is data. Every prediction shows its basis (weeks observed).

## 3. The budget, and what runs when

A deferred job has: a prompt, a device and folder, an **estimate** (percent of a window and of the week, from similar past tasks and a margin), a **priority**, an optional **deadline**, and the account it runs on.

The scheduler runs when a frame is open and **all** of these hold:

1. **5-hour window**: the percent left in the current window covers the estimate **plus a reserve** for the owner's expected use in the rest of that window (their `P(active)` times their usual spend per active hour).
2. **Day**: the day's share is not used up. The share is the week's remaining percent split over the days left, weighted by how much the owner normally uses each day, with a floor so a quiet day still allows small jobs.
3. **Week**: the percent left in the week covers the estimate plus the reserve for the owner's expected use for the rest of the week (and never takes the last 10%, a floor the owner can change).
4. **The owner is away**: nothing started in the last N minutes (default 20), no open approval, and the slot is a free frame. If the owner comes back, the job is paused at the next safe point (it finishes its step, then waits) and resumes in the next frame.

When the limit is hit anyway, the job waits for the reset and carries on by itself (already built for tasks). A job that does not fit any frame before its deadline is shown with the reason and the choice to run it now.

**Suggesting.** When a request is sent, the hub estimates it (prompt size, the project's past tasks, words like "refactor all", "migrate", "run the full suite", a number of repos). If the estimate is above a threshold (default 25% of a window), or the window is short, the app asks before sending: *This looks long, about 35% of your window. Run it tonight, 1 to 5 am, when you are usually away? [Schedule] [Run now]*. The answer and whether the estimate was right are kept to tune the next one.

## 4. Shared devices (the pool)

**What is shared is a device's time, not anyone's Claude account.** A user can share a device with other users **for jobs**: servers, training runs, long scripts. The first case: a user with a GPU desktop on the tailnet shares it with the hub's owner, who trains models on it in its free time. A job is an ordinary process on that device (see [shared-workspace.md](shared-workspace.md#jobs)); it needs no Claude login, so nothing of the device owner's Claude plan is used and nothing about the plan's terms is touched. A Claude session on a shared device runs under **that device owner's own Claude Code**, and only when the owner has granted full access ([teams.md](teams.md#b-users-and-workspaces)); a jobs-only grant never starts one.

**Sharing.** The device owner shares a device with a user, with limits they set: jobs only; which hours (a window, or *only when I am away*); the most GPU memory, CPU and disk a job may use; which folders it may write to. The owner can pause or stop any job on their device at any moment, and sees every job with who started it.

**"Free time" for a device** is measured, not guessed from a calendar: the device's own state (the owner's recent input, whether a game or another heavy process is using the GPU, GPU and CPU load) together with the owner's learned pattern (section 2). A shared device offers a free frame when the owner is predicted away *and* the device is idle now. The *Schedule* page shows the week grid for each shared device, with the odds.

**Flow.**

1. A user queues a job for a shared device, with an estimate of how long and how much GPU memory (or none, and the job is measured on its first minutes).
2. The scheduler starts it in a free frame, and **pauses** it (SIGSTOP, or suspend on Windows) when the owner comes back or the device is no longer idle, and resumes it in the next frame. A job that can checkpoint is asked to, and is stopped and started again from its checkpoint; one that cannot is paused in place, which holds its GPU memory (the app says so, and the owner can choose *stop instead*).
3. The owner is warned before a booking that overlaps their likely use: *You are usually at this machine in this frame (62%, from 5 weeks). A job will be paused when you return.* The booking needs the owner's agreement unless they have approved that user's jobs in advance.
4. Both sides see the job's state, log and use of the device.

**What was dropped.** Offering a slot of one person's Claude allowance to another would run one person's work on another person's logged-in account. Plans are issued to a person and the terms may not allow sharing, so this is not built. What stays from that idea is the part about a person's own limits: tracking, patterns and scheduling their own deferred work (sections 1 to 3).

## Build order

1. **Tracking**: `limit_samples`, `limit_events`, `activity`; per-user and per-model spend; a Usage page with the 5-hour, day and week bars and the cost of a percent.
2. **Patterns**: the 168-slot probability, the free-frame finder, the Schedule page with the week grid, hand-marked free hours. (Needs a few weeks of data, collected from step 1 on.)
3. **Deferred jobs and the budget**: queue a task for later, estimates, the four conditions, pause when the owner returns, resume in the next frame.
4. **Suggest**: the estimate on send, the ask, the feedback loop.
5. **Multi-user** ([teams.md](teams.md) step B): users; devices that belong to a user; a device shared with another user for jobs.
6. **Shared devices**: the sharing limits, free frames from the device's own state, pause and resume around the owner, checkpoints, the booking and the warning.

## Tests

Time is injected, never the wall clock; no real account is read.

- **Samples**: a recorded series of `/usage` outputs gives the right percent, reset time and cost-of-a-percent; a changed output format is ignored, not misread.
- **Patterns**: a synthetic six weeks (a person active 9 to 6 on weekdays) gives high `P` in those slots and low at night; with two weeks it says there is not enough data.
- **Budget**: with known percents left, a known pattern and a known estimate, the scheduler runs a job in exactly the expected frame and refuses the others, for each of the four conditions in turn.
- **Away**: activity during a run pauses it at the step boundary and resumes it in the next frame.
- **Shared devices**: a job on a device shared for jobs only never starts a Claude session, and a session on a fully shared device is charged to the device owner's usage; a job outside the shared hours or over its memory limit is refused; the owner's return pauses the job at the next check and a resume follows in the next free frame; the warning percentage equals the owner's `P` for the frame; an owner's stop ends the job and its children.
- **Estimate**: past tasks of known size give an estimate within the stated margin; the threshold decides when the app asks.

## Decisions to make

- **Defaults**: the "free" threshold (15%), the away time (20 minutes), the reserve floor (10% of the week), the ask threshold (25% of a window).
- **Whether the scheduler may start a job without asking** once the owner has approved the kind of job, or always asks per job.
