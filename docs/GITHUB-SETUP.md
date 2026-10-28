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

## The signing key (still to decide)

Since 0.17.0 the APK is signed with the **laptop's Android debug keystore**. It was copied to `~/ci/signing/release.jks` on the hub's machine, with alias `androiddebugkey` and passwords `android`. That's the key the installed app already has, so updates install over it without uninstalling or re-pairing.

**The weakness:** the debug keystore's passwords are public, and a debug key isn't meant to sign releases. Anyone with that file can sign an APK the phone accepts as an update. Keep the file private: it's ignored by git, and the copy on the hub's machine is mode 600.

**To move to a proper key later** (the phone then has to uninstall once and re-pair):

```sh
keytool -genkeypair -v -keystore tether-release.jks -alias tether -keyalg RSA -keysize 4096 -validity 10000
```

Then run `github-bootstrap.sh --keystore tether-release.jks --alias tether` with its passwords, and `setup-runner.sh --keystore tether-release.jks`. Release the next version and install it once by hand.
