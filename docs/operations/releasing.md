# Releasing and updating

`v0.20.0` was the last unified tag. Since then there are two independent tracks:

| Track | Tag | Version source | What it contains |
|---|---|---|---|
| core | `core-vX.Y.Z` | `VERSION` | hub, agents, `tetherctl`, the optional Herdr bridge, MCP/protocol surface; built and deployed without an app |
| app | `app-vX.Y.Z` | `app/pubspec.yaml` + `app/lib/core/version.dart` | Android APK and Windows app; published without redeploying the hub |

No `1.0` tag is cut until core token routing, budgets and automatic fallback are complete. The Herdr harness itself stays external; only the small `tether-herdr` bridge ships with core.

## Versions and compatibility

Each track has its own version number; they may differ. Bump only the files for the track you are releasing:

```sh
tools/release/version.sh set core 0.21.0   # writes VERSION
tools/release/version.sh set app 0.21.0    # writes pubspec.yaml and version.dart, sets the Android versionCode
tools/release/version.sh check core-v0.21.0
tools/release/version.sh check app-v0.21.0
tools/release/version.sh code              # the app's Android versionCode
```

`tools/release/version.sh set X.Y.Z` with no track still bumps both, for local/unified builds. `check` with no tag validates both tracks independently; a tag is checked against its own track only.

Compatibility files:

- `MIN_SUPPORTED`: the oldest core/agent version a release still accepts; also the app feed's `min_core_version`.
- `APP_MIN_SUPPORTED`: the oldest app version the core feed accepts as `min_app_version`; a lower app is forced to update.

Each manifest carries `track` and the relevant compatibility field. The hub advertises `min_app_version` in core manifests and in `Welcome.update`. The app holds off offering a release whose `min_core_version` is newer than the hub it is talking to.

Release notes come from `CHANGELOG.md` (`## X.Y.Z`) on either track.

## Making a release

What goes into a release is decided by hand, and so is merging it. The release flow starts from the tag on `main` and never merges anything.

1. **Merge what belongs in the track.** Both CI checks on `main`'s latest commit must pass; `FORCE_CI=1` overrides that check.
2. **Open the release pull request** with the version bump and its changelog section:

   ```sh
   make release-prepare TRACK=core BUMP=patch NOTES=notes.md
   # BUMP: patch, minor, major or X.Y.Z
   ```

   This branches from `origin/main`, runs `version.sh set <track>`, adds the notes above the newest changelog section, and opens the pull request. Merge it last.
3. **Release what is on `main`:**

   ```sh
   make release-check TRACK=core   # what would happen; changes nothing
   make release-core               # tag, watch the build, deploy core, check it
   make release-check TRACK=app
   make release-app                # tag, watch the build, publish the app
   ```

   `tools/release/release.sh <track> ...` reads `origin/main` without touching your working tree. It checks the track's version files (the app's two files must agree), a matching changelog section, that the version is newer than the newest release of that track, and that the tag does not exist. It asks you to type the tag before pushing it (`YES=1` skips the prompt), follows the workflow until it ends, prints failed logs, then checks the published assets, the track feed and, for core, the deployed hub. `make release-status TRACK=app` shows a track's newest release.

   By hand: `git tag -a core-v0.21.0 -m 0.21.0 origin/main && git push origin core-v0.21.0` (or `app-v...`).

### What CI does

`.github/workflows/release-core.yml` (`core-v*`):

| Job | Runs on | Does |
|---|---|---|
| `linux` | the hub's machine (self-hosted) | `make test-go`; builds hub, agent, `tetherctl` and `tether-herdr` for linux-amd64, and agent/tetherctl/herdr for windows-amd64 |
| `publish` | the hub's machine | writes `core-latest.json`, `SHA256SUMS` and creates the GitHub Release |
| `deploy` | the hub's machine | `deploy/linux/deploy.sh`, with backup and rollback; needs only `linux` |

`.github/workflows/release-app.yml` (`app-v*`):

| Job | Runs on | Does |
|---|---|---|
| `linux` | the hub's machine | builds the signed APK |
| `windows` | GitHub's `windows-latest` | builds `tether-windows-X.Y.Z.zip`, the installer and signed `appcast.xml` |
| `publish` | the hub's machine | writes `app-latest.json` and creates the GitHub Release; a failed Windows job still publishes the APK |

`workflow_dispatch` builds without publishing; the core workflow can still deploy if you select that input. The `deploy` job uses the `minipc` environment; give it required reviewers in the repo settings to approve each deploy by hand.

### Shipping from your laptop

`make ship` is the old unified manual path (`tools/release/ship.sh`): it bumps both versions, builds everything, deploys over ssh and needs `TETHER_SHIP_HOST` in `.local/ship.env`. Prefer the two track workflows for v1 releases.

On the hub's machine, `make dist-core` / `make dist-app` build one track; `make deploy` deploys a core dist. `make test` checks both server and app, `make test-go` only the server.

## Manifests

`tools/release/manifest.sh <core|app> dist/<version>` writes:

- `core-latest.json` / `app-latest.json` with `version`, `notes`, `published`, `min_supported`, `platforms`, `track`, and the compatibility field for that track;
- `<track>-SHA256SUMS`, plus `latest.json` and `SHA256SUMS` as legacy aliases for installed clients and the deploy script.

Core platforms are `hub-linux-amd64`, `agent-linux-amd64`, `agent-windows-amd64`, `tetherctl-linux-amd64`, `tetherctl-windows-amd64`, `herdr-linux-amd64` and `herdr-windows-amd64`. App platforms are `android` and `windows` (the zip). A generator refuses a dist folder with files from the other track; a unified dist keeps both.

```json
{
  "version": "0.21.0",
  "notes": "- **Faster chats.** …",
  "published": "2026-11-28T08:00:00Z",
  "min_supported": "0.15.0",
  "platforms": {"agent-linux-amd64": {"name": "tether-agent-linux-amd64", "url": "https://github.com/…/core-v0.21.0/tether-agent-linux-amd64", "sha256": "…", "size": 12345}},
  "track": "core",
  "min_app_version": "0.15.0"
}
```

The app feed instead carries `"track": "app"` and `"min_core_version": "0.15.0"`.

## Deploying on the hub's machine

`deploy/linux/deploy.sh dist/<version>` is core-only:

1. Stops the hub and agent and backs up into `~/tether/backups/<time>-pre-<version>/`: `hub.db*`, the three binaries and systemd units. Each binary is kept as `~/tether/bin/<name>.prev`, with a `rollback.sh` beside the backup.
2. Installs the new binaries and restarts both services. The agent's `KillMode=process` keeps tmux sessions alive.
3. Copies the release into `~/tether/updates/<version>/`, where the hub reads it.
4. Waits for `/healthz` and `/api/v1/state` to report the new `hubVersion`; on failure it removes the release, runs `rollback.sh` and fails.
5. Waits for the hub's own agent to reconnect with the new version; on failure it restores `tether-agent.prev`.

To undo a deploy that passed: `~/tether/backups/<time>-pre-<version>/rollback.sh`. Add `--db` to restore the database too; that drops WAL files and loses anything written since.

## How updates reach clients

**Core.** The deploy puts a release in `<data>/updates/<version>/`. The hub reads `core-latest.json` there at start and every minute (falling back to `latest.json` from before the split). Every 30 minutes it also polls `-update-feed`, whose default is the GitHub `core-latest.json`. It downloads only each agent's binary, checks sha256, then tells every app and agent. A release counts as new when its version is newer or it is the same version with more files; the hub keeps the two newest.

- `GET /api/v1/updates/latest`: the core manifest, with hub links for files the hub holds. Older clients keep using this as their app feed until they are past `MIN_SUPPORTED`.
- `GET /api/v1/updates/files/<version>/<name>`: the file itself; any token works, node tokens included.
- `Welcome.update` and `update_available` frames carry the same core manifest, including `min_app_version`.
- Flags: `-update-feed` (empty turns polling off), `-updates-dir`, `-update-agents` (default on).

**Agents** from 0.17 update themselves when idle, at most three tries 30 minutes apart: download the hub's asset, check sha256, run `version`, rename the old binary to `.prev`, move the new one in and exit with code 75. On start, three failed attempts to reach the hub restore `.prev`. Turn it off with `-self-update=false`; agents older than 0.17 are updated by hand once.

**Apps** read the app track, not the core feed:

- Android and the app's banner fetch `app-latest.json` from GitHub. If the newest GitHub release is a core release, they find the newest `app-v*` release through the releases API. The hub's `/api/v1/updates/latest` is used only for legacy untracked manifests. A release whose `min_core_version` is newer than the connected hub is not offered.
- A newer release shows **What's new**, **Skip this version** and **Update**; below the app's `min_supported` it becomes a forced screen. Downloads check sha256. Android uses the same signing key, so installs replace in place.
- Windows uses the signed appcast described below instead of the banner.

## Windows updates

WinSparkle (through `auto_updater`) reads `appcast.xml` from the newest GitHub release and verifies the installer's DSA signature against the public key built into the app. It shows its own dialog, runs `Tether-Setup-<version>.exe /SILENT` and restarts the app. The hub is not involved.

| Part | Where |
|---|---|
| Installer (Inno Setup, per user, upgrades in place) | `deploy/windows/tether.iss`, built by `tools/release/build-windows.ps1` when `ISCC.exe` is present |
| Appcast, with one item, notes and signature | `tools/release/appcast.sh`; URLs point at `app-v<version>` assets |
| Keys | public `app/dsa_pub.pem`; private GitHub secret `APPCAST_DSA_PRIVATE_KEY`. Lose the private key and installed apps can no longer update themselves. |

To make a key pair (once): `openssl dsaparam -out p.pem 4096 && openssl gendsa -out dsa_priv.pem p.pem && openssl dsa -in dsa_priv.pem -pubout -out dsa_pub.pem`, then put `dsa_pub.pem` at `app/dsa_pub.pem` and the private half in the secret with `gh secret set APPCAST_DSA_PRIVATE_KEY < dsa_priv.pem`.

## Signing

The APK is signed with a release key; `*.jks`, `*.keystore` and `app/android/key.properties` are never committed. Since 0.17.7 the key alias is `tether`; phones on the old debug key (up to 0.17.6) uninstall once and re-pair. The build refuses to run without the release key. Put `app/android/key.properties` in place and link it from `~/ci/signing` on the hub machine, as described in [from-source.md](../getting-started/from-source.md).
