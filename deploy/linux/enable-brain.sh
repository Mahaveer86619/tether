#!/usr/bin/env bash
# Sets up the second brain on the hub's machine:
#   1. installs the tether-brain program into ~/tether/bin;
#   2. runs it as a user service on the loopback (127.0.0.1:7433), with its
#      database in ~/tether/brain and a small memory cap;
#   3. adds -brain to the hub's flags (a copy of tether.env is kept first) and
#      restarts the hub, which then serves the brain at /brain/mcp; agents
#      register it with Claude Code on their own.
# Needs a hub that knows -brain (0.18.0 or later). Build the program with
# brain/build.sh. Undo: put tether.env.pre-brain back and restart the hub,
# then `systemctl --user disable --now tether-brain`.
# Usage: enable-brain.sh <path to the tether-brain binary>
set -euo pipefail

bin=${1:?usage: enable-brain.sh <path to the tether-brain binary>}
home=${TETHER_HOME:-$HOME/tether}
env_file=$home/tether.env
here=$(cd "$(dirname "$0")" && pwd)
[ -f "$env_file" ] || { echo "no $env_file; install the hub first (see docs/operations/running.md)" >&2; exit 1; }
[ -x "$bin" ] || { echo "$bin is not an executable file" >&2; exit 1; }
"$bin" --version >/dev/null || { echo "$bin does not run on this machine" >&2; exit 1; }

mkdir -p "$home/bin" "$home/brain"
install -m 755 "$bin" "$home/bin/tether-brain.new"
mv "$home/bin/tether-brain.new" "$home/bin/tether-brain"
chmod 700 "$home/brain"
mkdir -p "$HOME/.config/systemd/user"
tr -d '\r' < "$here/tether-brain.service" > "$HOME/.config/systemd/user/tether-brain.service"
systemctl --user daemon-reload
systemctl --user enable tether-brain >/dev/null 2>&1
systemctl --user restart tether-brain

for _ in $(seq 1 20); do
  curl -fsS http://127.0.0.1:7433/healthz >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS http://127.0.0.1:7433/healthz >/dev/null || { echo "the brain does not answer; see: journalctl --user -u tether-brain -n 30" >&2; exit 1; }
echo "the brain is running"

cp -p "$env_file" "$env_file.pre-brain"
if grep -q -- '-brain' "$env_file"; then
  echo "tether.env already has -brain"
else
  if grep -q '^TETHER_HUB_FLAGS="' "$env_file"; then
    # Already quoted: the new flag goes inside the quotes.
    sed -i -E 's|^(TETHER_HUB_FLAGS="[^"]*)"|\1 -brain http://127.0.0.1:7433"|' "$env_file"
  elif grep -q '^TETHER_HUB_FLAGS=' "$env_file"; then
    sed -i "s|^TETHER_HUB_FLAGS=\(.*\)$|TETHER_HUB_FLAGS=\1 -brain http://127.0.0.1:7433|" "$env_file"
  else
    echo "TETHER_HUB_FLAGS=-brain http://127.0.0.1:7433" >> "$env_file"
  fi
  # deploy.sh sources this file, so a value with spaces needs quotes; systemd reads them too.
  sed -i -E '/^TETHER_HUB_FLAGS=[^"]/ s/^TETHER_HUB_FLAGS=(.*)$/TETHER_HUB_FLAGS="\1"/' "$env_file"
fi
systemctl --user restart tether-hub
sleep 3
systemctl --user is-active tether-hub >/dev/null || { echo "the hub did not come back; put $env_file.pre-brain back" >&2; exit 1; }
# This machine's agent registers the brain with Claude Code now; others do within 20 minutes, or when they restart.
systemctl --user restart tether-agent 2>/dev/null || true
echo "the hub now serves the brain at /brain/mcp"
