#!/usr/bin/env bash
# Writes latest.json and SHA256SUMS for a dist/<version> folder.
# Usage: manifest.sh dist/<version>
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
dist=$(cd "${1:?usage: manifest.sh dist/<version>}" && pwd)
v=$(tr -d ' \r\n' < "$root/VERSION")
repo=${GITHUB_REPOSITORY:-Mahaveer86619/tether}
base=${BASE_URL:-https://github.com/$repo/releases/download/v$v}

cd "$root/server"
go run ./tools/release -dist "$dist" -version "$v" -base-url "$base" \
  -notes "$root/CHANGELOG.md" -min-supported "$(tr -d ' \r\n' < "$root/MIN_SUPPORTED")"
echo "  latest.json, SHA256SUMS"
