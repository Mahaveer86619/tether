# Home server

The mini PC runs `tether-hub`, a `tether-agent`, and the session sandboxes. The NAS is the shared drive for every node.

## Reference hardware

| | |
|---|---|
| OS | Ubuntu 24.04 LTS |
| CPU / RAM / disk | 4-core Intel Jasper Lake, 8 GB RAM, 256 GB SSD |
| Software | Claude Code (logged in), Go, Docker |
| Network | Ethernet and Wi-Fi on the home LAN, joined to the tailnet |
| NAS | On the home LAN, reached from the mini PC over SMB or NFS |

Things this means for the design:

- RAM is the limit. Each Claude Code process uses a few hundred MB, so cap concurrent sandbox sessions at about 3 to start with.
- The machine may host other services too. Sandboxed sessions must not get the Docker socket or host networking, or one bad `Bash` command could take those down.
- The hub listens only on the Tailscale IP (port 7420 by default), so it isn't reachable from the LAN.

Machine-specific details (addresses, users, credentials) stay out of the repo, in the git-ignored `.local/` folder.

## NAS mount

Mount the share once on the host with a systemd automount, credentials in a root-only file:

```
//<nas-host>/<share>  /mnt/nas  cifs  credentials=/etc/tether/nas.cred,uid=tether,gid=tether,_netdev,x-systemd.automount  0 0
```

Layout on the NAS:

```
/mnt/nas/tether/
  workspaces/   project folders sessions work in
  inbox/        files uploaded from the app or laptop
  outputs/      reports and artifacts sessions produce
  transcripts/  hub backups of session event logs
```

The hub's Files API serves this tree to the app. Optionally the mini PC can advertise its LAN as a Tailscale subnet route so the laptop can open the NAS share directly from anywhere.

## Sandbox

Each sandboxed session runs in its own container:

- Image: Ubuntu with Claude Code, git, Go, Node, Python and common CLIs (`deploy/sandbox.Dockerfile`).
- Mounts: one workspace folder from `/mnt/nas/tether/workspaces/<project>` at `/workspace`, `inbox/` read-only, `outputs/` read-write, and the Claude Code login from a dedicated `tether` user's `~/.claude`.
- No Docker socket, no host network, no access to other containers' networks. Outbound internet allowed.
- CPU and memory limits per container.
- The agent runs `claude -p ...` via `docker exec` and streams stdio exactly as on the laptop, so the hub sees no difference.

Run the hub, agent and sandboxes as a dedicated `tether` system user, not your login user.

## Setup checklist

1. Get the NAS credentials and confirm its protocol (SMB or NFS) and share. Until then, sandboxes use a local folder at `/srv/tether` with the same layout.
2. Create the `tether` user, log Claude Code in for it, add `/usr/local/go/bin` to its PATH.
3. Add the CIFS automount and the `tether/` folder layout.
4. Build the sandbox image.
5. Install `tether-hub` and `tether-agent` systemd units from `deploy/`.
