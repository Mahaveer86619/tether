# Using a release

For when you want Tether running and have no wish to build it. Releases come in two independent tracks: [core releases](https://github.com/Mahaveer86619/tether/releases?q=core-v) (`core-vX.Y.Z`) hold the hub, agents and `tetherctl`; [app releases](https://github.com/Mahaveer86619/tether/releases?q=app-v) (`app-vX.Y.Z`) hold the optional Flutter apps. `v0.20.0` was the last combined release.

Tether core is the MVP: the hub, agents and `tetherctl` are enough to pair a device and drive work from a shell or MCP client. The apps in section 3 are optional views. Herdr desktop/Android is an external alternative to them ([core-first-v1.md](../plans/core-first-v1.md)); it is not included in a Tether release and is not required.

## What is in a release

| File | Track | What it is |
|---|---|---|
| `tether-hub-linux-amd64` | core | The hub |
| `tether-agent-linux-amd64`, `tether-agent-windows-amd64.exe` | core | The agent, per OS |
| `tetherctl-linux-amd64`, `tetherctl-windows-amd64.exe` | core | Terminal client for pairing and scripting |
| `tether-herdr-linux-amd64`, `tether-herdr-windows-amd64.exe` | core | Optional MCP sidecar for Herdr panes |
| `Tether-Setup-X.Y.Z.exe` | app | Windows app installer (also `tether-windows-X.Y.Z.zip`) |
| `tether-X.Y.Z.apk` | app | Android app |
| `core-latest.json`, `core-SHA256SUMS` | core | Core manifest and checksums |
| `app-latest.json`, `app-SHA256SUMS`, `appcast.xml` | app | App manifest, checksums and Windows update feed |

`latest.json` and `SHA256SUMS` remain as aliases of the track's manifest for older clients. Check a download against the track's checksums (`sha256sum -c core-SHA256SUMS --ignore-missing`). Core manifests carry the oldest app version they work with; app manifests carry the hub version they need.

## Before you start

1. Install Tailscale on the hub machine, every agent machine and your phone and desktop, signed in to the same account. Note the hub machine's address with `tailscale ip -4`.
2. Install Claude Code on each machine that will run sessions and log in once (`claude`, then `/login`).

## 1. The hub (Linux)

Download `tether-hub-linux-amd64`, `tether-agent-linux-amd64` and `tetherctl-linux-amd64` to a folder on the hub machine, rename them to `tether-hub`, `tether-agent` and `tetherctl`, and `chmod +x` them. Get the repository's `deploy/linux/` folder onto the machine too (clone the repo, or download it as a zip).

```sh
./deploy/linux/install.sh <folder-with-binaries> hub agent
```

The first run creates `~/tether/tether.env` and stops. Fill it in:

```sh
TETHER_TOKEN=$(openssl rand -hex 32)       # the hub's admin token; keep it private
TETHER_ADDR=<tailscale ip -4>:7420
TETHER_HUB=ws://<tailscale ip -4>:7420/ws
TETHER_NODE=minipc                          # the name this machine shows up as
```

Run `install.sh` again. It installs systemd **user** services. To keep them running after you log out and start at boot:

```sh
loginctl enable-linger        # may need sudo
systemctl --user status tether-hub tether-agent
journalctl --user -u tether-hub -f
```

Optional but recommended on a home tailnet: add `TETHER_HUB_FLAGS=-trust-tailnet` to `tether.env`, so apps and agents on your own Tailscale account connect without a token. Without it, pair each device with a code (below).

## 2. The agent on Windows

From an ordinary (not admin) PowerShell, with `deploy\windows\` from the repo:

```powershell
.\deploy\windows\install-agent.ps1 -Binary .\tether-agent-windows-amd64.exe -Hub ws://<hub tailscale ip>:7420/ws -Node laptop
```

It asks for a token once, or take a pairing code instead: `-PairCode ABCDE-FGHJK`. It registers a "Tether Agent" task that runs as you, so it uses your Claude Code login. The Tether app starts it on launch.

## 3. The apps (optional)

**Windows.** Run `Tether-Setup-X.Y.Z.exe`. Once installed, the app offers new releases itself, signed and verified.

**Android.** Install `tether-X.Y.Z.apk` (allow installs from your browser or file manager when asked). The app shows an update banner when a newer release is available.

On first launch, connect to the hub:

- **Over Tailscale** (with `-trust-tailnet`): enter the hub machine's name, e.g. `minipc`, and choose **Connect over Tailscale**.
- **With a pairing code:** on a connected app, **Settings → Add a device** shows a QR code and a code. On the new phone choose **Scan QR code**; on a desktop type the hub address and code. For an agent: `tether-agent pair -hub <url> -token-file <path> CODE`.

## A teammate on your hub

In releases after 0.19.0 several people can use one hub, each with their own login. A teammate needs Tailscale access to the hub's machine (share it with them in Tailscale).

1. **Invite.** On your app: **Settings → Team → Invite**. It shows the hub address and a one-time code, good for 24 hours.
2. **Join.** The teammate installs the app, and on its setup screen types the hub address, the code and **their name**, then **Pair**. They are now a member, with their own chats.
3. **Their agent.** On their machine they run the agent, pairing it with a code from **their** app (**Settings → Add a device**): the machine is then theirs.
4. **Share a device.** On **Devices → Owners and sharing**, the owner of a machine taps **Share**, picks the teammate and **Full access** (Claude sessions, under the owner's Claude login and plan) or **Jobs only**. The chip with their name stops sharing at once.

What each side sees, to check it works:

- Each person sees only their own chats, sessions, approvals, files and notifications, and only their own machines plus the ones shared with them.
- A teammate starting a chat on your machine without a grant gets "you do not have access to this"; with **Jobs only** a chat is refused but a job starts; with **Full access** it runs.
- A session on someone else's machine shows "on <name>'s <machine>" in its header; the machine's owner sees it too, marked "started by <name>", and can stop it but not type into it. Its approvals go to the teammate.
- Stopping the sharing drops the teammate's app connection for a moment; when it comes back the machine is gone from their list.

## Updating

Core first, then the app if you use one. The tracks have separate version numbers, so check both pages for what you run.

- **Hub and the hub machine's agent:** download the core binaries from a `core-vX.Y.Z` release and run `install.sh` again, or let the core release workflow deploy them.
- **Other agents** update themselves from the hub when idle.
- **Apps** offer updates from `app-vX.Y.Z` releases in-app. An app release that needs a newer hub waits until the core is updated.

A core manifest says which app versions still work; an app manifest says which hub version it needs. Each device's version is on the **Devices** screen, flagged "update" when it is behind.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| App cannot reach the hub | Tailscale is off on the phone or desktop; the app's connection doctor says which step to fix. Check `tailscale status`. |
| Agent log shows `context deadline exceeded` | Tailscale on that machine is not connected. On Windows run `tailscale set --unattended=true`. |
| Headless runs say "OAuth session expired" | Claude Code is not logged in for the user the agent runs as. Run `claude` there and `/login`. |
| A device is missing from Devices | The agent is not running or points at the wrong `TETHER_HUB`; check its journal or log. |
| Android refuses to update | The APK was signed with a different key than the installed app; uninstall once and reinstall. |

More detail on each piece: [docs/operations/running.md](../operations/running.md), and for hubs on a public address, the notification tunnel and TLS, the same page. To tidy up or remove Tether see [plans/uninstall.md](../plans/uninstall.md).
