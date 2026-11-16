# Using a release

For when you want Tether running and have no wish to build it. Every part is a download from the [latest release](https://github.com/Mahaveer86619/tether/releases/latest).

## What is in a release

| File | What it is |
|---|---|
| `tether-hub-linux-amd64` | The hub |
| `tether-agent-linux-amd64`, `tether-agent-windows-amd64.exe` | The agent, per OS |
| `tetherctl-linux-amd64`, `tetherctl-windows-amd64.exe` | Terminal client for pairing and scripting |
| `Tether-Setup-X.Y.Z.exe` | Windows app installer (also `tether-windows-X.Y.Z.zip`) |
| `tether-X.Y.Z.apk` | Android app |
| `SHA256SUMS`, `latest.json`, `appcast.xml` | Checksums, release manifest and the Windows update feed |

Check a download against `SHA256SUMS` (`sha256sum -c SHA256SUMS --ignore-missing`).

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

## 3. The apps

**Windows.** Run `Tether-Setup-X.Y.Z.exe`. Once installed, the app offers new releases itself, signed and verified.

**Android.** Install `tether-X.Y.Z.apk` (allow installs from your browser or file manager when asked). The app shows an update banner when a newer release is available.

On first launch, connect to the hub:

- **Over Tailscale** (with `-trust-tailnet`): enter the hub machine's name, e.g. `minipc`, and choose **Connect over Tailscale**.
- **With a pairing code:** on a connected app, **Settings → Add a device** shows a QR code and a code. On the new phone choose **Scan QR code**; on a desktop type the hub address and code. For an agent: `tether-agent pair -hub <url> -token-file <path> CODE`.

## Updating

Hub first, then everything else.

- **Hub and the hub machine's agent:** download the new binaries and run `install.sh` again, or, if you use the repository's release flow, let CI deploy it.
- **Other agents** update themselves from the hub when idle.
- **Apps** offer the update in-app.

The hub accepts older clients, and clients need a hub at least as new as they are, which is why the hub goes first. Each device's version is on the **Devices** screen, flagged "update" when it is behind.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| App cannot reach the hub | Tailscale is off on the phone or desktop; the app's connection doctor says which step to fix. Check `tailscale status`. |
| Agent log shows `context deadline exceeded` | Tailscale on that machine is not connected. On Windows run `tailscale set --unattended=true`. |
| Headless runs say "OAuth session expired" | Claude Code is not logged in for the user the agent runs as. Run `claude` there and `/login`. |
| A device is missing from Devices | The agent is not running or points at the wrong `TETHER_HUB`; check its journal or log. |
| Android refuses to update | The APK was signed with a different key than the installed app; uninstall once and reinstall. |

More detail on each piece: [docs/operations/running.md](../operations/running.md), and for hubs on a public address, the notification tunnel and TLS, the same page. To tidy up or remove Tether see [plans/uninstall.md](../plans/uninstall.md).
