# Getting started

Three ways in. Pick the one that matches what you are doing.

| I want to... | Read | You need |
|---|---|---|
| Use Tether without building anything | [using-releases.md](using-releases.md) | A GitHub release, an always-on machine, Tailscale |
| Clone the repo, build and run it | [from-source.md](from-source.md) | Go, Flutter, Git (Rust and `buf` optional) |
| Fix a bug or add a feature | [contributing.md](contributing.md) | The from-source setup, plus the project's conventions |

## What every setup needs

- **Tailscale** on every device (hub machine, each agent machine, phone, desktop). Tether is built around one tailnet: it is how the hub is reached and how your own devices are trusted. Nothing is exposed publicly.
- **Claude Code** installed and logged in on every machine that will run sessions, for the user the agent runs as. Run `claude` once there and use `/login`.
- **One always-on machine for the hub.** A mini PC, a NAS, a VM or a spare laptop is enough. Linux is the best supported; the hub is a single Go binary.

## The three parts, and the order

1. **Hub** (`tether-hub`) on the always-on machine. Everything connects to it, so it goes first and is updated first.
2. **Agent** (`tether-agent`) on each machine whose sessions you want in Tether, the hub's machine included.
3. **App** on your phone and desktop.

## Not sure it is working?

After the install, open the app's **Devices** screen. The hub, each agent and each connected app should be listed with a version. Start a chat on a device and check that Claude answers. [using-releases.md](using-releases.md#troubleshooting) lists the usual causes when it does not.
