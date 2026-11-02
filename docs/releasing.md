# Releasing and updating

A release is one version number for everything: the hub, the agents, `tetherctl` and both apps. Tagging `vX.Y.Z` builds, publishes and deploys it. The hub's machine can do all of that alone, with no laptop connected. Apps and agents then update from the hub.

## Versions

`VERSION` holds the version. `app/pubspec.yaml` and `app/lib/core/version.dart` must agree with it, and CI checks they do. Change all three at once:

```sh
tools/release/version.sh set 0.18.0   # also sets the Android versionCode: 1800
tools/release/version.sh check        # what CI runs; with a tag: check v0.18.0
```

`MIN_SUPPORTED` is the oldest app and agent version that may keep running. Apps below it get a forced update. Raise it only when the hub stops understanding older clients.

Each release's notes are its section in `CHANGELOG.md` (`## X.Y.Z`). They go into the GitHub Release, into `latest.json`, and into the app's "What's new".

## Making a release

1. On `main`: bump the version, write the `CHANGELOG.md` section, and commit.
2. Tag and push:

   ```sh
   git tag -a v0.18.0 -m "Tether 0.18.0"
   git push origin main v0.18.0
   ```

3. `.github/workflows/release.yml` then runs these jobs:

   | Job | Runs on | Does |
   |---|---|---|
   | `linux` | the hub's machine (self-hosted runner) | `make test`; builds `tether-hub`, `tether-agent` and `tetherctl` for linux-amd64, the agent and tetherctl for windows-amd64, and the APK, signed with the release key from GitHub secrets |
   | `windows` | GitHub's `windows-latest` | builds the Windows app as `tether-windows-X.Y.Z.zip` |
   | `publish` | the hub's machine | the GitHub Release with every file, `SHA256SUMS` and `latest.json` |
   | `deploy` | the hub's machine | `deploy/linux/deploy.sh`; it needs only `linux`, so a Windows failure never blocks the hub |

   The `deploy` job uses the `minipc` environment. Give it required reviewers in the repo settings to approve each deploy by hand.

`workflow_dispatch` runs the same jobs on a branch, but builds and deploys without publishing.

### By hand on the hub's machine

The same steps, without GitHub:

```sh
. ~/ci/ci-env.sh          # the toolchains setup-runner.sh installed
make release              # make test, make dist, make deploy
make dist-go deploy       # when only the server changed: no APK
```

`make dist` signs the APK with `app/android/key.properties`. Link it from `~/ci/signing` (see [Signing](#signing)). Without it, the build stops, unless `ALLOW_DEBUG_SIGNING=1` is set.

## `latest.json`

`tools/release/manifest.sh` writes `latest.json` and `SHA256SUMS` into `dist/X.Y.Z/`, using `server/tools/release`:

```json
{
  "version": "0.17.0",
  "notes": "- Updates in the app. …",
  "published": "2026-10-24T08:00:00Z",
  "min_supported": "0.15.0",
  "platforms": {
    "android":             {"name": "tether-0.17.0.apk", "url": "https://github.com/…/v0.17.0/tether-0.17.0.apk", "sha256": "…", "size": 81487523},
    "windows":             {"name": "tether-windows-0.17.0.zip", …},
    "agent-linux-amd64":   {"name": "tether-agent-linux-amd64", …},
    "agent-windows-amd64": {"name": "tether-agent-windows-amd64.exe", …},
    "hub-linux-amd64":     {"name": "tether-hub-linux-amd64", …},
    "tetherctl-linux-amd64": …, "tetherctl-windows-amd64": …
  }
}
```

## Deploying on the hub's machine

`deploy/linux/deploy.sh dist/X.Y.Z` follows the 0.15 deploy, with checks added:

1. Stops the hub and agent and backs up into `~/tether/backups/<time>-pre-X.Y.Z/`: `hub.db*`, the three binaries and the systemd units. Each binary is also kept as `~/tether/bin/<name>.prev`. It writes `rollback.sh` next to the backup.
2. Installs the new binaries with `install.sh` and restarts both services. The agent's `KillMode=process` keeps tmux sessions alive.
3. Copies the release into `~/tether/updates/X.Y.Z/`.
4. Waits up to a minute for `/healthz` and for `/api/v1/state` to report the new `hubVersion`. If they don't, it removes the release from `updates/`, runs `rollback.sh` (binaries and units; the database stays, since older hubs ignore newer tables) and fails.
5. Waits up to a minute for the hub's own agent to reconnect with the new version. If it doesn't, it puts `tether-agent.prev` back and fails.

To undo a deploy that passed: `~/tether/backups/<time>-pre-X.Y.Z/rollback.sh`. Add `--db` to also restore the database from the backup; that drops the WAL files first and loses anything written since.

## How apps and agents update

**The hub** gets releases two ways:

- The deploy puts them in `<data>/updates/<version>/`. The hub reads that folder at start and every minute.
- Every 30 minutes it polls `-update-feed`, which by default is the GitHub release's `latest.json`. It downloads the files it serves (the APK, the Windows zip, and the agents), checks each against its sha256, and only then takes the release.

A release counts as new when its version is newer, or when it's the same version with more files. That's how the Windows zip, built after the deploy, still arrives. The hub keeps the two newest releases.

The hub serves the release at:

- `GET /api/v1/updates/latest`: the manifest. Each file it has gets a link on the hub; the rest keep their GitHub links.
- `GET /api/v1/updates/files/<version>/<name>`: the file itself. Any token works, node tokens included.

It also sends the manifest in `Welcome.update` and pushes it to every app as an `update_available` frame.

Flags:

- `-update-feed` (empty turns polling off)
- `-updates-dir`
- `-update-agents` (default on)

**Apps** check at start, every 6 hours and whenever the hub pushes a release:

- A newer release shows a banner with **What's new**, **Skip this version** and **Update**. On Android a system notification also announces it, once per version.
- **Android:** the app downloads the APK from the hub, checks its sha256 and opens the system installer. That uses `REQUEST_INSTALL_PACKAGES` and a `FileProvider` on the cache's `updates/` folder. The first time, Android asks to allow installs from Tether.
- **Windows:** the app downloads and checks the zip, then offers **Restart to update**. A helper script (`apply-update.ps1`, next to the download) waits for the app to exit and unpacks the zip. It swaps the app folder, keeping the old one as `<folder>.prev` and putting it back if the swap fails, then starts the app again. The script logs to `apply-update.log`.
- A release whose `min_supported` is above the app's version replaces the whole app with an update screen, and can't be skipped.

**Agents** from 0.17 update themselves:

- The hub asks an idle agent (no running sessions) that is older than the release, at most three times, 30 minutes apart.
- The agent:
  1. downloads its binary from the hub and checks the sha256;
  2. runs it with `version` to check it starts;
  3. renames itself to `<exe>.prev`, moves the new binary into place and writes `<exe>.update`;
  4. exits with code 75. On Linux systemd restarts it; on Windows it first asks Task Scheduler to start "Tether Agent" again.
- On start, the agent counts the starts in `<exe>.update`. Reaching the hub confirms the update and removes the file. After three starts that never reach the hub, it puts `<exe>.prev` back and restarts.
- Turn this off with `-self-update=false`. Agents older than 0.17 are updated by hand, once.

## Signing

The APK is signed with a release key, so updates install over each other. The key never goes in the repo; `*.jks`, `*.keystore` and `app/android/key.properties` are ignored.

**One-off: changing keys.** Android only installs an update signed with the same key as the installed app. Builds up to 0.16 were signed with the laptop's debug key. So you can either:

- **(a)** make a new release key. The phone then has to uninstall the old app once, which loses its pairing (re-pair afterwards); or
- **(b)** use the laptop's existing debug keystore (`%USERPROFILE%\.android\debug.keystore`, alias `androiddebugkey`, passwords `android`) as the release key. Nothing to reinstall, but it's a weak, well-known key.

(a) is the safer choice.

**A new key:**

```sh
keytool -genkeypair -v -keystore tether-release.jks -alias tether -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 tether-release.jks > tether-release.jks.b64
```

Keep the `.jks` and its passwords somewhere safe, outside the repo; losing them means users reinstall.

**GitHub secrets** (repo Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the `.b64` file's content |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `tether` (or `androiddebugkey`) |
| `ANDROID_KEY_PASSWORD` | the key password (empty: same as the keystore's) |

**For `make dist` on the hub's machine:** run `deploy/ci/setup-runner.sh --keystore tether-release.jks`. It asks for the passwords and writes `~/ci/signing/key.properties` (mode 600). Then link it into the checkout:

```sh
ln -sf ~/ci/signing/key.properties app/android/key.properties
```

## The self-hosted runner

`deploy/ci/setup-runner.sh` installs everything under `~/ci`, with no `sudo`. It needs `curl`, `tar`, `unzip`, `git` and `xz`.

- Go (`go/`), Temurin JDK 17 (`jdk/`), the Android SDK (`android-sdk/`: platform-tools, the platform and build-tools), and Flutter at the app's version (`flutter/`).
- Caches in `gopath/`, `go-build/`, `pub-cache/` and `gradle/`. Gradle is capped at 2 GB with two workers, since the machine has about 7 GB and runs other services.
- `ci-env.sh`, to source for builds by hand.
- The GitHub Actions runner (`runner/`), registered with the labels `tether,minipc`. It runs as the systemd user service `tether-ci-runner` at lower CPU priority, with `MemoryHigh=5G`.

```sh
deploy/ci/setup-runner.sh                      # toolchains
deploy/ci/setup-runner.sh --token <TOKEN>      # and register the runner
```

The token is a runner registration token, valid for an hour: repo Settings → Actions → Runners → New self-hosted runner. A repo admin can also run:

```sh
gh api -X POST repos/<owner>/tether/actions/runners/registration-token --jq .token
```

**Security.** The repo is public, so the self-hosted runner only takes jobs from `release.yml`. Those run on tags and manual dispatch, never on pull requests; `ci.yml` uses GitHub's runners for every push and PR. Also set Settings → Actions → General → "Require approval for all external contributors".

## The repository

- `main` is what's released. Work happens on branches, merged by pull request once `ci` passes.
- **Branch protection on `main`:**
  - require a pull request;
  - require the `ci / server` and `ci / app` checks;
  - require a linear history;
  - no force pushes.
- **Tags** `vX.Y.Z` are releases. Protect them in Settings → Rules: only admins create `v*`.
- **Never in the repo:** `hub.db`, `secrets.key`, `tether.env`, keystores, `.local/`, `dist/`. See `.gitignore`.
