# Building and running

## Build

Requires Go 1.24+. From `server/`:

```sh
go test ./...
go build -o bin/ ./cmd/...                                   # this machine
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bin/linux/ ./cmd/...   # the home server
```

After changing `proto/`, regenerate from the repo root with `buf generate` (needs `buf` and `protoc-gen-go` on PATH).

## Hub and agent on the home server (Linux)

Copy `tether-hub`, `tether-agent` and `tetherctl` plus `deploy/linux/` to the machine, then:

```sh
./deploy/linux/install.sh <dir-with-binaries> hub agent
```

The first run creates `~/tether/tether.env` from `tether.env.example` and stops. Fill it in:

```sh
TETHER_TOKEN=$(openssl rand -hex 32)
TETHER_ADDR=<tailscale ip -4>:7420
TETHER_HUB=ws://<tailscale ip -4>:7420/ws
TETHER_NODE=minipc
```

Run the script again. It installs both as systemd **user** services. So they keep running after you log out and start at boot, enable lingering once:

```sh
loginctl enable-linger   # may need sudo
journalctl --user -u tether-hub -u tether-agent -f
```

## Agent on Windows

From an ordinary (not admin) PowerShell:

```powershell
.\deploy\windows\install-agent.ps1 -Binary .\server\bin\tether-agent.exe -Hub ws://<hub tailscale ip>:7420/ws -Node laptop
```

It asks for the token once and stores it in `%USERPROFILE%\.tether\token`. It then registers a "Tether Agent" task that starts at logon as your user, so it uses your Claude Code login. Logs go to `%USERPROFILE%\.tether\agent.log`.

## tetherctl

A terminal client for the hub. It's useful for testing and scripting until the app exists.

```sh
export TETHER_HUB=ws://<hub tailscale ip>:7420/ws TETHER_TOKEN=...
tetherctl nodes
tetherctl sessions -n 20
tetherctl watch 6b01a2b8                       # follow a session live (prefix of the id)
tetherctl run -node minipc -cwd /srv/project "fix the failing test"
tetherctl send 6b01a2b8 "now add a test for it"
tetherctl send -fork 6b01a2b8 "try a different approach"
tetherctl dump 6b01a2b8                        # timeline as JSON
```

Tool calls that need permission prompt `allow? [y/N]` in the terminal; `-yes` approves everything.

On Windows Git Bash, set `MSYS_NO_PATHCONV=1` before passing Linux paths such as `-cwd /srv/project`, or Git Bash rewrites them into Windows paths.

## Requirements on each node

- Claude Code installed and **logged in** for the user the agent runs as. Headless runs fail with "OAuth session expired" otherwise; fix it by running `claude` once on that machine and using `/login`.
- The working directory you pass to `run` must exist on that node.
