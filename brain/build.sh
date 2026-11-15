#!/usr/bin/env bash
# Builds tether-brain for Linux x86-64 in Docker (no Rust needed on the host),
# into brain/dist/tether-brain. Usage: brain/build.sh
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist
docker run --rm --cpus 2 -m 3g -v "$PWD":/src -w /src -e CARGO_TARGET_DIR=/src/target-linux rust:1-slim sh -c \
  'apt-get update -qq >/dev/null && apt-get install -y -qq build-essential >/dev/null && cargo build --release --locked; chown -R "$(stat -c %u:%g /src)" /src/target-linux'
cp target-linux/release/tether-brain dist/tether-brain
echo "built $(pwd)/dist/tether-brain"
