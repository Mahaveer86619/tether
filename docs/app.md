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

- **Desktop (840px and wider):** a sidebar with devices and their sessions, and a main pane showing the overview, a device page, a session, or settings.
- **Phone:** the overview with devices and recent sessions; sessions and devices open as pages.
- **Session screen:** a header (state, host, model, interrupt, fork, menu with "End session"), the timeline, approval cards, a progress panel for to-dos, and the composer.
- **Composer:** Enter sends on desktop, Shift+Enter adds a new line, Esc interrupts. For sessions open in your own terminal, the composer is replaced by a notice with **Fork**, except on Windows, where messages are typed into the terminal.
- **Animation:** only items that arrive after the history has loaded animate in. While Claude works between messages, a "Claude is working" indicator shows.
