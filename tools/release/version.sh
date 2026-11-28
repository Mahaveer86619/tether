#!/usr/bin/env bash
# The two release tracks have separate versions: VERSION is core, and the
# app's files hold the app version. A plain tag means the old unified track.
# Usage: version.sh check [core-vX.Y.Z|app-vX.Y.Z|vX.Y.Z]
#        version.sh set [core|app] X.Y.Z   (no track sets both)
#        version.sh code                   (the app's Android versionCode)
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
pubspec=$root/app/pubspec.yaml
dart=$root/app/lib/core/version.dart

# Android needs a growing integer: 0.17.0 -> 1700, 1.2.3 -> 10203.
code() { IFS=. read -r a b c <<<"$1"; echo $((a * 10000 + b * 100 + c)); }
app_version() { sed -n 's/^version: \([0-9.]*\)+.*/\1/p' "$pubspec" | tr -d '\r'; }
dart_version() { sed -n "s/^const appVersion = '\(.*\)';/\1/p" "$dart" | tr -d '\r'; }

core=$(tr -d ' \r\n' < "$root/VERSION")
app=$(app_version)
tag_track() {
  case "${1:-}" in
  core-v*) echo core ;;
  app-v*) echo app ;;
  v*) echo unified ;;
  *) echo "" ;;
  esac
}

case "${1:-check}" in
set)
  track=${2:-}
  if [ "$track" = core ] || [ "$track" = app ]; then
    new=${3:?usage: version.sh set [core|app] X.Y.Z}
  else
    new=$track
    track=both
  fi
  [[ $new =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not X.Y.Z: $new" >&2; exit 2; }
  case $track in
  core) printf '%s\n' "$new" > "$root/VERSION"; echo "core $new" ;;
  app)
    sed -i "s/^version: .*/version: $new+$(code "$new")/" "$pubspec"
    sed -i "s/^const appVersion = .*/const appVersion = '$new';/" "$dart"
    echo "app $new (Android versionCode $(code "$new"))"
    ;;
  both)
    printf '%s\n' "$new" > "$root/VERSION"
    sed -i "s/^version: .*/version: $new+$(code "$new")/" "$pubspec"
    sed -i "s/^const appVersion = .*/const appVersion = '$new';/" "$dart"
    echo "core and app $new (Android versionCode $(code "$new"))"
    ;;
  esac
  ;;
code)
  code "$app"
  ;;
check)
  track=$(tag_track "${2:-}")
  bad=0
  case $track in
  core)
    [[ $core =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "bad core version: $core" >&2; bad=1; }
    [ "${2#core-v}" = "$core" ] || { echo "tag $2 doesn't match core $core" >&2; bad=1; }
    ;;
  app)
    [[ $app =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "bad app version: $app" >&2; bad=1; }
    [ "$(dart_version)" = "$app" ] || { echo "app/lib/core/version.dart says $(dart_version), pubspec says $app" >&2; bad=1; }
    [ "${2#app-v}" = "$app" ] || { echo "tag $2 doesn't match app $app" >&2; bad=1; }
    ;;
  unified)
    [ "$core" = "$app" ] || { echo "unified tag needs VERSION $core to match the app $app" >&2; bad=1; }
    [ "${2#v}" = "$core" ] || { echo "tag $2 doesn't match VERSION $core" >&2; bad=1; }
    ;;
  *)
    [[ $core =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "bad core version: $core" >&2; bad=1; }
    [[ $app =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "bad app version: $app" >&2; bad=1; }
    [ "$(dart_version)" = "$app" ] || { echo "app/lib/core/version.dart says $(dart_version), pubspec says $app" >&2; bad=1; }
    ;;
  esac
  [ $bad -eq 0 ] || { echo "fix with: tools/release/version.sh set [core|app] X.Y.Z" >&2; exit 1; }
  case $track in app) echo "$app" ;; *) echo "$core" ;; esac
  ;;
*)
  echo "usage: version.sh check [core-vX.Y.Z|app-vX.Y.Z|vX.Y.Z] | set [core|app] X.Y.Z | code" >&2
  exit 2
  ;;
esac
