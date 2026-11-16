# Server

The Go module behind Tether: the hub, the agent that runs on every machine, and `tetherctl`, a terminal client.

| Binary | Role |
|---|---|
| `cmd/tether-hub` | The always-on hub: session index, event log, rendering, approvals, files, git for remote projects, the MCP server, updates |
| `cmd/tether-agent` | Runs on each machine with Claude Code; dials out to the hub; hosts, indexes and mirrors sessions |
| `cmd/tetherctl` | Pairing, listing, watching and driving sessions from a terminal |

## Layout

```
internal/hub/       routing, chats, approvals, files, remote projects, skills, updates, audit
internal/agent/     session index, headless runs, transcript mirror, hooks, project sync
internal/render/    stream-json and transcript lines → timeline items
internal/store/     SQLite (pure Go)
internal/gitsync/   snapshot, push and pull of a project through the hub's git repo
internal/skills/    finding routines, the library, the router
internal/tailnet/   who is on the tailnet and what runs on it
internal/updates/   release feed and self-update
internal/wire/      the WebSocket framing around the protobuf contract
gen/                generated protobuf code (do not edit; regenerate with buf generate)
tools/              small programs: release manifest, skill scanner
```

## Build and test

Needs the Go version in `go.mod`.

```sh
go vet ./... && go test ./...
go build -o bin/ ./cmd/...
```

Tests use temporary directories and fake agents; they never touch real sessions. Live tests that need a real Claude Code are excluded from the default run.

## Run

```sh
export TETHER_TOKEN=dev-token
./bin/tether-hub -addr 127.0.0.1:7420 -db /tmp/tether.db
./bin/tether-agent -hub ws://127.0.0.1:7420/ws -node dev
```

All flags: `./bin/tether-hub -h`. Installing as a service, pairing and `tetherctl`: [docs/operations/running.md](../docs/operations/running.md). How it works: [docs/architecture/](../docs/architecture/).
