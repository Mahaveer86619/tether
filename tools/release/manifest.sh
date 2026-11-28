#!/usr/bin/env bash
# Writes a track's <track>-latest.json and <track>-SHA256SUMS for dist/<version>,
# plus the legacy latest.json/SHA256SUMS aliases. core takes its version from
# VERSION; app takes it from pubspec.yaml.
# Usage: manifest.sh core|app dist/<version>
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
track=${1:?usage: manifest.sh core|app dist/<version>}
dist=$(cd "${2:?usage: manifest.sh core|app dist/<version>}" && pwd)
case $track in
core) v=$(tr -d ' \r\n' < "$root/VERSION") ;;
app) v=$(sed -n 's/^version: \([0-9.]*\)+.*/\1/p' "$root/app/pubspec.yaml" | tr -d '\r') ;;
*) echo "unknown track: $track" >&2; exit 2 ;;
esac
repo=${GITHUB_REPOSITORY:-Mahaveer86619/tether}
base=${BASE_URL:-https://github.com/$repo/releases/download/$track-v$v}
min_core=$(tr -d ' \r\n' < "$root/MIN_SUPPORTED")
min_app=$(tr -d ' \r\n' < "$root/APP_MIN_SUPPORTED")
case $track in
core) min_supported=$min_core; min_core_arg=""; min_app_arg=$min_app ;;
app) min_supported=$min_app; min_core_arg=$min_core; min_app_arg="" ;;
esac

cd "$root/server"
go run ./tools/release -dist "$dist" -version "$v" -base-url "$base" -track "$track" \
  -notes "$root/CHANGELOG.md" -min-supported "$min_supported" \
  -min-app "$min_app_arg" -min-core "$min_core_arg" >/dev/null
echo "  $track-latest.json, $track-SHA256SUMS"
