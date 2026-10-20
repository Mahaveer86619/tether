# Building and running

## Install order

Tether has three parts, and they go in, and are updated, in this order:

1. **The hub** (`tether-hub`) on an always-on machine on your tailnet. Everything connects to it, so it goes first. It's also updated first: agents and apps are made to work with a hub at least as new as they are, and the hub accepts older ones.
2. **The agent** (`tether-agent`) on every machine whose Claude Code sessions you want in Tether, the hub's own machine included. Pair it with a code from the app's "Add a device" or `tetherctl pair`.
3. **The apps** (Android, Windows). Pair one by scanning the QR code another paired app shows, or connect over Tailscale.

The app's Devices screen follows the same order: the hub, then the devices running the agent, then the connected apps. Each shows its version and is flagged "update" when it's older than the hub. Apps from 0.15 send their version (`ClientHello.app_version`), and hubs from 0.15 list connected apps (`GET /api/v1/clients`).

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

## Pairing devices

Instead of copying the admin token everywhere, give each app and agent its own token:

- **App:** on a connected app, Settings → **Add a device** shows a QR code and a code. On the new phone, the setup screen's **Scan QR code** pairs it; on a desktop, type the hub address and code.
- **Agent:** `tether-agent pair -hub <url> -token-file <path> [-node NAME] [-fingerprint SHA256] CODE`. On Windows, `install-agent.ps1 -PairCode CODE` does this for you.
- **From the hub:** `tetherctl pair` prints a code and the QR link; `tetherctl devices` lists paired devices, and `tetherctl revoke <id>` revokes one.

## Your own machines over Tailscale

Add `-trust-tailnet` to the hub (`TETHER_HUB_FLAGS=-trust-tailnet` in `tether.env`). Apps and agents on machines owned by your own Tailscale account then connect without a token:

- **App:** on the setup screen, enter the hub's machine name (for example `minipc`) and choose **Connect over Tailscale**.
- **Agent:** start it without a token.

Settings → Devices lists every machine on the tailnet and what of Tether runs on it.

## A hub on a public address

Over Tailscale, nothing more is needed. On a VM with a public `host:port`, the hub needs TLS, and it refuses to start without it:

```sh
TETHER_HUB_FLAGS=-tls          # in tether.env: a self-signed certificate next to the database
journalctl --user -u tether-hub | grep sha256   # its fingerprint
```

Apps learn the fingerprint from the QR code. Agents and `tetherctl` take it from `-fingerprint` or `TETHER_HUB_FINGERPRINT`. The hub address becomes `wss://host:port/ws`. To use a CA certificate instead, pass `-tls-cert` and `-tls-key`.

## Agent on Windows

From an ordinary (not admin) PowerShell:

```powershell
.\deploy\windows\install-agent.ps1 -Binary .\server\bin\tether-agent.exe -Hub ws://<hub tailscale ip>:7420/ws -Node laptop
```

It asks for the token once and stores it in `%USERPROFILE%\.tether\token`. It then registers a "Tether Agent" task that runs as your user, so it uses your Claude Code login. The task has no logon trigger: the Tether app starts it on launch (`schtasks /Run`), so nothing runs at boot until you open the app. The agent keeps running after you close the app, until you sign out or restart. The task runs `tether-agent.exe` directly (`-token-file`, `-log`) and restarts it within a minute if it stops. Logs go to `%USERPROFILE%\.tether\agent.log`. Build the binary with `-H=windowsgui` so no console window opens; the agent also needs that to type into your terminals.

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
- In each codebase it snapshots: `.tether/codebase.json`, a default `.tetherignore` if there's none, and `.tether/` in `.git/info/exclude`.
- On the hub's machine, restores codebases into `~/.tether/codebases/<id>/` (next to the scratch folder) when a session is continued there.

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

- **Tailscale**, on the same tailnet as the hub. Tether is built around one tailnet: it's how the hub is reached, how it lists machines, and how it trusts your own devices (`-trust-tailnet`).

- Claude Code installed and **logged in** for the user the agent runs as. Headless runs fail with "OAuth session expired" otherwise; fix it by running `claude` once on that machine and using `/login`.
- The working directory you pass to `run` must exist on that node.
