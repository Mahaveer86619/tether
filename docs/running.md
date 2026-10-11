# Building and running

## Build

Requires Go 1.24+. From `server/`:

```sh
go test ./...
go build -o bin/ ./cmd/...                                   # this machine
go build -ldflags -H=windowsgui -o bin/tether-agent.exe ./cmd/tether-agent   # Windows agent: no console window
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

It asks for the token once and stores it in `%USERPROFILE%\.tether\token`. It then registers a "Tether Agent" task that starts at logon as your user, so it uses your Claude Code login. The task runs `tether-agent.exe` directly (`-token-file`, `-log`) and restarts it within a minute if it stops. Logs go to `%USERPROFILE%\.tether\agent.log`. Build the binary with `-H=windowsgui` so no console window opens; the agent also needs that to type into your terminals.

## App on Windows

```powershell
cd app; flutter build windows --release; cd ..
.\deploy\windows\install-app.ps1            # -NoDesktop to skip the desktop shortcut
```

It copies the build to `%LOCALAPPDATA%\Programs\Tether` and adds Start menu and desktop shortcuts. Run it again after each build to update; it closes the running app first. The hub address and token entered in the app survive reinstalls. If icons are missing in a Windows build, Flutter reused a stale icon font: delete `app/build/flutter_assets` and `app/.dart_tool/flutter_build`, then build again.

If the agent log shows `context deadline exceeded` when dialling the hub, check `tailscale status`. Tailscale on Windows can sit in `NoState` when its tray app isn't running. `tailscale set --unattended=true` keeps it connected without the tray app, including before you log in.

## What the agent changes on a machine

- Adds HTTP hooks to `~/.claude/settings.json` (backup: `settings.json.tether-backup`). Undo with `tether-agent uninstall-hooks`, or run with `-hooks=false`.
- On Linux with tmux, creates a tmux session named `tether` with one window per Claude session. Attach with `tmux attach -t tether`.

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
tetherctl interrupt 6b01a2b8                   # stop the current turn
tetherctl stop 6b01a2b8                        # end a tmux or headless session
tetherctl rebuild 6b01a2b8                     # re-render the timeline from the transcript
tetherctl approvals                            # pending approvals
tetherctl approve [-deny] <approval id>
```

Tool calls that need permission prompt `allow? [y/N]` in the terminal; `-yes` approves everything.

On Windows Git Bash, set `MSYS_NO_PATHCONV=1` before passing Linux paths such as `-cwd /srv/project`, or Git Bash rewrites them into Windows paths.

## Requirements on each node

- Claude Code installed and **logged in** for the user the agent runs as. Headless runs fail with "OAuth session expired" otherwise; fix it by running `claude` once on that machine and using `/login`.
- The working directory you pass to `run` must exist on that node.
