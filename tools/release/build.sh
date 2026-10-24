#!/usr/bin/env bash
# Builds a release into dist/<version>/: the Go binaries for Linux and
# Windows (amd64) and the signed Android APK, then latest.json and
# SHA256SUMS. The Windows app is built on Windows (build-windows.ps1);
# CI adds it before publishing. See docs/releasing.md.
#
# Usage: build.sh [--no-android] [--no-manifest]
# BASE_URL sets where latest.json says the files are; it defaults to the
# GitHub release for the version (GITHUB_REPOSITORY or Mahaveer86619/tether).
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
android=1
manifest=1
for arg in "$@"; do
  case $arg in
  --no-android) android=0 ;;
  --no-manifest) manifest=0 ;;
  *) echo "unknown option $arg" >&2; exit 2 ;;
  esac
done

v=$("$root/tools/release/version.sh" check)
dist=$root/dist/$v
mkdir -p "$dist"
echo "building $v into $dist"

ld="-s -w -X github.com/Mahaveer86619/tether/server/internal/version.Version=$v"
(
  cd "$root/server"
  for target in linux windows; do
    for bin in tether-hub tether-agent tetherctl; do
      # The hub only runs on Linux.
      [ "$target" = windows ] && [ "$bin" = tether-hub ] && continue
      out=$bin-$target-amd64
      flags=$ld
      if [ "$target" = windows ]; then
        out=$out.exe
        # No console window for the agent, which also needs that to type into terminals.
        [ "$bin" = tether-agent ] && flags="$flags -H=windowsgui"
      fi
      GOOS=$target GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags "$flags" -o "$dist/$out" "./cmd/$bin"
      echo "  $out"
    done
  done
)

if [ $android -eq 1 ]; then
  if [ ! -f "$root/app/android/key.properties" ]; then
    echo "app/android/key.properties is missing, so the APK would be signed with a debug key; see docs/releasing.md#signing" >&2
    [ "${ALLOW_DEBUG_SIGNING:-}" = 1 ] || exit 1
  fi
  (
    cd "$root/app"
    flutter build apk --release --build-name="$v" --build-number="$("$root/tools/release/version.sh" code)"
  )
  cp "$root/app/build/app/outputs/flutter-apk/app-release.apk" "$dist/tether-$v.apk"
  echo "  tether-$v.apk"
fi

if [ $manifest -eq 1 ]; then
  "$root/tools/release/manifest.sh" "$dist"
fi
