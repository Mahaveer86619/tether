#!/usr/bin/env bash
# Builds a release on this machine and deploys it to the hub's machine, so
# the hub, its agent and every app and agent come up to date. The same
# steps CI runs, without GitHub: tests, the Go binaries, the APK, the
# Windows app, latest.json, then deploy.sh over ssh with its backup, health
# checks and automatic rollback. See docs/releasing.md#shipping-from-your-laptop.
#
# Usage: ship.sh [--patch | --version X.Y.Z] [--no-tests] [--no-apk] [--no-windows]
# Needs TETHER_SHIP_HOST (user@host of the hub's machine), set in the
# environment or in .local/ship.env, which is not committed.
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
[ -f .local/ship.env ] && . .local/ship.env
host=${TETHER_SHIP_HOST:?set TETHER_SHIP_HOST (user@host of the hub machine), or put it in .local/ship.env}

tests=1 apk=1 windows=1 target=
while [ $# -gt 0 ]; do
  case $1 in
  --patch)
    IFS=. read -r a b c < <(tr -d ' \r\n' < VERSION)
    target=$a.$b.$((c + 1))
    ;;
  --version) shift; target=${1:?--version needs X.Y.Z} ;;
  --no-tests) tests=0 ;;
  --no-apk) apk=0 ;;
  --no-windows) windows=0 ;;
  *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "commit or stash your changes first: the release is built from the working tree and must match a commit" >&2; exit 1; }
[ -n "$target" ] && tools/release/version.sh set "$target"
v=$(tools/release/version.sh check)
grep -q "^## $v\$" CHANGELOG.md || { echo "CHANGELOG.md has no '## $v' section; write the release notes first" >&2; exit 1; }
ssh -o BatchMode=yes -o ConnectTimeout=15 "$host" true || { echo "cannot ssh to $host" >&2; exit 1; }

if [ $tests -eq 1 ]; then
  echo "== tests"
  (cd server && go vet ./... && go test ./...)
  (cd app && flutter analyze && flutter test --exclude-tags live)
fi

echo "== build $v"
dist=dist/$v
rm -rf "$dist"
flags=(--no-manifest)
[ $apk -eq 0 ] && flags+=(--no-android)
# The APK is signed with the key in app/android/key.properties; without it,
# the debug key, which keeps updating the installed app in place.
[ -f app/android/key.properties ] || export ALLOW_DEBUG_SIGNING=1
tools/release/build.sh "${flags[@]}"
if [ $windows -eq 1 ]; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w tools/release/build-windows.ps1)"
fi
tools/release/manifest.sh "$dist"

echo "== send to $host"
remote=tether/incoming/$v
ssh "$host" "rm -rf ~/$remote && mkdir -p ~/$remote/dist ~/$remote/deploy"
tar czf - -C "$dist" . | ssh "$host" "tar xzf - -C ~/$remote/dist"
tar czf - -C deploy/linux . | ssh "$host" "tar xzf - -C ~/$remote/deploy"

echo "== deploy"
# Deploy files checked out on Windows can have CRLF endings.
ssh "$host" "cd ~/$remote/deploy && sed -i 's/\r\$//' *.sh *.service *.example && bash deploy.sh ~/$remote/dist"

cat <<EOT

Shipped $v. The hub and its agent are on it. Everything else updates itself:
  agents on other machines    when idle, within a few minutes
  the Windows and Android apps  a banner with the release notes; tap Update
Undo with the backup's rollback.sh named above.
EOT
