# Deploy

Everything that puts Tether on a machine.

| Folder | What | Use |
|---|---|---|
| `linux/` | systemd user units, `install.sh`, `deploy.sh`, `tether.env.example`, `enable-*.sh` | Installing the hub and agent on Linux; the release deploy with backup and rollback; optional notification tunnel and second brain |
| `windows/` | `install-agent.ps1`, `install-app.ps1`, `tether.iss` | The Windows agent as an on-demand task; the app from a build; the installer definition |
| `ci/` | `github-bootstrap.sh`, `setup-runner.sh`, the runner service | One-time GitHub setup and the self-hosted runner on the hub's machine |

First install, step by step: [docs/getting-started/using-releases.md](../docs/getting-started/using-releases.md). Options and details: [docs/operations/running.md](../docs/operations/running.md). Releases and the runner: [docs/operations/releasing.md](../docs/operations/releasing.md).
