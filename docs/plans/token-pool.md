# Usage tracking, scheduled work and the token pool

Status: plan. It builds on the usage data the hub already keeps, the usage-limit wait ([chats.md](../architecture/chats.md#tasks-and-the-usage-limit)), the users and workspaces in [teams.md](teams.md) and the deferred jobs of [shared-workspace.md](shared-workspace.md). Insights ([prompt-desk.md](prompt-desk.md#insights)) supplies the task-size estimates.

## What is wanted

1. **Track tokens and limits properly**: what each user, session and model spends, and where each user stands in the plan's **5-hour window**, the **day** and the **week**.
2. **Schedule work into the empty time**: learn when each person uses Tether, find the quiet frames, and run deferred jobs there, sized so they fit the budget that is left.
3. **Suggest it**: when a request looks long, offer to run it in the owner's free time instead of now.
4. **A pool**: a quiet frame of one person's allowance can be offered to, and booked by, another user, if both agree, with a warning when the giver is likely to be using Tether then.

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

## 4. The pool

**Idea.** A quiet frame of someone's allowance is a thing that can be given or lent. User B asks for it, or A offers it; both confirm; the job then runs in that frame.

**Flow.**

1. A marks a frame as **offered** (a time range and a size, as percent of a window), or B **requests** one from A.
2. The other side sees the offer: the frame, the size, and a warning computed from A's pattern: *Alex is usually active in this frame (62%). Their own work may be slowed or stopped.* The percentage is the model's, with the weeks it is based on.
3. Both accept. A can withdraw before it starts, and can **recall** it at any moment (the job stops at a safe point).
4. The job runs on the frame's account, and the cost is booked to the frame: spent percent is shown to both.

**Who runs the work.** A job booked into A's frame runs **under A's account on A's devices** (see [teams.md](teams.md#decisions-made)), never on B's, and B's prompt and folder reach A's device only if A allowed it for that project. A sees everything run in their name.

**A risk to settle before building.** Claude's plans are issued to a person. Running someone else's work on a person's logged-in Claude account is account sharing, which the plan's terms may not allow, and may be detected as abuse. Check Anthropic's current consumer and commercial terms before building this part. The safe forms are: a pool among **one person's own accounts** (a work and a personal one), among accounts of **an organization that permits it**, or on **API keys** with their own budget. The design above works for any of them; which one is offered must follow what the terms allow.

## Build order

1. **Tracking**: `limit_samples`, `limit_events`, `activity`; per-user and per-model spend; a Usage page with the 5-hour, day and week bars and the cost of a percent.
2. **Patterns**: the 168-slot probability, the free-frame finder, the Schedule page with the week grid, hand-marked free hours. (Needs a few weeks of data, collected from step 1 on.)
3. **Deferred jobs and the budget**: queue a task for later, estimates, the four conditions, pause when the owner returns, resume in the next frame.
4. **Suggest**: the estimate on send, the ask, the feedback loop.
5. **Multi-user** ([teams.md](teams.md) step B): users and accounts per user.
6. **The pool**: offers, requests, the warning, recall; only after the terms are checked.

## Tests

Time is injected, never the wall clock; no real account is read.

- **Samples**: a recorded series of `/usage` outputs gives the right percent, reset time and cost-of-a-percent; a changed output format is ignored, not misread.
- **Patterns**: a synthetic six weeks (a person active 9 to 6 on weekdays) gives high `P` in those slots and low at night; with two weeks it says there is not enough data.
- **Budget**: with known percents left, a known pattern and a known estimate, the scheduler runs a job in exactly the expected frame and refuses the others, for each of the four conditions in turn.
- **Away**: activity during a run pauses it at the step boundary and resumes it in the next frame.
- **Pool**: an offer's warning percentage equals the giver's `P` for the frame; a recall stops the job; a job in A's frame never starts on B's device.
- **Estimate**: past tasks of known size give an estimate within the stated margin; the threshold decides when the app asks.

## Decisions to make

- **The terms for the pool** (above): which form is allowed to be offered.
- **Defaults**: the "free" threshold (15%), the away time (20 minutes), the reserve floor (10% of the week), the ask threshold (25% of a window).
- **Whether the scheduler may start a job without asking** once the owner has approved the kind of job, or always asks per job.
