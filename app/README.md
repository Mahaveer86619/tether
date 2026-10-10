# Tether app

The Flutter client for Tether, for Android and Windows. It shows every Claude Code session on every machine connected to your hub: live chats, progress, approvals. You can start, continue, fork, interrupt and end sessions from it.

It's only a client: everything goes through `tether-hub`. See the [project README](../README.md) for the whole system.

## Features

- **Devices and sessions.** Every machine running `tether-agent`, with its sessions grouped and searchable. Live sessions come first, labelled with where they run (tmux, headless, or your own terminal).
- **Live chat.** Claude's replies render as proper Markdown (headings, lists, tables, code), tool calls as collapsible cards (shell, diffs, file writes, to-dos), and text streams in as it's written. New messages animate in.
- **Control.** Send messages, fork a session into a new one, interrupt the current turn (button, or Esc on desktop), or end a session the agent hosts.
- **Your own terminals.** Sessions you started yourself show up live through hooks, and their permission prompts can be answered here. On Windows the app can also type into them directly.
- **Approvals.** Tool permission prompts and "trust this folder?" questions, from any session, on the dashboard and in the session itself.
- **Offline-friendly.** Chat history and the device/session list are cached on the device, so sessions open instantly. Sessions that are working stay synced in the background.

## Architecture

MVVM with BLoC, in three layers. Each layer only talks to the one below it:

```
lib/
  core/            Result type, typed exceptions (data) and failures (domain)
  data/            REST client (package:http), WebSocket push channel, on-device cache,
                   mappers and repository implementations; exceptions become failures here
  domain/          entities, repository interfaces, use cases (input rules live here)
  presentation/    view models (Cubits/Blocs) and views; views only see view models
  injection.dart   get_it registrations for all of the above
  gen/             Dart types generated from proto/ (do not edit)
```

Details: [docs/app.md](../docs/app.md).

## Run

```sh
flutter run -d windows
flutter run -d <android device>
```

On first launch, enter the hub address (for example `100.x.y.z`) and the token (`TETHER_TOKEN` from the hub machine). On Windows the `TETHER_HUB` and `TETHER_TOKEN` environment variables pre-fill them.

## Test

```sh
flutter test                      # unit, view-model and widget tests
TETHER_HUB=ws://<hub>:7420/ws TETHER_TOKEN=... LIVE_WINDOWS_CWD=<folder on the laptop> \
  flutter test test/live          # end to end against a real hub and agents
```

The live tests start, continue, fork, interrupt and end real sessions using a cheap model. They never send messages to sessions they didn't create.

## Build

```sh
flutter build windows --release
flutter build apk --release
```

After changing `proto/`, run `buf generate` from the repo root (needs `dart pub global activate protoc_plugin`). After changing the icon, see [tools/icongen](../tools/icongen).
