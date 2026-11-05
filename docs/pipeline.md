# Pipeline

What is left to build, in the order that makes sense, so the next development can be planned. [features.md](features.md) says where every feature stands; this page says what to do next and what each step depends on. Sizes: **S** is under a day, **M** a few days, **L** about a week or more, **XL** several weeks or needs its own design first.

## While the design team works

[v1-spec.md](v1-spec.md) is the document for the design team. Their work is the screens; the engine underneath each feature does not wait for them. These can be built now with no UI decisions, in this order, and each ends with something the design can rely on:

| Order | Item | Why now | Doc |
|---|---|---|---|
| a | ~~Hub posts a finished task's result into its chat (5)~~ Done: a note per finished turn; the rich card waits for the design | The chat's result cards need it | [chats.md](chats.md) |
| b | ~~The drop folder and the chat's artifacts endpoint~~ Done; `present_file` and result items remain (new) | Deliverables need it; the file card and Files panel are drawn against it | [deliverables.md](deliverables.md) |
| c | Node capabilities (done: tools and the Android SDK, in the node status and the lead's prompt); the agent's doctor remains (new) | The checklist screen, Auto picking the machine that can build | [first-run.md](first-run.md) |
| d | ~~The skill router~~ Done for a chat's first request (top three that fit, a pointer to the rest); usage recording and outcomes remain (8) | "Used skill X" and a prompt that stays small | [agent-tools.md](agent-tools.md#3-choosing-skills-well) |
| e | Notification rules, preferences and the `Notify` frame on the hub (new) | Every notification screen and setting | [notifications.md](notifications.md) |
| f | The audit log (done for tool calls and skill decisions); scoped MCP credentials and rate limits remain (new) | Security for 1.0; the audit log has a screen | [agent-tools.md](agent-tools.md#4-security) |
| g | Terminal output with colour, then streaming frames (new) | Terminal mode | [terminal-mode.md](terminal-mode.md) |
| h | Wipe orders and per-scope deletion on the hub (15) | The remove-data screen | [uninstall.md](uninstall.md) |
| i | The hub installer (new) | First run | [first-run.md](first-run.md) |

Anything needing the phone or a screen (run card, history views, terminal widget, Android notifications) waits for the designs.

## 1. Finish what is half done (do these first)

| # | Item | Size | What is missing | Depends on |
|---|---|---|---|---|
| 1 | **Merge and release what is built** | S | Merge the open PRs; cut 0.17.1 with `deploy.sh` (the hub on the mini PC is a hand-built 0.17.0); push the `v0.17.0` tag | Your merge |
| 2 | **Switch CI on** | M | The GitHub setup ([GITHUB-SETUP.md](GITHUB-SETUP.md)): runner on the mini PC, signing secrets, branch protection, the `minipc` environment. Then a tag builds and deploys | 1, your GitHub access |
| 3 | **Start-a-chat with files in the background** | S | The Home box still uploads in the foreground; the session composer already does it in the background | |
| 4 | **Run card** | M | The card for a working session or task, from your video ([ui-overhaul.md](ui-overhaul.md#run-card)) | |
| 5 | **Hub posts a task's result into its chat** | M | Today the lead only reports what it chooses to read with `wait_for_session`; the hub should add "Task finished: ..." to the chat when a started session ends a turn | |
| 6 | **Follow a remote session live in its chat, and message it** | M | A linked session's timeline streams into the chat; a message can go to it from there | 4 |
| 7 | **History views in the app** | M | The hub keeps all history and exports it; the app has no screen for a chat's combined history, search or "synced up to" | |
| 8 | **Skills, the unfinished parts** | M | Run a real draft and look at what comes out; match a skill to a new request; copy approved skills into `~/.claude/skills`; auto-create read-only skills | Real use of 1-3 steps already built |
| 9 | ~~Confirm Tailscale on the phone~~ | Done | The Android connect intent works: Tailscale turns on by itself when Tether needs the hub | |
| 10 | **Loose ends** | S | The phone flapping seen on 2 Nov (unexplained); "backup import points at a missing artifact file"; messages before 0.17.x have no file link; remove `new_session/` | |

## 2. Before 1.0

| # | Item | Size | Notes |
|---|---|---|---|
| 11 | **UI overhaul, shared parts** | L | Type scale, spacing tokens, one Pill/Card/Banner/Sheet/Empty/Error, the step bar ([ui-overhaul.md](ui-overhaul.md#shared-parts-to-settle-first)) |
| 12 | **UI overhaul, screen by screen** | XL | Fifteen screens, one pass each, with you looking at each one ([ui-overhaul.md](ui-overhaul.md#screens)) |
| 13 | **Previews in the chat** | L | File card with download, image, text, code, CSV table, audio and video; result card at the end of a turn ([previews-and-guides.md](previews-and-guides.md#previews-in-the-chat)). Build on 11 |
| 14 | **Interactive guides** | L | Page card in the chat, `present_page`, the shared kit, versions, an in-app viewer ([previews-and-guides.md](previews-and-guides.md#interactive-guides)). Uses the existing generated pages; the page card needs 11 |
| 15 | **Remove data, or Tether** | L | Wipe orders that reach every device, even offline ones, per scope ([uninstall.md](uninstall.md)) |
| 16 | **Other LLM providers** | XL | The Claude CLI, your own API keys and base URLs, local servers, custom CLI agents; keys encrypted on the hub; a settings screen. Needs a design doc first (what a "session" means for a provider with no CLI) |
| 17 | **Notifications** | L | Needs you, finished, ready, something wrong; reaching a sleeping phone is the hard part. Only update and download notifications exist today ([notifications.md](notifications.md)) |
| 18 | **First-run and setup** | L | The doctor, the hub installer, a guided flow that assumes nothing about the author's machine ([first-run.md](first-run.md)) |
| 18a | **Terminal mode** | L | The assistant's own interface live beside chat mode, with a key row on the phone ([terminal-mode.md](terminal-mode.md)) |
| 18b | **Deliverables** | L | Ask for a build or an export and get the file in the chat with Download and Install ([deliverables.md](deliverables.md)) |
| 18c | **Skill choice, the engine contract and security for 1.0** | L | ([agent-tools.md](agent-tools.md)) |
| 19 | **Hardening for other people's setups** | M | Windows and Linux paths and permissions, a hub without Docker, the agent on a Mac, upgrade paths from every 0.x |

## 3. After 1.0

| # | Item | Size | Notes |
|---|---|---|---|
| 20 | **Branch and merge** (the replacement for `/btw`) | L | [plan.md](plan.md#fork-branch-and-merge); forks exist, merging a branch's findings back does not |
| 21 | **Second brain** | XL | Memories with scope, a graph, local light embeddings, `memory.md` and a recall tool ([plan.md](plan.md#second-brain-on-the-mini-pc)). Skills feed it |
| 22 | **Automations from webhooks and schedules** | L | A trigger asks you, then runs a skill on a node ([roadmap.md](roadmap.md#m5-hub-chat-skills-and-automations)). Needs skills (8) |
| 23 | **Users, roles and sharing** | XL | One hub, several people, per-node and per-service grants ([plan.md](plan.md#users-roles-and-visibility)) |
| 24 | **Adapters for other agents** | XL | Behind the same contract; overlaps with 16 |
| 25 | **Custom dashboard sections** | L | Generated by Claude, rendered as server-driven UI; overlaps with interactive guides |
| 26 | **Usage and cost analytics** | M | Per node and project over time |

## Ideas (a sentence each, nothing designed)

- A button inside a guide that sends a message into the chat.
- A guide that exports itself as PDF or PNG.
- A page thumbnail and a first-page thumbnail for PDFs in the chat.
- Voice input for a new chat on the phone.
- A "what changed since I last looked" digest on Home.
- Pairing a second phone by showing a QR from the first.

## Decisions I need from you

1. **Order of 3-7.** Run card first (it is what the UI overhaul and the Tasks strip both need), or live-following first (what makes the lead feel real)?
2. **Phone web view.** For interactive guides, is the phone's browser enough, or should guides open inside the app?
3. **LLM providers.** Is this before 1.0, or after? It is the largest unknown on the list.
4. **Notifications.** Do they work today, or are they missing? I have not checked.
5. **1.0 means what?** The sections above assume "the author's setup works well and a second person could install it". If 1.0 means more (other people using one hub), items 23 and 19 move up.
