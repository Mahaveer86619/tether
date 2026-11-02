# Chats

The app talks in chats, like a chatbot. A chat is what the user sees: a title, a stream of messages and a composer. The work happens in Claude Code sessions behind it, which the user never has to name. Chats live on the hub (0.16 and later), so every app sees the same ones.

## Chats and sessions

A chat has one **active** session, where messages go, and any number of **linked** ones. Each link has a role:

| Role | When |
|---|---|
| `main` | The session the chat started with, or the one a chat was made from |
| `moved` | The chat carried on in another place (see [Moving](#moving)), or its active session was gone when a message came |
| `fork` | A session split off from one in the chat: a fork, or a continue on the hub. Splitting off the active session makes the new one active. |
| `started` | Claude started it with the hub's MCP `start_session` and passed `chat` |
| `linked` | Added by hand (`POST /chats/{id}/links`) |

A session is in at most one chat. Linking it to another moves it.

The session the user talks to **leads** the chat. Its system prompt lists the machines online when the message is sent, and tells it to hand work that belongs elsewhere, or can run in parallel, to sessions on those machines (`start_session` with `chat`), follow them with `wait_for_session` or `read_session`, and tell the user in plain words what each did. A session it starts (role `started`) gets a **task** prompt instead: do the one task, don't start other sessions, end with a short report for the lead. The app shows these sessions as tasks inside the chat (see [app.md](app.md)).

The hub tells sessions which chat they're in through Claude Code's `--append-system-prompt` (`StartRun.system_prompt`, and `SendInput.system_prompt` for a resume, since Claude Code doesn't keep it across `--resume`). It asks Claude to pass `chat` to `start_session`, so sessions it launches on other machines show up in the chat. Agents before 0.16 ignore the field, so the hub only sets it for newer ones.

**Lifecycle.** Creating a chat starts its first session. Sending goes to the active session: the hub resumes it if no process is live, as for any session. If the active session no longer exists (a scratch folder cleaned up by retention, a transcript deleted), the chat moves to a new session at its target, carrying the conversation. Archiving a chat hides it from the recents; a new message brings it back.

## Titles

A new chat is named from its first message: the first line or sentence, without markdown or "please / can you", cut at a word to 60 characters. The user can rename it (`title_by_user`); the title job then leaves it alone. Clearing the name hands it back to the job. A chat made from an existing session keeps the session's title.

## Targets

Where a chat runs is its `ChatTarget`: a node and folder, or `scratch` (a fresh folder on the hub's machine). The mode says how it was chosen:

1. **`auto`** (the default). The hub lists the folders the user works in: every non-scratch session's folder and every codebase, per node. It scores each against the prompt: the folder's whole name as words in the prompt (`tether`, `fk-cn` or `fkcn`) scores 10; each distinctive word of it 3; a parent folder's word 1. Generic words (`app`, `server`, `src`, `work`...) don't count alone. Ties go to the most recently used. Auto picks the best online folder if it scores at least 3 and nothing else ties with it; otherwise it hands over to Claude.
2. **`manual`**. The user picks a device and folder. `GET /targets?prompt=` gives the list, best match and most recent first, so the project being worked on comes first.
3. **`claude`**. The chat starts in a scratch folder on the hub's machine, with `state: detecting`, and the system prompt asks Claude to work out the target (from the prompt and the hub's `list_nodes` / `list_sessions`), say which and why, or ask the user if it's unclear, and then call the MCP tool `set_chat_target`. That records the target and moves the chat there. A general question with no project ends with `scratch=true`, and the chat stays where it is.

The app shows the target under the chat's title, with why it was picked, and lets the user change it.

## Moving

`POST /chats/{id}/target` with `move` (or `set_chat_target` from Claude) starts a new session at the target and makes it active. Its first message is the conversation so far, oldest first, then the user's text, or "carry on" if there is none. The conversation is trimmed to its newest 40,000 characters, 4,000 per message. The hub turns it into an attached file when it's long, like any long message. The new session's lineage is `move`, with the previous one as parent.

## Context store and post-processing

What's said in a chat is kept in the hub's `chat_messages` table: user messages and Claude's replies, as plain text, per session and item, without tool calls or sub-agent chatter. It's filled as items arrive (`commit`), and when a session joins a chat, from its history. It outlives the sessions, so a chat's context survives scratch retention. `GET /chats/{id}/context` returns it with the chat's notes.

Post-processing jobs (`chatJobs` in `server/internal/hub/chats.go`) run when a chat is made and whenever one of its sessions ends a turn. Each gets the chat and its messages and returns a note (`chat_notes`: one value per kind per chat). The **title** job is the first. Jobs run under the hub lock, so they must be quick. A slow one, like a summary by a model, should start a goroutine and come back through `putChat`.

## Storage

Four tables, added by migration 2: `chats` (the `Chat` message, without its links), `chat_sessions` (chat, session, role, when), `chat_messages` and `chat_notes`.

## Compatibility

- **Older apps** don't know the `chat` frame or `Welcome.chats`. They skip both and keep working with sessions.
- **A newer app on an older hub** gets no chats in `Welcome`, and `POST /chats` returns 404. The app then shows sessions in the history and starts plain sessions (see [app.md](app.md)).
