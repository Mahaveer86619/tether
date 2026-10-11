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

- **Overview (home on the phone):**
  - A quick-start box at the top: type a prompt and send. It starts on the device and in the folder you used most recently; the chips change them, and "more options" opens the full form.
  - Then what needs you (approvals), what's active now, and "Pick up where you left off".
  - "Pick up where you left off" groups sessions by project (a folder on a device), most recent first. Tapping a project continues its latest session.
  - Devices come last.
- **Desktop (840px and wider):** a sidebar and a main pane. The sidebar groups sessions by project or by device. Sessions marked done sit in a collapsed "Done" section at the end. The main pane shows the overview, a device page, a session, or settings.
- **Phone:** the overview; sessions and devices open as pages.
- **Mark as done:** the session menu archives a session on the hub, so it leaves the "pick up" lists on every client. It comes back by itself if it starts working again.
- **Session screen:** a header (title, state, device and folder, interrupt, menu), the timeline, approval cards, a progress panel for to-dos, and the composer. On phones, fork moves into the menu.
- **Timeline:** consecutive tool calls fold into one "Ran N steps" group that opens in place. Rows are keyed by item id, so new messages don't rebuild the rows above them. Long output, diffs and code show their first lines with "Show all N lines" rather than a nested scroll box. Opening something keeps it where you tapped, even though the list is anchored at the bottom.
- **Fork:** first shows what a fork is (a new session with a copy of this conversation; the original is untouched), then puts the composer in fork mode.
- **Composer:** Enter sends on desktop, Shift+Enter adds a new line, Esc interrupts. For sessions open in your own terminal, the composer is replaced by a notice with **Fork**, except on Windows, where messages are typed into the terminal.
- **Animation:** only items that arrive after the history has loaded animate in. While Claude works between messages, a "Claude is working" indicator shows.
