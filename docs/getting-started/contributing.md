# Contributing

Thanks for looking. This page is the working agreement; [CONTRIBUTING.md](../../CONTRIBUTING.md) at the repo root points here.

## Set up

Follow [from-source.md](from-source.md), then run the full checks once so you know the baseline is green:

```sh
make test
```

## Find your way around

| To change... | Look in | Doc |
|---|---|---|
| How sessions are found, hosted, mirrored | `server/internal/agent/` | [sessions.md](../architecture/sessions.md), [hosting.md](../architecture/hosting.md) |
| Routing, chats, approvals, files, updates | `server/internal/hub/` | [architecture.md](../architecture/architecture.md), [chats.md](../architecture/chats.md) |
| How output becomes blocks | `server/internal/render/` | [protocol.md](../architecture/protocol.md) |
| Storage | `server/internal/store/` | |
| The wire contract | `proto/tether/v1/` | [protocol.md](../architecture/protocol.md) |
| A screen or widget | `app/lib/presentation/` | [app.md](../architecture/app.md), [ui-overhaul.md](../design/ui-overhaul.md) |
| The second brain | `brain/src/` | [second-brain-rust.md](../plans/second-brain-rust.md) |
| Releases and deploys | `tools/release/`, `deploy/`, `.github/workflows/` | [releasing.md](../operations/releasing.md) |

[features.md](../product/features.md) is the map of what exists; it names the screens and files each feature touches.

## Conventions

- **App:** MVVM with BLoC/Cubit, dependencies through `get_it`, HTTP through `package:http`, errors as layered exceptions turned into failures in the data layer. Views see view models, never repositories. See [app.md](../architecture/app.md).
- **Go:** standard library first, small packages, tests beside the code. `go vet ./...` and `go test ./...` must pass.
- **Do not run `dart format` on the app.** It rewrites nearly every file and buries your change; keep to the style of the file you are in.
- **Comments:** only for a non-obvious *why*. Explanations of design and flow belong in `docs/`.
- **Docs move with code.** A change that alters behaviour updates the doc it belongs to in the same commit, and its row in [features.md](../product/features.md).
- **Tests.** Add one for what you change. Tests must never touch real sessions or a real machine's state: use temporary directories and fake nodes (see `server/internal/hub/remote_test.go`).
- **No private details in the repo.** No IPs, hostnames or user names of your own machines; keep those in `.local/` (git-ignored).
- **Generated code** (`server/gen`, `app/lib/gen`) is produced by `buf generate`, never edited by hand.

## Branches, commits and pull requests

1. Branch from `main`: `feat/<name>`, `fix/<name>` or `docs/<name>`.
2. Keep commits focused. A subject like `[feat] what it does for the user` or `[fix] what was wrong` matches the history.
3. Run `make test` before you push. CI runs the same checks plus `version.sh check`.
4. Open a pull request against `main` describing what changed and why, and how you checked it. Screenshots for UI changes.
5. Do not bump `VERSION` or edit the changelog in a feature pull request; the release has its own pull request ([releasing.md](../operations/releasing.md)).

## Reporting a problem

Open an issue with the Tether version (Settings, or the **Devices** screen), the OS of the hub, agent and app involved, what you expected, and what happened. Logs help: `journalctl --user -u tether-hub -u tether-agent` on Linux. Remove tokens and addresses first.

For a security issue, do not open a public issue: contact the maintainer directly. The trust model is in [security.md](../architecture/security.md).
