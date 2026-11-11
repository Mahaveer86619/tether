#!/usr/bin/env bash
# Turns on the hub's notification tunnel on the hub's machine:
#   1. downloads Cloudflare's `cloudflared` into ~/tether/bin (no root needed);
#   2. adds -notify-tunnel and -cloudflared to TETHER_HUB_FLAGS in tether.env,
#      keeping a copy of the file first;
#   3. restarts the hub and prints the tunnel's address once it has one.
# The tunnel serves only notifications, behind a token that opens nothing
# else; see docs/plans/notifications.md#what-is-built. Undo: put
# tether.env.pre-tunnel back and restart the hub.
# Usage: enable-notify-tunnel.sh
set -euo pipefail

home=${TETHER_HOME:-$HOME/tether}
env_file=$home/tether.env
bin=$home/bin/cloudflared
[ -f "$env_file" ] || { echo "no $env_file; install the hub first (see docs/operations/running.md)" >&2; exit 1; }

case $(uname -m) in
x86_64) asset=cloudflared-linux-amd64 ;;
aarch64) asset=cloudflared-linux-arm64 ;;
*) echo "no cloudflared build for $(uname -m)" >&2; exit 1 ;;
esac

if [ ! -x "$bin" ]; then
  echo "downloading cloudflared"
  tmp=$(mktemp)
  curl -fsSL -o "$tmp" "https://github.com/cloudflare/cloudflared/releases/latest/download/$asset"
  chmod 755 "$tmp"
  "$tmp" --version >/dev/null || { echo "the download does not run on this machine" >&2; rm -f "$tmp"; exit 1; }
  mv "$tmp" "$bin"
fi
"$bin" --version

cp -p "$env_file" "$env_file.pre-tunnel"
if grep -q -- '-notify-tunnel' "$env_file"; then
  echo "tether.env already has -notify-tunnel"
else
  if grep -q '^TETHER_HUB_FLAGS=' "$env_file"; then
    sed -i "s|^TETHER_HUB_FLAGS=\(.*\)$|TETHER_HUB_FLAGS=\1 -notify-tunnel -cloudflared $bin|" "$env_file"
  else
    echo "TETHER_HUB_FLAGS=-notify-tunnel -cloudflared $bin" >> "$env_file"
  fi
fi

systemctl --user restart tether-hub
echo "waiting for the tunnel's address"
for _ in $(seq 1 30); do
  url=$(journalctl --user -u tether-hub --since "1 minute ago" --no-pager 2>/dev/null | grep -o 'url=https://[a-z0-9-]*\.trycloudflare\.com' | tail -1 | cut -d= -f2 || true)
  if [ -n "$url" ]; then
    echo "the tunnel is up at $url (apps are told by themselves)"
    exit 0
  fi
  sleep 2
done
echo "no address after a minute; look at: journalctl --user -u tether-hub -n 40" >&2
exit 1
