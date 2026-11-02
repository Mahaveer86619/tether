#!/usr/bin/env bash
# Keeps VERSION, app/pubspec.yaml and app/lib/core/version.dart in step.
# Usage: version.sh check [vX.Y.Z]   (with a tag, it must match too)
#        version.sh set X.Y.Z
#        version.sh code               (the Android versionCode for VERSION)
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
pubspec=$root/app/pubspec.yaml
dart=$root/app/lib/core/version.dart

# Android needs a growing integer: 0.17.0 -> 1700, 1.2.3 -> 10203.
code() { IFS=. read -r a b c <<<"$1"; echo $((a * 10000 + b * 100 + c)); }

current=$(tr -d ' \r\n' < "$root/VERSION")
case "${1:-check}" in
set)
  new=${2:?usage: version.sh set X.Y.Z}
  [[ $new =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not X.Y.Z: $new" >&2; exit 2; }
  printf '%s\n' "$new" > "$root/VERSION"
  sed -i "s/^version: .*/version: $new+$(code "$new")/" "$pubspec"
  sed -i "s/^const appVersion = .*/const appVersion = '$new';/" "$dart"
  echo "version $new (Android versionCode $(code "$new"))"
  ;;
code)
  code "$current"
  ;;
check)
  pub=$(sed -n 's/^version: \([0-9.]*\)+.*/\1/p' "$pubspec" | tr -d '\r')
  app=$(sed -n "s/^const appVersion = '\(.*\)';/\1/p" "$dart" | tr -d '\r')
  bad=0
  [ "$pub" = "$current" ] || { echo "app/pubspec.yaml says $pub, VERSION says $current" >&2; bad=1; }
  [ "$app" = "$current" ] || { echo "app/lib/core/version.dart says $app, VERSION says $current" >&2; bad=1; }
  if [ -n "${2:-}" ] && [ "${2#v}" != "$current" ]; then
    echo "tag ${2} doesn't match VERSION $current" >&2
    bad=1
  fi
  [ $bad -eq 0 ] || { echo "fix with: tools/release/version.sh set X.Y.Z" >&2; exit 1; }
  echo "$current"
  ;;
*)
  echo "usage: version.sh check [vX.Y.Z] | set X.Y.Z | code" >&2
  exit 2
  ;;
esac
