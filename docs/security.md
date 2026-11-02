# Security

Tether lets a phone run commands on your machines through Claude. These rules keep that safe.

## Network

- The hub listens only on the host's Tailscale IP. Nothing is exposed on the LAN or the internet.
- Tailscale ACLs: tag the hub `tag:tether-hub` and allow only your own devices to reach it. Agents and apps only make outbound connections to the hub.
- Every connection presents a token. Tokens never go in the repo.
  - **The admin token** (`TETHER_TOKEN`) lives in `~/tether/tether.env` on the hub (mode 600) and is compared in constant time. Use it for `tetherctl` on the hub and for recovery.
  - **Device tokens** come from pairing. A one-time code (from the app's **Add a device** or `tetherctl pair`) expires after 10 minutes and works once; it buys a device its own random token.
  - The hub stores only token hashes. A node token only connects as the node it was paired for, and never reaches the REST API. Settings → Devices (or `tetherctl revoke`) deletes a token and closes its connections at once.
- After 10 failed token checks or pairing attempts in 10 minutes, an address is refused until the window passes.
- **On a public address** the hub refuses plain HTTP (unless started with `-insecure`).
  - With `-tls` it serves a self-signed certificate, kept next to its database. Pairing codes carry its SHA-256, and the apps and agents pin it: no other certificate is accepted, and there's no "trust this certificate?" prompt.
  - `-tls-cert`/`-tls-key` use a certificate from a CA instead.
- **Tailnet trust (`-trust-tailnet`):** apps and agents connecting from a machine owned by the same Tailscale user as the hub's machine get in without a token.
  - The hub matches the connection's address against `tailscale status`, cached for 30 s. Tailscale drops 100.x traffic that didn't arrive over the tailnet interface, so the address can't be spoofed from the LAN.
  - Machines shared into the tailnet by other users still need a token or a pairing code.
  - Trusted machines are revoked through Tailscale (remove the machine), not in Tether.

## Claude permissions

- Headless sessions never use `--dangerously-skip-permissions` or `bypassPermissions` by default.
- Permission prompts go to the app through the `PermissionRequest` hook (interactive sessions) or `--permission-prompt-tool stdio` (headless). In a terminal the local prompt stays usable; headless prompts nobody answers are denied after 30 minutes.
- The hook receiver listens on `127.0.0.1` only, without a token, so any local process could post fake hook events. At worst that shows a bogus approval in the app; it can't approve anything on Claude's behalf.
- The agent edits `~/.claude/settings.json` to add its hooks, after backing it up to `settings.json.tether-backup`. `tether-agent uninstall-hooks` removes them; `-hooks=false` stops the agent from adding them.
- "Always allow" rules chosen in the app are stored per node and per project and are visible and revocable in Settings.

## Sandbox

- Sandbox containers get no Docker socket, no host network and no access to other containers' networks.
- Only the session's own workspace folder is writable; `inbox/` is read-only.
- Per-container CPU and memory limits.

## Data

- Transcripts can contain secrets and personal data. The hub's SQLite file and NAS backups are readable only by the `tether` user.
- NAS credentials live in a root-only file referenced by the mount, never in the repo or the database.
- `.env` files of codebases are sealed with AES-GCM under `<hub data dir>/secrets.key` (mode 600, made on first use) before they're stored. Apps and the MCP server only see their paths and key names, with a short keyed fingerprint per value. Values are given back only to the agent on the hub's own machine, to write the files when it restores a codebase. Back up `secrets.key` with the database, or the vault can't be opened.
- Generated pages are served from the hub's address with `Content-Security-Policy: sandbox`, so their scripts run as an opaque origin and can't use the hub's API as the page.
- The app caches recent sessions locally; clearing it is available in Settings.
- Prompt injection: content Claude reads (web pages, files from `inbox/`) can try to steer it. Approvals for writes, shell commands and network calls are the main defence, so keep them on for sandboxed and unattended runs.
