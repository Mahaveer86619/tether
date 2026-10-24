# The app

`app/` is a Flutter client for Android and Windows. It talks only to the hub.

## Layers

| Layer | Folder | Owns | Talks to |
|---|---|---|---|
| Presentation | `lib/presentation` | Views (widgets) and view models (`Cubit`/`Bloc`) | Use cases |
| Domain | `lib/domain` | Entities, repository interfaces, use cases | Repository interfaces |
| Data | `lib/data` | REST client, WebSocket, cache, mappers, repository implementations | The hub, the device |
| Core | `lib/core` | `Result`, exceptions, failures | — |

Dependencies are wired with `get_it` in `lib/injection.dart`. Data sources, repositories and use cases are lazy singletons; view models are factories. `SessionBloc` takes its session id, and `NewSessionCubit` takes the current hub snapshot. `NavCubit` and `ChatsCubit` are created once, at the top of the app.

## Errors

- The data layer throws only `DataException`s: `ApiException` (an HTTP status plus the hub's error code), `NetworkException`, `RequestTimeoutException`, `ProtocolException`, `StorageException`.
- Repositories catch them and return a `Result<T>`: `Ok` or `Err(Failure)`. `failureFrom` maps hub error codes to typed failures: `UnauthorizedFailure`, `NotFoundFailure`, `NodeOfflineFailure`, `TerminalActiveFailure`, `ValidationFailure`, `ServerFailure`, `NetworkFailure`, `TimeoutFailure`...
- Use cases validate input and return failures too.
- View models put the failure in state with a counter (`failureId`), so the same failure twice still shows twice. Views show `failure.userMessage` in a snackbar.

## Talking to the hub

- **REST (`package:http`)** for request/response: `GET /api/v1/state`, `GET /api/v1/sessions/{id}/timeline?after=`, and `POST` for creating, sending, forking, interrupting, ending and approving. See [protocol.md](protocol.md).
- **WebSocket** only for what the hub pushes: state changes and live timeline updates. Keeping it alive (`data/datasources/hub_socket.dart`):
  - **Heartbeat:** every 15 s the app sends a `heartbeat` frame. If no frame at all arrives within 10 s, the socket counts as dead, however open it looks. Hubs before 0.17 answer with an `unsupported` error, which counts as an answer.
  - **Backoff:** reconnects back off exponentially with jitter (1 s, 2 s, 4 s… up to 30 s, each between half and all of that). A rejected token stops retrying.
  - **Forced reconnects:** a network change (Wi-Fi, mobile data, a VPN; from `connectivity_plus`) and **Retry** always reconnect at once, replacing a socket that only looks alive.
  - **Coming back to the foreground** retries at once if the app was waiting out a backoff, and otherwise sends a heartbeat straight away.
  - **Catching up:** after a reconnect, open timelines subscribe again from their last `seq`.
  - **Status:** the connection line shows "Reconnecting… (try N)" or "Offline · retrying in Ns", with the last error and the number of failed tries in its tooltip; tapping it retries. The socket logs each drop, its reason and the next delay.

## History and background sync

- **Opening a session:**
  1. Show the cached timeline immediately.
  2. Fetch changes since the cached `seq` over REST.
  3. Subscribe on the WebSocket from that `seq`.

  If the hub's latest `seq` is lower than the cache's, the hub was reset; the app drops the cache and fetches everything.
- **What's cached:** timelines and the device/session list, as protobuf files in the app support directory (`hub-cache/`). The 300 most recently updated timelines are kept.
- **Background sync:** sessions that are working or waiting for approval stay subscribed in the background, even when not open, and are released two minutes after they go idle.

## Views

- **Navigation** (`nav/nav_cubit.dart`): one `NavCubit` holds where the app is: the destination (Chats, Monitor, Sessions, Devices, Activity, Files, Usage, Settings), the screens open on top of it (a chat, a new chat, a session, a device), and a history for Back (up to 50 steps). Every layout renders from it, and every screen moves through it; no screen keeps navigation state of its own.
  - Back (the phone's back button, a back arrow, Esc outside a chat or session, the mouse's back button) restores the previous state. With no history it closes the top screen, then returns to Chats; on Chats with nothing open, the phone's back leaves the app.
  - Opening a session that is a chat's active session opens the chat, so you stay in the conversation. Other sessions open on their own.
  - A new chat becomes its chat in place, so Back skips the empty composer.
- **Layouts** (`home/shell.dart`), by window width:
  - **Under 600 px (phones):** a bottom bar with Chats, Monitor (badged with what needs you), Sessions and Devices. Activity, Files, Usage and Settings are in the header's menu and open with a back arrow. Chats, sessions, new chats and devices open as pages on top, through a `Navigator` built from the nav state, so the system back button and the state can't disagree.
  - **600 to 999 px (tablets, narrow windows):** an icon rail with labels, a New chat button and Settings, beside the main pane.
  - **1000 px and wider:** a sidebar with New chat, the destinations, then **Recents** (chats as single lines, the open one highlighted, with a menu on hover) or **Projects** (the session tree by project or device), and the connection line with Settings at the bottom.
  - The current destination is tinted in the accent colour with a filled icon, in the sidebar, the rail and the bottom bar alike.
- **Chats** (`chats/`; see [chats.md](chats.md)):
  - **History** (`chats_page.dart`): chats grouped by Today, Yesterday, Previous 7 days, Previous 30 days and Older, with search and an Archived filter. Each row shows its title, where it runs, its session's state while live, how many sessions are linked, and a menu: Rename, Copy conversation (from the hub's stored context), Archive or Restore. On a hub before 0.16 the history lists sessions instead and starts plain sessions.
  - **New chat** (`new_chat_page.dart`): "What should Claude work on?", a message box with attachments, and a target chip. While the target is Auto, the chip shows what the hub would pick for the text so far ("Auto · tether on laptop", with why), refreshed as you type. The draft is kept on the device.
  - **Target picker** (`target_picker.dart`): Let Tether decide; Let Claude work it out; No project (a scratch folder on the hub's machine); or a device and one of its folders, best match for the message first, then most recently used, plus its home folder. For a chat already going, it also asks whether to carry the conversation over now.
  - **A chat** (`chat_page.dart`) is its active session's screen with the chat's title in the header (tap it to rename in place; Enter saves, Esc cancels, empty hands naming back to the hub). Under the header: where it runs and why, **Change**, the number of linked sessions as a menu (each with its role, device and folder; tap to open), and the chat menu. While Claude is still working out the target, the line says so, with **Choose myself**. If the chat's session is gone, it says so and the next message starts a new session at the target with the conversation so far.
- **Monitor** (`home/monitor_page.dart`), top to bottom:
  - A devices strip ("2 online · 1 offline") that opens Devices. It counts only the other devices, not the one the app runs on.
  - **Needs you:** approvals, sessions waiting for a reply, and failures from the last day.
  - **Running now:** sessions Claude is working in.
  - **Pick up where you left off:** up to four projects (a folder on a device) not already shown above, with **View all** for the Sessions page.
- **Session cards** (`home/cards.dart`) share one look per state: working in the accent colour, waiting in amber, finished in muted green, failed in red with the error, and grey when the device is offline. Each shows the latest useful line (the current to-do, the error, or your last prompt) and an action: Watch, Respond, Approve, Continue.
- **Sessions:** every session, searchable by title, prompt or folder, with filters: Running, Needs you, Finished, Failed, On the hub, Done.
- **Devices**, in install order:
  1. **Hub:** its version, the machine it runs on, and whether the app is connected. It's flagged when it's older than the app.
  2. **Devices running the agent:** this device first. Each shows its agent and Claude Code versions and its live and total sessions, and is flagged "update" when its agent is older than the hub. A device opens its own page of live and past sessions.
  3. **Apps:** the apps connected now (`GET /api/v1/clients`), with their versions, "this app" on the app's own entry, and "update" when older than the hub. An older hub says it can't list them.

  Then an "Adding a device" guide (hub, agents, apps; see [running.md](running.md#install-order)) and the rest of the tailnet.
- **Activity:** a feed grouped by day: sessions started, forked, continued on the hub, finished or failed, and files saved.
- **Files** (`artifacts/files_page.dart`): the hub's artifact store as a list. Search covers names and notes. It filters by type (images, documents, data, media, attached), session and size, and sorts by date, size or name. Each row shows its size, session and note, and has download, copy link, open session and delete. Downloads and uploads show as progress bars with speed, pause, resume and cancel (see [plan.md](plan.md#large-files)). Opened from a session's menu ("This session's files"), the page shows only that session's files, and its Attach button attaches to it. The **Pages** filter lists the pages sessions made (`artifacts/pages_view.dart`), each with Open, which opens it in the browser, and Copy link; a session's own pages are also in its menu.
- **Mark as done:** the session menu archives a session on the hub, so it leaves the "pick up" lists on every client. It comes back by itself if it starts working again.
- **Session screen:** a header (title, state, device and folder, interrupt, menu), the timeline, approval cards, a progress panel for to-dos, and the composer. On phones, fork moves into the menu.
- **Timeline:** consecutive tool calls fold into one "Ran N steps" group that opens in place. Rows are keyed by item id, so new messages don't rebuild the rows above them. Long output, diffs and code show their first lines with "Show all N lines" rather than a nested scroll box. Opening something keeps it where you tapped, even though the list is anchored at the bottom. A long message sent as a file shows in full, collapsed to its first lines with "Show full message". Claude's questions show as a card with each question's options (radio buttons, or checkboxes for multiple choice) and a box for your own words; Skip answers with nothing. The timeline sits in one `SelectionArea`, so text can be selected across messages; the selection menu adds **Quote**, which puts the text into the composer as a `>` quote.
- **Settings:**
  - Before the app is connected, the setup screen pairs it: **Scan QR code** (Android) or the hub address and a pairing code. The admin token is tucked under "Use the hub token instead".
  - Once connected, **Devices** lists paired apps and agents, with **Add a device** (a QR code and the code, with a countdown) and **Revoke**. The app's own entry is tagged "this device" and offers **Disconnect** instead: it revokes this device's token, forgets the hub address and token, clears the cache and returns to the connect screen.
  - A self-signed hub certificate is pinned by fingerprint for both REST and the WebSocket (`HubTls`).
- **Appearance:** light, dark or system, plus a theme (Claude, Ocean, Forest, Rose, Graphite, Solarized) and an optional accent.
  - Each theme has its own syntax colours, so code blocks, shell commands and file previews are highlighted to match (`theme/syntax.dart`, using the `highlight` package; unknown languages stay plain).
  - Themes live in `theme/palettes.dart`. Most are generated from one hue, and the choice is saved per device.
- **Synced settings:** appearance is saved on the hub (`PUT /preferences`) and pushed to every connected app, so changing the theme on the laptop changes it on the phone. When the hub has none yet, the first app to connect offers its own.
- **Drafts:** unsent text in a session's composer, and in the new-chat box, is kept on the device per session, saved half a second after typing stops, and cleared once sent. It survives restarts.
- **Message source:** your messages show where they came from (the phone, a desktop app, `tetherctl`, or typed in the terminal), as recorded by the hub.
- **Tailnet:** Settings → Devices also lists every machine on the hub's tailnet, with tags for the hub, its Tether agent and its apps. Machines without Tether are marked too.
- **Projects tree:** groups sessions by project or by device. Sessions marked done sit in a collapsed "Done" section at the end. Projects start collapsed, apart from the one holding the open session.
- **Workspaces:**
  - Projects are the folders sessions ran in, remembered per device.
  - Workspace roots are folders where new projects are made. They're stored on the hub, managed in Settings → Workspaces, and suggested from the parents of recent projects.
  - The new-session form switches between **Existing project** and **New project** (a root, a name, and the path it will create).
  - A suggested root that gets used is remembered.
  - **Settings → Codebases** lists each folder directly in a root as a codebase, by device: when the hub last copied it, its size and branch, why the last copy failed if it did, its `.env` files as key names (expand a codebase), and **Snapshot now**. See [plan.md](plan.md#codebases-on-the-hub).
- **Usage:** the sidebar's **Usage** page (an icon in the phone's header) has three parts.
  - **Claude plan:** first, the limits Claude Code's `/usage` reports, with a bar, percentage and reset time each. Machines on the same account share one card; reset times within 5 minutes count as the same account. If the limits can't be read, the card shows the raw text.
  - **Machines:** counted tokens per machine for the last 5 hours, today and 7 days. Counted means input + output + cache writes.
  - **Sessions:** this week's sessions by tokens.

  It refreshes every 30 seconds while open.
- **Updates** (`update/`): `UpdateCubit` checks the hub's `/api/v1/updates/latest` at start, every 6 hours and when the hub pushes `update_available`. A newer release shows a banner above the main pane (What's new, Skip this version, Update, then download progress), and Android also gets a system notification once per version. Android downloads the APK, checks its sha256 and opens the installer; Windows downloads the zip and applies it on **Restart to update**. Below the release's `min_supported`, `ForcedUpdatePage` replaces the app. The platform side is `data/datasources/update_platform.dart` and `MainActivity.kt`. See [releasing.md](releasing.md#how-apps-and-agents-update).
- **Message box:** `PromptBox` is used by the composer and the new-chat box.
  - The text and the 40 px buttons share one row, so the hint sits level with the buttons.
  - It grows to 5 lines (8 on desktop) with the buttons on the last line.
  - Past a few lines, an expand button opens a full editor (full screen on phones, a large dialog on desktop) on the same text. The desktop editor sends with Ctrl+Enter.
- **Outbox:** a message goes into the session's outbox on the device (`outbox:<session>` in shared preferences) before it's sent, and the composer clears at once. The outbox is shown at the end of the timeline. An entry leaves it once the timeline shows the message.
  - **Matching:** the hub stamps the user item with the message's client id (`UserText.client_id`). A hub too old to stamp ids is matched by text, against the last 10 messages and once each. Text matches ignore how whitespace was reflowed: a message pasted into a terminal can come back with each line break doubled. A message that reaches the timeline before the hub has answered the send leaves the outbox as soon as the answer arrives.
  - **Pasted content:** Claude Code wraps pasted text, including what an agent pastes into a terminal, in `<pasted_content id="…">` tags. The app takes the tags out of user messages, titles and last prompts as they arrive (`unpaste` in `data/mappers/hub_mappers.dart`) and keeps the ids in `UserText.pasted_ids`. A 0.16 hub does this itself; the app does it too for older hubs and cached history.
  - **States:** Sending; Queued (hidden once the hub shows its own "queued" item); Not sent, with Retry or Discard; and "Sent, but not in the session yet" after 10 minutes, with Resend.
  - **Safe retries:** the hub passes a message with a client id it has seen in the last 15 minutes on only once, so Retry and Resend can't double a message.
  - **Restarts:** the outbox is read back when the session opens. A send the app was in the middle of comes back as Not sent.
- **Lineage:** a fork's header says "Forked from …" and opens the parent when tapped. Its timeline has a "Forked here" line after the last message it shares with the parent. A session with forks shows "N forks", a menu that opens them. Forks have a split icon in the sidebar.
- **Attachments:** the composer's paperclip picks files. Each uploads to the artifact store at once, in chunks from disk with its progress on a chip, and then shows as a chip above the text (tap to view, x to remove). "Attach files to this session" in the session menu asks for an optional note and sends the files to the session's folder right away, without a message. They go with the message as artifact ids, and the agent copies them into `.tether/attachments/` in the session's folder. A message can be just files.
- **Artifacts in the timeline:** images and files a tool call read or wrote show under its card, and pasted images under your message. Images are fetched through the app's own client (so a pinned certificate works) and cached; tapping one opens a viewer with download, copy-link and open-in-browser (links expire after an hour). Only files up to 20 MB are previewed in the app; bigger ones offer Download.
- **Global sessions:** the session menu's **Keep a copy on the hub** makes the hub store the transcript after every turn. A global session also gets **Continue on the hub**, which asks for the first message and opens a new session on the hub's machine that carries on from that copy.
- **Fork:** first shows what a fork is (a new session with a copy of this conversation; the original is untouched), then puts the composer in fork mode.
- **Composer:** Enter sends on desktop, Shift+Enter adds a new line, Esc interrupts. For sessions open in your own terminal, the composer is replaced by a notice with **Fork**, except on Windows, where messages are typed into the terminal.
- **Animation:** only items that arrive after the history has loaded animate in. While Claude works between messages, a "Claude is working" indicator shows.
