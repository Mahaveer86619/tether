# From source

Clone, build and run every part on your own machine.

## Prerequisites

| Tool | Version | For |
|---|---|---|
| Git | any recent | everything |
| Go | the version in `server/go.mod` (1.26) | hub, agent, `tetherctl` |
| Flutter | 3.47.x (what CI uses) | the app; Android SDK for the APK, Visual Studio with the C++ desktop workload for Windows |
| [`buf`](https://buf.build) and `protoc-gen-go` | current | only if you change `proto/` |
| Rust (stable) or Docker | current | only for `brain/` |
| Tailscale, Claude Code | | to run it for real (see [getting-started](README.md)) |

## Get the code

```sh
git clone https://github.com/Mahaveer86619/tether.git
cd tether
```

## Build and test

```sh
# Go: hub, agent, tetherctl
cd server
go vet ./... && go test ./...
go build -o bin/ ./cmd/...
```

Cross-compile for another machine:

```sh
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bin/linux/ ./cmd/...
go build -ldflags -H=windowsgui -o bin/tether-agent.exe ./cmd/tether-agent   # Windows agent, no console window
```

```sh
# Flutter app
cd app
flutter pub get
flutter analyze && flutter test --exclude-tags live
flutter run -d windows        # or an Android device/emulator
flutter build apk             # debug-signed unless you configure the release key
```

```sh
# Second brain (optional)
cd brain
cargo test                    # or ./build.sh to build the Linux binary in Docker
```

The same checks run in CI on every push and pull request: `.github/workflows/ci.yml`. The Makefile wraps them: `make test`, `make test-go`, `make test-app`.

## Run it locally

A hub and an agent on one machine is enough to try everything but the multi-device features.

```sh
cd server
export TETHER_TOKEN=dev-token
./bin/tether-hub -addr 127.0.0.1:7420 -db /tmp/tether.db &
./bin/tether-agent -hub ws://127.0.0.1:7420/ws -node dev &
TETHER_HUB=ws://127.0.0.1:7420/ws ./bin/tetherctl nodes
```

Then start the app (`flutter run -d windows`) and, on its setup screen, enter `127.0.0.1:7420` and the token. For a phone or another machine, listen on the machine's Tailscale address instead and see [using-releases.md](using-releases.md).

Useful flags (see `cmd/*/main.go` for all of them):

| Binary | Flag | Meaning |
|---|---|---|
| hub | `-addr`, `-db` | listen address (default `127.0.0.1:7420`), SQLite file |
| hub | `-trust-tailnet` | let your own tailnet's devices in without a token |
| hub | `-tls` | self-signed TLS, for a public address |
| agent | `-hub`, `-node` | where the hub is, the name of this machine |
| agent | `-host auto\|tmux\|headless` | how sessions are hosted |
| agent | `-hooks=false` | do not touch `~/.claude/settings.json` |

Note what the agent changes on your machine: hooks in `~/.claude/settings.json` (backed up, undone with `tether-agent uninstall-hooks`) and a `.tether/` folder in codebases it indexes. See [running.md](../operations/running.md#what-the-agent-changes-on-a-machine).

## Changing the wire contract

`proto/tether/v1/` is the source of truth. After editing, from the repo root:

```sh
buf generate        # writes server/gen and app/lib/gen
```

Commit the generated code with the change. Never edit generated files by hand.

## Install your own build

Use the same installers a release uses: `deploy/linux/install.sh <folder> hub agent` on Linux, `deploy/windows/install-agent.ps1` and `install-app.ps1` on Windows. Details: [running.md](../operations/running.md).

## Making your own release

Versions, signing keys and the CI release flow are in [releasing.md](../operations/releasing.md); the one-time GitHub setup for a fork is in [GITHUB-SETUP.md](../operations/GITHUB-SETUP.md).
