#!/usr/bin/env bash
# Releases one track from what is on main: tags it, watches GitHub build and
# publish it, deploys core, and checks the result. Nothing here merges anything.
#
# Usage: release.sh core|app run
#        release.sh core|app check         say what would happen, change nothing
#        release.sh core|app prepare patch|minor|major|X.Y.Z --notes FILE
#                                          open the version bump pull request
#        release.sh core|app status        the newest release of that track
# Needs git, gh (logged in) and, to check a core deploy, ssh to the hub's
# machine (TETHER_SHIP_HOST in .local/ship.env). Ask before pushing the tag;
# YES=1 skips that. FORCE_CI=1 releases a main whose checks did not pass.
# See docs/operations/releasing.md.
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"

say() { printf '%s\n' "$*"; }
die() { printf 'release: %s\n' "$*" >&2; exit 1; }

# ---- small pure helpers, tested in release_test.sh ----

# True when $1 is a newer version than $2 (X.Y.Z).
version_gt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]; }

# The version after $1 for patch, minor or major.
next_version() {
  local a b c
  IFS=. read -r a b c <<<"$1"
  case $2 in
  patch) echo "$a.$b.$((c + 1))" ;;
  minor) echo "$a.$((b + 1)).0" ;;
  major) echo "$((a + 1)).0.0" ;;
  *) return 1 ;;
  esac
}

# Puts "## $2" and the lines of $3 into the changelog $1, above the newest section.
insert_notes() {
  local file=$1 v=$2 notes=$3 tmp
  tmp=$(mktemp)
  awk -v v="$v" -v notes="$notes" '
    !done && /^## / { print "## " v; print ""; while ((getline line < notes) > 0) print line; print ""; done = 1 }
    { print }
  ' "$file" | tr -d '\r' > "$tmp"
  mv "$tmp" "$file"
}

# Sourced by the tests for the helpers above: stop before anything that needs GitHub.
if [ "${RELEASE_LIB:-}" = 1 ]; then
  return 0 2>/dev/null || exit 0
fi

case ${1:-} in
core | app) track=$1; cmd=${2:-run}; shift 2 ;;
*) track=core; cmd=${1:-run}; shift || true ;;
esac
case $track in
core)
  prefix=core-v
  workflow=release-core
  version_files=(VERSION)
  ;;
app)
  prefix=app-v
  workflow=release-app
  version_files=(app/pubspec.yaml app/lib/core/version.dart)
  ;;
esac

command -v gh > /dev/null || die "the GitHub CLI (gh) is needed"
gh auth status > /dev/null 2>&1 || die "gh is not logged in; run: gh auth login"
[ -f .local/ship.env ] && . .local/ship.env
host=${TETHER_SHIP_HOST:-}

latest_release() { gh release list --limit 100 --json tagName -q '.[].tagName' 2>/dev/null | sed -n "s/^${prefix}//p" | sort -V | tail -1; }

# What origin/main is, read without touching the working tree.
main_facts() {
  git fetch -q origin --tags --force --prune
  main_sha=$(git rev-parse origin/main)
  case $track in
  core) version=$(git show origin/main:VERSION | tr -d ' \r\n') ;;
  app) version=$(git show origin/main:app/pubspec.yaml | sed -n 's/^version: \([0-9.]*\)+.*/\1/p' | tr -d '\r') ;;
  esac
  tag=$prefix$version
  dart=$(git show origin/main:app/lib/core/version.dart | sed -n "s/^const appVersion = '\(.*\)';/\1/p" | tr -d '\r')
  published=$(latest_release)
}

problems=()
problem() { problems+=("$1"); }

inspect() {
  main_facts
  problems=()
  say "$track is ${main_sha:0:7}: $(git log -1 --format=%s origin/main | cut -c1-70)"
  say "$track version on main: $version     newest $track release: ${published:-none}"
  if [ "$track" = app ] && [ "$dart" != "$version" ]; then
    problem "app/pubspec.yaml says $version but app/lib/core/version.dart says $dart; run tools/release/version.sh set app $version in a pull request"
  fi
  git show origin/main:CHANGELOG.md | tr -d '\r' | grep -qx "## $version" || problem "CHANGELOG.md has no '## $version' section on main"
  if [ -n "$(git ls-remote --tags origin "refs/tags/$tag")" ]; then
    problem "$tag is already tagged; main has no newer version (open a release pull request: release.sh $track prepare patch --notes FILE)"
  elif [ -n "$published" ] && ! version_gt "$version" "$published"; then
    problem "$version is not newer than the published $published"
  fi
  local ci
  ci=$(gh run list --workflow ci --commit "$main_sha" --limit 1 --json status,conclusion -q '.[0] | (.status + " " + (.conclusion // ""))' 2>/dev/null || true)
  case $ci in
  "completed success") say "checks on main: passed" ;;
  "") [ "${FORCE_CI:-}" = 1 ] || problem "no checks have run on main's latest commit yet" ;;
  *) [ "${FORCE_CI:-}" = 1 ] || problem "checks on main: ${ci% } (wait for them, or FORCE_CI=1)" ;;
  esac
  local open
  open=$(gh pr list --state open --json number,title -q '.[] | "  #\(.number) \(.title)"' | cut -c1-90)
  if [ -n "$open" ]; then say "open pull requests (not in this release):"; say "$open"; fi
  if [ "$track" = core ] && [ -n "$host" ] && ! ssh -o BatchMode=yes -o ConnectTimeout=15 "$host" true > /dev/null 2>&1; then
    say "warning: cannot ssh to $host (Tailscale may want you to approve it), so the deploy cannot be checked from here"
  fi
}

cmd_check() {
  inspect
  if [ ${#problems[@]} -gt 0 ]; then
    for p in "${problems[@]}"; do say "problem: $p"; done
    exit 1
  fi
  say "ready: running release.sh $track would tag $tag on ${main_sha:0:7}"
}

# Waits for the release workflow the tag started, and fails with its log if it fails.
watch_release() {
  local id=""
  say "waiting for the $workflow run of $tag"
  for _ in $(seq 1 30); do
    id=$(gh run list --workflow "$workflow" --branch "$tag" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
    [ -n "$id" ] && break
    sleep 10
  done
  [ -n "$id" ] || die "no $workflow run started for $tag; look at the Actions page"
  say "release run $id: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions/runs/$id"
  if ! gh run watch "$id" --exit-status --interval 30 > /dev/null 2>&1; then
    say "the release failed:"
    gh run view "$id" --json jobs -q '.jobs[] | "  \(.name): \(.conclusion)"'
    gh run view "$id" --log-failed 2>/dev/null | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tail -25 | cut -c1-200
    die "fix what failed, then either rerun the failed jobs (gh run rerun $id --failed) or merge the fix and retag"
  fi
  say "release run passed"
}

# Checks what a release should leave behind.
verify() {
  local ok=1 assets n repo
  assets=$(gh release view "$tag" --json assets -q '.assets[].name' 2>/dev/null || true)
  n=$(printf '%s\n' "$assets" | grep -c . || true)
  local -a want
  if [ "$track" = core ]; then
    want=(core-latest.json core-SHA256SUMS SHA256SUMS tether-hub-linux-amd64 tether-agent-linux-amd64 tetherctl-linux-amd64 tether-herdr-linux-amd64)
  else
    want=(app-latest.json app-SHA256SUMS "tether-$version.apk")
    # A failed Windows job still publishes the APK; the signed appcast only
    # belongs to a release that actually carries the Windows build.
    if printf '%s\n' "$assets" | grep -q "tether-windows-$version.zip"; then
      want+=(appcast.xml "tether-windows-$version.zip")
    fi
  fi
  for name in "${want[@]}"; do
    printf '%s\n' "$assets" | grep -qx "$name" || { say "missing from the release: $name"; ok=0; }
  done
  say "release has $n files"
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
  feed="https://github.com/$repo/releases/download/$tag/$track-latest.json"
  if curl -fsSL "$feed" | grep -q "\"version\": \"$version\"" && curl -fsSL "$feed" \
    | grep -q "\"track\": \"$track\""; then
    say "the $track feed lists $version"
  else
    say "the $track feed does not list $version yet"
    ok=0
  fi
  if [ "$track" = core ] && [ -n "$host" ]; then
    if out=$(ssh -o BatchMode=yes -o ConnectTimeout=20 "$host" 'systemctl --user is-active tether-hub tether-agent; journalctl --user -u tether-hub --no-pager | grep "tether-hub listening" | tail -1' 2>/dev/null); then
      if printf '%s' "$out" | grep -q "version=$version"; then say "the hub is running $version"; else say "the hub is not on $version: $(printf '%s' "$out" | tail -1 | cut -c1-120)"; ok=0; fi
      printf '%s\n' "$out" | head -2 | grep -vq active && { say "a service on the hub's machine is not active"; ok=0; }
    else
      say "could not ask the hub's machine (ssh); check it by hand"
    fi
  fi
  [ "$ok" = 1 ] || die "the release is not complete; see above"
  say ""
  say "$tag is out."
  if [ "$track" = core ]; then
    say "  Hub and the hub machine's agent: deployed. Other agents update when idle."
  else
    say "  Windows: the app offers it itself (or run Tether-Setup-$version.exe)."
    say "  Android: the update banner offers it."
  fi
}

cmd_run() {
  inspect
  if [ ${#problems[@]} -gt 0 ]; then
    for p in "${problems[@]}"; do say "problem: $p"; done
    exit 1
  fi
  if [ "${YES:-}" != 1 ]; then
    [ -t 0 ] || die "not a terminal: set YES=1 to release without being asked"
    printf 'Release %s %s (main %s)? Type %s to go on: ' "$track" "$version" "${main_sha:0:7}" "$tag"
    read -r answer
    [ "$answer" = "$tag" ] || die "not confirmed"
  fi
  git tag -d "$tag" > /dev/null 2>&1 || true
  git tag -a "$tag" -m "$version" "$main_sha"
  git push -q origin "$tag"
  say "tagged $tag on ${main_sha:0:7} and pushed it"
  watch_release
  verify
}

cmd_status() {
  main_facts
  say "newest $track release: ${published:-none}; version on main: $version"
  [ -n "$published" ] && gh release view "$prefix$published" --json publishedAt,url -q '"published " + .publishedAt + "  " + .url'
  if [ "$track" = core ] && [ -n "$host" ]; then
    ssh -o BatchMode=yes -o ConnectTimeout=20 "$host" 'journalctl --user -u tether-hub --no-pager | grep "tether-hub listening" | tail -1 | grep -o "version=[0-9.]*"' 2>/dev/null | sed 's/^/hub: /' || say "hub: could not ask (ssh)"
  fi
}

# Opens the pull request that makes the next release: the version bump and its changelog section.
cmd_prepare() {
  local want=${1:-} notes="" new
  shift || true
  while [ $# -gt 0 ]; do
    case $1 in
    --notes) notes=${2:?--notes needs a file}; shift 2 ;;
    *) die "unknown option $1" ;;
    esac
  done
  [ -n "$want" ] || die "usage: release.sh $track prepare patch|minor|major|X.Y.Z --notes FILE"
  [ -f "$notes" ] || die "give the changelog bullets in a file: --notes FILE (lines like: - **A title.** What it means for you.)"
  main_facts
  case $want in
  patch | minor | major) new=$(next_version "$version" "$want") ;;
  *) new=$want ;;
  esac
  [[ $new =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "not a version: $new"
  version_gt "$new" "$version" || die "$new is not newer than $version on main"
  local dir branch="release/$track-$new"
  [ -z "$(git ls-remote --heads origin "$branch")" ] || die "$branch already exists on GitHub"
  dir=$(mktemp -d)
  git worktree add -q -b "$branch" "$dir" origin/main
  (
    cd "$dir"
    tools/release/version.sh set "$track" "$new" > /dev/null
    insert_notes CHANGELOG.md "$new" "$notes"
    tools/release/version.sh check "$prefix$new" > /dev/null
    git add "${version_files[@]}" CHANGELOG.md
    git -c core.autocrlf=false commit -q -m "[release] $track $new"
    git push -q -u origin "$branch"
    gh pr create --base main --head "$branch" --title "Release $track $new" \
      --body "Version $new on the $track track and its changelog section. Merge this after the pull requests that belong in the release, then run \`make release-$track\`."
  )
  git worktree remove --force "$dir"
  git branch -D -q "$branch" 2>/dev/null || true
}

case $cmd in
run) cmd_run ;;
check) cmd_check ;;
status) cmd_status ;;
prepare) cmd_prepare "$@" ;;
*) die "unknown command $cmd (run, check, status, prepare)" ;;
esac
