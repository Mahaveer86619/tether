# GitHub setup (one-time, for the repo owner)

Releases are built and deployed by GitHub Actions on the hub's machine; see [releasing.md](releasing.md). Until the steps below are done, everything is built and deployed by hand with `make release`.

Today the laptop and the hub's machine both reach GitHub as **MahaveerPanigrahi86619**, which can only read `Mahaveer86619/tether`. Pushing, releases, branch protection and the runner need the owner, **Mahaveer86619**, once.

## The quick way: one script

On the hub's machine, logged in to GitHub as the owner:

1. Create a token: github.com → Settings → Developer settings → Personal access tokens → **Fine-grained tokens** → Generate new token.
   - Repository access: only `Mahaveer86619/tether`.
   - Permissions: Administration (read and write), Secrets (read and write), Environments (read and write), Actions (read and write), Contents (read and write).
   - Expiry: 7 days. It's needed once.
2. Run:

   ```sh
   cd ~/src/tether
   export GH_TOKEN=<the token>
   deploy/ci/github-bootstrap.sh --dry-run --collaborator MahaveerPanigrahi86619   # see what it will do
   KEYSTORE_PASSWORD=android \
     deploy/ci/github-bootstrap.sh --collaborator MahaveerPanigrahi86619 \
       --keystore ~/ci/signing/release.jks --alias androiddebugkey \
       --register-runner --push
   unset GH_TOKEN
   ```

3. Accept the collaborator invitation as MahaveerPanigrahi86619: github.com/notifications, or the email.

The script is safe to run again: every step sets the same state. `--keystore` needs `gh` (the GitHub CLI) on the machine. `deploy/ci/github-bootstrap_test.sh` checks it in dry-run mode.

## The same by hand

| Step | Where |
|---|---|
| 1. Add MahaveerPanigrahi86619 with the **Admin** role | Repo → Settings → Collaborators → Add people |
| 2. Branch protection for `main`: require a pull request, require the status checks `server` and `app` (from `ci`), require a linear history, no force pushes, no deletions | Settings → Branches → Add branch ruleset (or classic protection rule) |
| 3. Tag ruleset "release tags": target tags `refs/tags/v*`; restrict creation, updates and deletions; bypass for the Repository admin role | Settings → Rules → Rulesets → New tag ruleset |
| 4. Environment `minipc`, with required reviewer Mahaveer86619 | Settings → Environments → New environment |
| 5. "Require approval for all external contributors" | Settings → Actions → General → Fork pull request workflows |
| 6. Secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Settings → Secrets and variables → Actions → New repository secret |
| 7. Runner registration token (valid for 1 hour) | Settings → Actions → Runners → New self-hosted runner, the `--token` value |
| 8. On the hub's machine: `deploy/ci/setup-runner.sh --token <TOKEN>` | registers the runner as `<host>-tether` with the labels `tether,minipc` and starts it as `tether-ci-runner` |
| 9. Push: `git push origin main --tags` | any machine with write access |

For secret 6: `base64 -w0 ~/ci/signing/release.jks` gives the keystore value.

## Publishing releases from GitHub

The apps read releases from GitHub, not from the hub. For that to work:

1. **The repository is public** (it is). The apps fetch the release files without signing in, and a private repository's release files need a login.
2. **Add the Windows signing secret** (see [releasing.md](releasing.md#windows-updates)): `APPCAST_DSA_PRIVATE_KEY` is the contents of the private half of the key pair whose public half is in `app/dsa_pub.pem`. From a machine with `gh` logged in as the owner: `gh secret set APPCAST_DSA_PRIVATE_KEY < dsa_priv.pem`. Keep another copy of that file offline; without it no installed Windows app can update.
3. **The Android secrets** are the four `ANDROID_KEYSTORE_*` ones above.
4. **Make a release**: bump the version and write its `CHANGELOG.md` section (`tools/release/version.sh set X.Y.Z`), commit, then `git tag -a vX.Y.Z -m "Tether X.Y.Z" && git push origin main vX.Y.Z`. The `release` workflow builds on the self-hosted runner (the APK and the hub, agent and tetherctl binaries) and on GitHub's own Windows runner (the app, its zip, the installer, and the signed `appcast.xml`), makes the GitHub Release with all of them and `latest.json`, and deploys the hub's machine.
5. **Check the feeds** after the first release; both must answer 200 with no login:

   ```sh
   curl -sI -L https://github.com/Mahaveer86619/tether/releases/latest/download/appcast.xml | head -1
   curl -sI -L https://github.com/Mahaveer86619/tether/releases/latest/download/latest.json | head -1
   ```

   `latest` is the newest release that is not a draft or a pre-release, so do not mark releases as pre-releases.

`make ship` and `tools/release/ship.sh` still deploy a build straight to the hub from your laptop for trying something out; the apps then see it only through the hub, and only while it is newer than what GitHub has.

## The signing key

Since 0.17.7 the APK is signed with its own **release key** (alias `tether`, RSA 4096), made on the laptop and kept in `.local/keys/tether-release.jks` with its passwords in `.local/keys/tether-release.key.properties`. Both are ignored by git. **Back them up somewhere outside this machine**: losing them means every phone has to uninstall and re-pair again.

It is in four places: the laptop (`app/android/key.properties`, for `ship.sh`), the hub's machine (`~/ci/signing/`, mode 600, for `make dist`), and the GitHub secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`, which the release workflow turns into a key file for one run.

Android only installs an update signed with the same key as the installed app, so a phone that has a build signed with the old debug key must **uninstall once and re-pair**. Builds can no longer be made without the key: `ship.sh` and `make dist` refuse.

