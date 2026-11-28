#!/usr/bin/env bash
# Builds a release into dist/<version>/. Without a track it builds everything
# (the old unified path); with core it builds only hub/agent/tetherctl/herdr,
# and with app it builds only the signed APK. CI adds the Windows app before
# publishing and writes the track manifest with manifest.sh.
# Usage: build.sh [core|app] [--no-android] [--no-manifest]
# See docs/operations/releasing.md.
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
track=unified
android=1
manifest=1
go_binaries=1
for arg in "$@"; do
  case $arg in
  core | app) track=$arg ;;
  --no-android) android=0 ;;
  --no-manifest) manifest=0 ;;
  *) echo "unknown option $arg" >&2; exit 2 ;;
  esac
done
case $track in
core) android=0 ;;
app) go_binaries=0 ;;
esac

case $track in
app) v=$(sed -n 's/^version: \([0-9.]*\)+.*/\1/p' "$root/app/pubspec.yaml" | tr -d '\r') ;;
*) v=$("$root/tools/release/version.sh" check) ;;
esac
dist=$root/dist/$v
mkdir -p "$dist"
echo "building $v into $dist"

if [ $go_binaries -eq 1 ]; then
  ld="-s -w -X github.com/Mahaveer86619/tether/server/internal/version.Version=$v"
  (
    cd "$root/server"
    for target in linux windows; do
      for bin in tether-hub tether-agent tetherctl tether-herdr; do
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
fi

if [ $android -eq 1 ]; then
  if [ ! -f "$root/app/android/key.properties" ]; then
    echo "app/android/key.properties is missing; the APK has to be signed with the release key, see docs/operations/releasing.md#signing" >&2
    exit 1
  fi
  (
    cd "$root/app"
    flutter build apk --release --build-name="$v" --build-number="$("$root/tools/release/version.sh" code)"
  )
  cp "$root/app/build/app/outputs/flutter-apk/app-release.apk" "$dist/tether-$v.apk"
  echo "  tether-$v.apk"
fi

if [ $manifest -eq 1 ]; then
  if [ "$track" = core ] || [ "$track" = app ]; then
    "$root/tools/release/manifest.sh" "$track" "$dist"
  else
    (
      cd "$root/server"
      go run ./tools/release -dist "$dist" -version "$v" \
        -base-url "${BASE_URL:-https://github.com/${GITHUB_REPOSITORY:-Mahaveer86619/tether}/releases/download/v$v}" \
        -notes "$root/CHANGELOG.md" -min-supported "$(tr -d ' \r\n' < "$root/MIN_SUPPORTED")" >/dev/null
    )
    echo "  latest.json, SHA256SUMS"
  fi
fi
