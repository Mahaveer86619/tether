#!/usr/bin/env bash
# Runs the notification tunnel as a Docker service (on-demand-tunnel-cf's
# tunneld) on the hub's machine and points the hub at it:
#   1. starts tunneld from its source folder with docker compose, with an
#      admin token of its own (made once, kept in the folder's .env);
#   2. adds -tunneld to TETHER_HUB_FLAGS and the token to tether.env, keeping
#      a copy of the file first;
#   3. restarts the hub, which registers its notification listener with
#      tunneld and passes the address on to every app.
# Undo: put tether.env.pre-tunneld back, restart the hub, `docker compose down`.
# The hub's notification listener (reached by the container) is on 0.0.0.0:$NOTIFY_PORT, 7421 unless set.
# Usage: [NOTIFY_PORT=n] enable-tunneld.sh [path to on-demand-tunnel-cf (default ~/on-demand-tunnel-cf)]
set -euo pipefail

src=${1:-$HOME/on-demand-tunnel-cf}
home=${TETHER_HOME:-$HOME/tether}
env_file=$home/tether.env
[ -f "$env_file" ] || { echo "no $env_file; install the hub first (see docs/operations/running.md)" >&2; exit 1; }
[ -f "$src/compose.yaml" ] || { echo "no compose.yaml in $src" >&2; exit 1; }

cd "$src"
[ -f .env ] || cp .env.example .env
if ! grep -q '^ADMIN_TOKEN=.' .env; then
  tok=$(openssl rand -hex 24)
  if grep -q '^ADMIN_TOKEN=' .env; then sed -i "s|^ADMIN_TOKEN=.*|ADMIN_TOKEN=$tok|" .env; else echo "ADMIN_TOKEN=$tok" >> .env; fi
  chmod 600 .env
fi
docker compose up -d --build
token=$(sed -n 's/^ADMIN_TOKEN=//p' .env | head -1)
port=$(sed -n 's/^PORT=//p' .env | head -1)
port=${port:-7171}

for _ in $(seq 1 20); do
  curl -fsS "http://127.0.0.1:$port/healthz" >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS "http://127.0.0.1:$port/healthz" >/dev/null || { echo "tunneld does not answer on port $port; see: docker compose logs" >&2; exit 1; }

cp -p "$env_file" "$env_file.pre-tunneld"
nport=${NOTIFY_PORT:-7421}
flag="-tunneld http://127.0.0.1:$port -notify-addr 0.0.0.0:$nport"
if grep -q -- '-tunneld' "$env_file"; then
  echo "tether.env already has -tunneld"
elif grep -q '^TETHER_HUB_FLAGS=' "$env_file"; then
  sed -i "s|^TETHER_HUB_FLAGS=\(.*\)$|TETHER_HUB_FLAGS=\1 $flag|" "$env_file"
else
  echo "TETHER_HUB_FLAGS=$flag" >> "$env_file"
fi
# deploy.sh sources this file, so a value with spaces needs quotes; systemd reads them too.
sed -i -E '/^TETHER_HUB_FLAGS=[^"]/ s/^TETHER_HUB_FLAGS=(.*)$/TETHER_HUB_FLAGS="\1"/' "$env_file"
if grep -q '^TETHER_TUNNELD_TOKEN=' "$env_file"; then
  sed -i "s|^TETHER_TUNNELD_TOKEN=.*|TETHER_TUNNELD_TOKEN=$token|" "$env_file"
else
  echo "TETHER_TUNNELD_TOKEN=$token" >> "$env_file"
fi

systemctl --user restart tether-hub
echo "waiting for the tunnel's address"
for _ in $(seq 1 40); do
  url=$(journalctl --user -u tether-hub --since "2 minutes ago" --no-pager 2>/dev/null | grep -o 'url=https://[a-z0-9-]*\.trycloudflare\.com' | tail -1 | cut -d= -f2 || true)
  if [ -n "$url" ]; then
    echo "the tunnel is up at $url (apps are told by themselves)"
    exit 0
  fi
  sleep 2
done
echo "no address after 80 s; look at: journalctl --user -u tether-hub -n 40, and docker compose logs" >&2
exit 1
