# Security

Tether lets a phone run commands on your machines through Claude. These rules keep that safe.

## Network

- The hub listens only on the host's Tailscale IP. Nothing is exposed on the LAN or the internet.
- Tailscale ACLs: tag the hub `tag:tether-hub` and allow only your own devices to reach it. Agents and apps only make outbound connections to the hub.
- Every connection must present the shared `TETHER_TOKEN` (compared in constant time). It lives in `~/tether/tether.env` on the hub (mode 600) and `%USERPROFILE%\.tether\token` on Windows, never in the repo.
- Planned: per-device identity with Tailscale `WhoIs` via `tsnet`, and per-node tokens.

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
- The app caches recent sessions locally; clearing it is available in Settings.
- Prompt injection: content Claude reads (web pages, files from `inbox/`) can try to steer it. Approvals for writes, shell commands and network calls are the main defence, so keep them on for sandboxed and unattended runs.
