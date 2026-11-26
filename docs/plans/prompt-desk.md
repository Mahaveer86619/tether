# The prompt desk: rewind, rules, script skills, insights

Status: plan. Built slices are marked in [Build order](#build-order). It is the work between "Claude answers my message" and "Claude has what it needs to answer well": what happens to a message before it is sent, what Claude is always told, what it can run, and what Tether learns from how it is used.

## The five parts

| Part | In one line |
|---|---|
| [Rewind](#rewind-and-the-recap) | Restart a chat from an earlier prompt (the 3rd from last, say) and be reminded where it stood |
| [Rules](#rules) | Saved standing instructions ("no code comments", "keep docs/ current") applied to every session they cover |
| [Skills, found and run](#skills-found-and-run) | Search the library, ask for a task by skill, and keep scripts (a prod-database check, say) as skills |
| [Insights](#insights) | Analysis of what Tether has saved, on demand from the app, that recommends rules, skills and context fixes |
| [Context](#context-management) | Changes to how a chat's context is kept and carried, led by what Insights shows |

The shared workspace and long-running jobs are a separate plan: [shared-workspace.md](shared-workspace.md).

## Rewind and the recap

**The need.** A conversation goes wrong at prompt *n*. Today the choices are to correct it in place (the wrong turns stay in the context), or to start a new chat and paste. The wanted move: go back to the prompt before it went wrong and carry on from there.

**Rewind.** On any of the user's messages in a chat: *Rewind to before this*. The hub starts a new session in the same chat, with the conversation up to that message and the message itself put back in the composer to edit. Two ways to carry the conversation, chosen by where the chat runs:

1. **Fork at a point** (same device, Claude Code transcript available): copy the transcript up to that user turn into a new session id and resume it. Exact: Claude sees what it saw then. Uses the fork machinery that exists (`fork_point`, `lineage`), with the cut made at a turn.
2. **Carry as text** (any device): the chat's saved messages up to that point, trimmed to the same limit as *Moving* in [chats.md](../architecture/chats.md#moving), as the first message of a new session. Works where the transcript is not.

The old session stays, linked as `rewound`, so nothing is lost and the app can show "rewound from prompt 12". Quick choices: the last prompt, 2 back, 3 back (the *n-3* case), or pick any message.

**The recap.** When a chat is opened after a gap (default: a day), the app shows a short card above the composer: what was asked last, what was done, what is open, from the chat's own notes. It comes from a post-processing job (`chatJobs`) that writes a `recap` note when a turn ends, using the local summary approach, not a model call, unless Insights is switched to use one. A recap is also offered when you pick a rewind point, so the prompt's context is visible before you go back.

**Before sending (the prompt step).** An optional step between the composer and the session, off by default, per chat:

- **Remind**: the recap and the rules that apply, shown as chips under the composer (nothing sent to a model).
- **Sharpen**: the hub asks a short headless session to rewrite the message (clearer, with the project's names filled in from the chat). The app shows the original and the rewrite side by side; the user sends either. Never sent without being seen.

## Rules

**The need.** Instructions repeated in many chats: never write comments in the code, keep `docs/` current, commit locally and never push, match the file's style. Today they live in a global `CLAUDE.md` on one machine or in memory.

**What a rule is.** A short text with a name, a scope and an on/off switch:

| Scope | Applies to |
|---|---|
| Everywhere | every Tether chat, on every device |
| A device | sessions on that device |
| A project | sessions in that folder (by device and folder, as projects are listed) |

A rule is plain text, kept on the hub (`kv`, one value per rule, with versions). Rules are for how Claude works; credentials never go in a rule.

**How Claude gets them.** Through the system prompt the hub already builds (`chatPromptWith`), as a *Standing rules* paragraph after the lead prompt, for the lead and for the workers it starts. It needs no new `systemPromptVersion`: any agent that gets the lead prompt gets the rules with it. Claude also gets `list_rules` over the hub's MCP, so a long chat can re-read them. For a project, the hub can also write the project's rules into the folder's `.claude/` rules (opt in, per project) so they hold in a terminal session outside Tether.

**Authoring.** The app's Rules page: add, edit, scope, switch off, see which chats a rule reached. Rules are also **suggested**: Insights finds instructions the user keeps repeating (counted across chats) and offers them as a one-tap rule. Nothing is switched on without approval.

**Conflicts.** A project rule beats a device rule beats an everywhere rule. Contradictory rules are shown to the user rather than resolved silently.

## Skills, found and run

**Status: built** (search, ask by skill, script skills, the Save as skill brief and endpoint); the app's *Save as skill* button on a tool call is still to do.

Builds on [skills.md](skills.md): the library, the router (`skills.Rank`), `list_skills`, `read_skill`, `propose_skill`, `update_skill` and the lead's prompt listing the skills that fit the request exist.

**Search.** `GET /api/v1/skills/search?q=` ranks the approved skills (`skills.Search`: the router's word weights with a lower bar, and the last word may be unfinished) and returns name, description, score and a reason (the shared words, weightiest first). A search box on the Skills page shows the results live. The lead's prompt lists the best matches for the request, as now.

**Ask by skill.** In the composer, `/` opens the skill list, filtered as you type; picking one shows it as a chip. The message goes as typed, with a plain `skill` field beside it on `POST /api/v1/chats`, `/chats/{id}/messages` and `/sessions/{id}/messages` (not in the proto). For that turn the hub adds to the system prompt: *Use the skill "<name>" (version N) exactly to do: <request>*, then the skill's text at that version and, for a script skill, how to run it. An agent too old for a system prompt gets it at the head of the message.

**Scripts as skills.** A skill can carry **scripts**: a skill is a folder (`SKILL.md` plus `scripts/`). The case: a database check against production with a custom script, whose credentials sit in the project's environment, as in the owner's warehouse project. Rules for these:

- The script is saved **in the codebase** (the skill says where, usually `scripts/` or `.tether/skills/<name>/`), and travels with the project, including to a device the project is moved to ([shared-workspace.md](shared-workspace.md)). The library holds the skill's text and a hash of each script, so a change to a script is noticed and the skill is flagged for review.
- It declares what it needs: `needs_env: [DB_URL]`, `runs_on: <device or any>`, `effect: read | write`. Credentials are **never** in the skill or the script. They come from the project's `.env` (the sealed project files the hub already serves to allowed devices) or the device's own environment.
- Running one goes through the session's normal permissions. `effect: write` always asks. A read-only script against production is shown, with its target, before it first runs on a device.
- Making one: *Save as skill* on a tool call or a stretch of a chat. The hub starts a drafting session with the commands used, the script is written into the project, and the skill is proposed for approval, as in [skills.md](skills.md).

**How it is built.** Front matter: `needs_env: [DB_URL]` (names only; a value is refused), `runs_on: <device|any>`, `effect: read|write` (required with scripts; `write` makes the skill mutating) and `scripts: [paths relative to the project]` (inline or as `- item` lines). `propose_skill` and `update_skill` take `scripts: {path: contents}`; each script is checked for secrets (including `DB_PASSWORD=...` style assignments, but not values read from the environment) and its sha256 kept. A text-only correction keeps the hashes. `read_skill` appends what Tether requires: the scripts' paths, to call `check_skill_scripts` with their hashes before the first run, where the variables come from, `effect: write` asks every time, and a read-only run against production is shown with its target first. `check_skill_scripts` (or an `update_skill` that changes a script of an approved skill) puts the new hash in `changed`: the skill shows *script changed: review* in the app, and approving it again accepts the scripts as they are. `POST /api/v1/skills/draft {"session", "item"}` drafts from the task around that item; a routine that runs a database or service client (`psql`, `mysql`, `kubectl`, `python`, ...) is drafted in its project, told to write the script under `.tether/skills/<name>/` or `scripts/`, read credentials from the environment and never write a `.env`.

## Insights

**The need.** Improvements should come from how Tether is used, not guesses. What the hub saves (chats and messages, tool calls, approvals, usage, sessions, lineage) can answer: where chats restart, which instructions repeat, how long contexts get, which routines recur, where approvals are denied.

**What exists.** `skills.Cluster` and `tools/skillscan` find repeated routines; usage and history are stored. There is no single place that reads it all, and nothing the app can trigger.

**Two layers.**

1. **Measure** (no model, instant): `GET /api/v1/insights/stats?days=` returns counts and distributions from the hub's data: chats and messages per chat, prompt lengths, restarts and forks, rewinds when they exist, repeated instructions, context size per session, approvals and denials, tool use, cost. Deterministic and tested.
2. **Interpret** (a model, on demand): *Analyze* in the app (`POST /api/v1/insights/analyze`) starts a hub session with the stats and a bounded sample of masked messages, and a brief: say what is wrong or wasteful and recommend rules, skills and context changes. The session saves a report with the `save_insight` MCP tool; each recommendation is an item with a one-tap action (*Add rule*, *Draft skill*, *Open chat*). It runs only when the user taps it, on the connected account, and never sends more than the masked sample.

**Privacy.** Messages are masked before they go to a model: secrets as in the history redaction, then emails, URLs, paths, host names and the user's device names, then what the skills collector masks (ids, addresses, dates, hashes, numbers). Chats have no private flag yet, so none can be skipped; the brief says so. The sample size is shown before the run.

**How it is built.** `server/internal/hub/insights.go` loads the data (chat messages in the window with fork copies dropped, lineage, usage, tool cards decoded from `items`, approval entries from `audit`) and `computeInsights` turns it into numbers; it is a pure function, pinned by a synthetic store in `insights_test.go`. Distributions are nearest-rank (a median or p90 is a value that occurs). A **restart** is a prompt of three words or more whose word set is at least 60% the same (Jaccard) as one of the 8 prompts before it in the chat; a **repeated prompt** is one said word for word earlier in the chat. **Repeated instructions** are counted against a built-in list of rule-like phrases, each carrying the rule it would become. **Cost** is an estimate from list prices per model family (`prices`), labelled as such; models without a price are counted as unpriced. `insights_report.go` holds the interpret layer: the sample (the 50 most recently active chats, the latest 20 messages of each, clipped to 800 characters), the masking, the brief (its first line sends the session to `tether_guide` topic `data`), the reports in `kv` under `insights` (the newest 20), and `save_insight`. A recommended skill is drafted by `POST /api/v1/skills/draft` with an `idea`, which writes a skill from the text rather than from a routine in the history.

## Context management

Directions from the first real data (see [What the data says](#what-the-data-says), filled in from the analysis run):

- **Show the cost of a chat**: a context meter on the chat (estimated tokens of what a resume would carry), so growth is visible before it hurts.
- **Carry a summary, not everything**: *Move* and *Continue* trim by characters (40,000). Prefer the recap plus the last turns, with the full text one tap away.
- **Rewind** (above) as the answer to "this went wrong".
- **Forks and moves** keep one chat: the link roles say how a session joined, the recap follows the active one.
- **Decisions survive**: decisions and facts stated in a chat go to the second brain ([second-brain-rust.md](second-brain-rust.md)) with approval, so a new session can recall them instead of replaying the chat.

## What the data says

A read-only analysis of the hub's saved data (13 chats, 1,833 messages, about 31 days to 2026-11-25), run from a session on the hub's machine. The numbers that shape the plan:

| Finding | Number | What it means |
|---|---|---|
| Chats are long | median 78 messages, p90 462, max 495; 23 prompts per chat at the median | Context grows; a way to see and manage it matters |
| Chats span sessions | 8 of 13 chats have more than one session; 7 moves, 1 continue, 1 fork | The chat, not the session, is the unit; carrying context well is the common case |
| The heaviest sessions are huge | 400 to 1,700 turns, 100 to 800 million cache-read tokens; 6 auto-summary continuations | Hand off before the context runs out, with a structured summary |
| Cost is almost all cache reads | 98% of input-side tokens | Long contexts are the cost; shorter fresh sessions with a good summary cost much less |
| Rewinds are small | of 531 prompts, 15 repeat one of the 8 before; 7 of them 1 back, 3 two, 3 three, 2 five | A rewind of 1 to 5 prompts is the real need; it is occasional, so it must be cheap, not central |
| Corrections are rare | 6 prompts start with a correction word | The user corrects forward more than back |
| Long input is routine | 49 "message is long, it is in the attached file" prompts in 26 sessions | The long-message path deserves to be first class |
| Rules are stated ad hoc | the most repeated: do not commit or push unless asked (about 60), logs first (19), docs with the change (18), short answers (16), read-only tasks (14), verify before done (14), never restart a service (11) | Standing rules would remove the repetition; code comments came up only twice |
| Few skills so far | 1 active, 1 proposed | Candidates are mostly status and handoff routines |
| Not stored | approve and deny decisions, cost in money, a clear archived flag | Insights needs the approval decision and a price table to answer those |

**Changes this makes to the plan.**

- Rewind stays, sized for 1 to 5 prompts back, with *edit the last prompt* as its most common form.
- A **handoff** is added to context management and moved up: at a size threshold offer *continue in a fresh session with a summary* (goal, decisions, open items, files). It is the biggest cost lever in the data.
- The first rules to offer are the ones above, as suggestions the user approves (not switched on for them).
- Insights must record approval decisions and a cost estimate, so they are measurable next time.
- The `archived` field of a chat needs a clear meaning in the app before it can be analysed.

## Build order

0. **The guide**: `tether_guide` over the hub's MCP (parts, data tables, state, tools) and a line in every chat session's prompt pointing at it, so a session knows how Tether works before it analyses or changes it. **Built.**
1. **Rules**: store, `list_rules`, prompt injection, and the Rules page in the app with suggested starters. **Built.**
2. **Insights, measure**: the stats endpoint and the Insights page; approval decisions are now audited (`audit` kind `approval`) and cost is estimated from a price table. **Built.**
3. **Rewind and the recap**: the `rewound` link, rewind by text then by transcript fork, the recap note and card. **Built**, except the transcript fork (rewinds carry as text; see [chats.md](../architecture/chats.md#rewind)).
4. **Skills: search, `/` picker, run by name.**
5. **Insights, interpret**: Analyze, saved reports (`save_insight`, `GET /api/v1/insights`), one-tap actions (*Add rule* off by default, *Draft skill*, copy a context change), suggested rules. **Built** (moved ahead of 3 and 4).
6. **Script skills**: scripts in the codebase, needs and effects, drafting from a chat.
7. **The prompt step**: remind and sharpen. **Remind built**; Sharpen is next (`POST /chats/{id}/sharpen`, a short hub session, original and rewrite side by side).
8. **Context**: the handoff at a size threshold, the meter, summary carry, decisions into the second brain. **The meter and the handoff are built** (summary by rules); summary carry for moves and decisions into the second brain are next. (The handoff is worth doing before 7: it is the biggest saving in the data.)

## Tests

Real sessions are never touched. A temporary hub with fake agents (as in `remote_test.go`):

- **Rules**: scoping (everywhere, device, project) and precedence; a rule appears in the prompt only for sessions it covers; switching one off removes it; an agent older than the prompt version still starts a session.
- **Rewind**: a chat with ten prompts rewound to the third from last starts a session whose context ends at that prompt, links the old one, and puts the prompt back; both carry paths give the same conversation.
- **Stats**: a synthetic database with known numbers gives exactly those numbers.
- **Skills search**: a labelled set of requests and skills; the expected skill is in the top three.
- **Scripts**: a changed script flags its skill; a skill with `needs_env` refuses to run when the variable is missing; no value from `.env` appears in a skill, a report or the prompt.

## Open questions

- Whether Sharpen is worth a model call per message, or only on request. Start on request.
- Whether rules for a project are written into the folder (visible, works in a terminal) or only sent by Tether (clean repo). Start with sent by Tether, with the opt-in write.
- How much of Insights' sample is enough; start small (50 chats, 20 messages each) and see what it finds.
