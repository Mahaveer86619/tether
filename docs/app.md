# The app

`app/` is a Flutter client for Android and Windows. It talks only to the hub.

## Layers

| Layer | Folder | Owns | Talks to |
|---|---|---|---|
| Presentation | `lib/presentation` | Views (widgets) and view models (`Cubit`/`Bloc`) | Use cases |
| Domain | `lib/domain` | Entities, repository interfaces, use cases | Repository interfaces |
| Data | `lib/data` | REST client, WebSocket, cache, mappers, repository implementations | The hub, the device |
| Core | `lib/core` | `Result`, exceptions, failures | — |

Dependencies are wired with `get_it` in `lib/injection.dart`. Data sources, repositories and use cases are lazy singletons; view models are factories. `SessionBloc` takes its session id, and `NewSessionCubit` takes the current hub snapshot.

## Errors

- The data layer throws only `DataException`s: `ApiException` (an HTTP status plus the hub's error code), `NetworkException`, `RequestTimeoutException`, `ProtocolException`, `StorageException`.
- Repositories catch them and return a `Result<T>`: `Ok` or `Err(Failure)`. `failureFrom` maps hub error codes to typed failures: `UnauthorizedFailure`, `NotFoundFailure`, `NodeOfflineFailure`, `TerminalActiveFailure`, `ValidationFailure`, `ServerFailure`, `NetworkFailure`, `TimeoutFailure`...
- Use cases validate input and return failures too.
- View models put the failure in state with a counter (`failureId`), so the same failure twice still shows twice. Views show `failure.userMessage` in a snackbar.

## Talking to the hub

- **REST (`package:http`)** for request/response: `GET /api/v1/state`, `GET /api/v1/sessions/{id}/timeline?after=`, and `POST` for creating, sending, forking, interrupting, ending and approving. See [protocol.md](protocol.md).
- **WebSocket** only for what the hub pushes: state changes and live timeline updates. It reconnects on its own with backoff, and stops retrying if the token is rejected.

## History and background sync

- **Opening a session:**
  1. Show the cached timeline immediately.
  2. Fetch changes since the cached `seq` over REST.
  3. Subscribe on the WebSocket from that `seq`.

  If the hub's latest `seq` is lower than the cache's, the hub was reset; the app drops the cache and fetches everything.
- **What's cached:** timelines and the device/session list, as protobuf files in the app support directory (`hub-cache/`). The 300 most recently updated timelines are kept.
- **Background sync:** sessions that are working or waiting for approval stay subscribed in the background, even when not open, and are released two minutes after they go idle.

## Views

- **Home** (`home/home_page.dart`), top to bottom:
  - A devices strip ("2 online · 1 offline") that opens Devices. It counts only the other devices, not the one the app runs on.
  - **Start a task:** a quick-start box. It starts a hub session (on the hub's machine, in a scratch folder) when that machine is online, otherwise on the device and in the folder used most recently. The chips change device and folder, the paperclip attaches files, and "more options" opens the full form.
  - **Needs you:** approvals, sessions waiting for a reply, and failures from the last day.
  - **Running now:** sessions Claude is working in.
  - **Pick up where you left off:** up to four projects (a folder on a device) not already shown above, with **View all** for the Sessions page.
- **Session cards** (`home/cards.dart`) share one look per state: working in the accent colour, waiting in amber, finished in muted green, failed in red with the error, and grey when the device is offline. Each shows the latest useful line (the current to-do, the error, or your last prompt) and an action: Watch, Respond, Approve, Continue.
- **Sessions:** every session, searchable by title, prompt or folder, with filters: Running, Needs you, Finished, Failed, On the hub, Done.
- **Devices:** "This device" (the node on the app's own machine, if it runs one), then the other machines running Tether (the hub's is tagged), then the rest of the tailnet. A device opens its own page of live and past sessions.
- **Activity:** a feed grouped by day: sessions started, forked, continued on the hub, finished or failed, and files saved.
- **Files** (`artifacts/files_page.dart`): the hub's artifact store as a list. Search covers names and notes. It filters by type (images, documents, data, media, attached), session and size, and sorts by date, size or name. Each row shows its size, session and note, and has download, copy link, open session and delete. Downloads and uploads show as progress bars with speed, pause, resume and cancel (see [plan.md](plan.md#large-files)). Opened from a session's menu ("This session's files"), the page shows only that session's files, and its Attach button attaches to it. The **Pages** filter lists the pages sessions made (`artifacts/pages_view.dart`), each with Open, which opens it in the browser, and Copy link; a session's own pages are also in its menu.
- **Desktop (840px and wider):** a sidebar with Home, Sessions, Devices, Activity, Files and Usage, then the project tree, and a main pane. The tree groups sessions by project or by device. Sessions marked done sit in a collapsed "Done" section at the end.
- **Phone:** a bottom bar with Home, Sessions, Devices and Activity (Home carries a badge for what needs you). Files, Usage and Settings are in the header. Sessions and device pages open on top.
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
- **Drafts:** unsent text in a session's composer, and in the quick-start box, is kept on the device per session, saved half a second after typing stops, and cleared once sent. It survives restarts.
- **Message source:** your messages show where they came from (the phone, a desktop app, `tetherctl`, or typed in the terminal), as recorded by the hub.
- **Tailnet:** Settings → Devices also lists every machine on the hub's tailnet, with tags for the hub, its Tether agent and its apps. Machines without Tether are marked too.
- **Desktop navigation:** the main pane keeps a history. Settings and device pages have a back arrow, and Esc or the mouse back button also go back, except inside a session, where Esc interrupts Claude. Projects in the sidebar start collapsed, apart from the one holding the open session.
- **Workspaces:**
  - Projects are the folders sessions ran in, remembered per device.
  - Workspace roots are folders where new projects are made. They're stored on the hub, managed in Settings → Workspaces, and suggested from the parents of recent projects.
  - The new-session form switches between **Existing project** and **New project** (a root, a name, and the path it will create).
  - The quick-start folder chip offers "New project…".
  - A suggested root that gets used is remembered.
  - **Settings → Codebases** lists each folder directly in a root as a codebase, by device: when the hub last copied it, its size and branch, why the last copy failed if it did, its `.env` files as key names (expand a codebase), and **Snapshot now**. See [plan.md](plan.md#codebases-on-the-hub).
- **Usage:** the sidebar's **Usage** page (an icon in the phone's header) has three parts.
  - **Claude plan:** first, the limits Claude Code's `/usage` reports, with a bar, percentage and reset time each. Machines on the same account share one card; reset times within 5 minutes count as the same account. If the limits can't be read, the card shows the raw text.
  - **Machines:** counted tokens per machine for the last 5 hours, today and 7 days. Counted means input + output + cache writes.
  - **Sessions:** this week's sessions by tokens.

  It refreshes every 30 seconds while open.
- **Message box:** `PromptBox` is used by the composer and the quick-start box.
  - The text and the 40 px buttons share one row, so the hint sits level with the buttons.
  - It grows to 5 lines (8 on desktop) with the buttons on the last line.
  - Past a few lines, an expand button opens a full editor (full screen on phones, a large dialog on desktop) on the same text. The desktop editor sends with Ctrl+Enter.
- **Outbox:** a message goes into the session's outbox on the device (`outbox:<session>` in shared preferences) before it's sent, and the composer clears at once. The outbox is shown at the end of the timeline. An entry leaves it once the timeline shows the message.
  - **Matching:** the hub stamps the user item with the message's client id (`UserText.client_id`). A hub too old to stamp ids is matched by text, against the last 10 messages and once each.
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
