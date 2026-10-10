# Security

Tether lets a phone run commands on your machines through Claude. These rules keep that safe.

## Network

- The hub only listens inside the tailnet, through `tsnet`. Nothing is exposed on the LAN or the internet.
- Tailscale ACLs: tag the hub `tag:tether-hub` and allow only your own devices to reach it. Agents and apps only make outbound connections to the hub.
- The hub checks every connection with Tailscale `WhoIs` and only accepts devices owned by your account.
- Agents also present a per-node token issued at enrollment, so a stolen tailnet device key alone isn't enough to impersonate a node.

## Claude permissions

- Headless sessions never use `--dangerously-skip-permissions` or `bypassPermissions` by default.
- Every permission prompt goes to the app through `--permission-prompt-tool`. Unanswered prompts time out as **deny**.
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
