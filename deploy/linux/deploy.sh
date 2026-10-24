#!/usr/bin/env bash
# Deploys a release on the hub's machine:
#   1. backs up hub.db and the current binaries (also kept as .prev) and
#      writes a rollback.sh next to the backup;
#   2. installs the hub, agent and tetherctl and restarts them;
#   3. puts the release in the hub's updates folder, so apps and other
#      agents can update from it;
#   4. checks the hub answers with the new version, and the agent
#      reconnects with it, and rolls back on its own if either doesn't.
# Usage: deploy.sh <dist-dir> [--no-agent]
# The dist folder is what tools/release/build.sh makes. See docs/releasing.md.
set -euo pipefail

dist=$(cd "${1:?usage: deploy.sh <dist-dir> [--no-agent]}" && pwd)
roles=(hub agent)
[ "${2:-}" = --no-agent ] && roles=(hub)
here=$(cd "$(dirname "$0")" && pwd)
home=${TETHER_HOME:-$HOME/tether}
env_file=$home/tether.env

[ -f "$env_file" ] || { echo "no $env_file; install once with deploy/linux/install.sh first" >&2; exit 1; }
[ -f "$dist/latest.json" ] || { echo "no latest.json in $dist" >&2; exit 1; }
v=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$dist/latest.json" | head -1)
[ -n "$v" ] || { echo "no version in $dist/latest.json" >&2; exit 1; }
set -a
# shellcheck disable=SC1090
. "$env_file"
set +a

scheme=http
curl_tls=()
case "${TETHER_HUB:-}" in wss://*) scheme=https; curl_tls=(-k) ;; esac
base=$scheme://${TETHER_ADDR}

# Binaries under the names install.sh expects.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp "$dist/tether-hub-linux-amd64" "$stage/tether-hub"
cp "$dist/tether-agent-linux-amd64" "$stage/tether-agent"
cp "$dist/tetherctl-linux-amd64" "$stage/tetherctl"
chmod 755 "$stage"/*

backup=$home/backups/$(date +%Y%m%d-%H%M%S)-pre-$v
mkdir -p "$backup"
chmod 700 "$backup"
echo "deploying $v; backup in $backup"

systemctl --user stop tether-hub tether-agent
cp -p "$home"/hub.db* "$backup"/ 2>/dev/null || true
for b in tether-hub tether-agent tetherctl; do
  if [ -f "$home/bin/$b" ]; then
    cp -p "$home/bin/$b" "$backup/"
    cp -p "$home/bin/$b" "$home/bin/$b.prev"
  fi
done
cp -p "$HOME/.config/systemd/user/tether-hub.service" "$HOME/.config/systemd/user/tether-agent.service" "$backup/" 2>/dev/null || true

cat > "$backup/rollback.sh" <<EOF
#!/usr/bin/env bash
# Puts back what was running before $v was deployed.
set -euo pipefail
systemctl --user stop tether-hub tether-agent
for b in tether-hub tether-agent tetherctl; do
  [ -f "$backup/\$b" ] && cp -p "$backup/\$b" "$home/bin/\$b"
done
cp -p "$backup"/hub.db* "$home"/ 2>/dev/null || true
for u in tether-hub.service tether-agent.service; do
  [ -f "$backup/\$u" ] && cp -p "$backup/\$u" "\$HOME/.config/systemd/user/\$u"
done
systemctl --user daemon-reload
systemctl --user start tether-hub tether-agent
echo "rolled back to what ran before $v"
EOF
chmod 700 "$backup/rollback.sh"

"$here/install.sh" "$stage" "${roles[@]}" >/dev/null

# The release goes in the updates folder only now, so a rollback leaves
# no newer release for the old hub to hand out.
updates=$home/updates/$v
mkdir -p "$updates"
cp "$dist"/* "$updates"/

state() { curl -fsS "${curl_tls[@]}" -m 5 -H "Authorization: Bearer $TETHER_TOKEN" "$base/api/v1/state" 2>/dev/null; }
# protojson spaces its output unpredictably, so read it as JSON.
hub_is() { state | python3 -c 'import json,sys; sys.exit(json.load(sys.stdin).get("hubVersion") != sys.argv[1])' "$1"; }
agent_is() {
  state | python3 -c 'import json,sys
n = [n for n in json.load(sys.stdin).get("nodes", []) if n.get("node") == sys.argv[1]]
sys.exit(not (n and n[0].get("online") and n[0].get("agentVersion") == sys.argv[2]))' "$1" "$2"
}

hub_ok=0
for _ in $(seq 1 30); do
  if curl -fsS "${curl_tls[@]}" -m 3 "$base/healthz" >/dev/null 2>&1 && hub_is "$v"; then
    hub_ok=1
    break
  fi
  sleep 2
done
if [ $hub_ok -ne 1 ]; then
  echo "the hub didn't come up as $v within a minute; rolling back" >&2
  journalctl --user -u tether-hub -n 30 --no-pager >&2 || true
  rm -rf "$updates"
  bash "$backup/rollback.sh"
  exit 1
fi
echo "hub $v is up"

if [ "${roles[*]}" = "hub agent" ]; then
  agent_ok=0
  for _ in $(seq 1 30); do
    if agent_is "$TETHER_NODE" "$v"; then
      agent_ok=1
      break
    fi
    sleep 2
  done
  if [ $agent_ok -ne 1 ]; then
    echo "the agent didn't reconnect as $v within a minute; putting the previous agent back" >&2
    journalctl --user -u tether-agent -n 30 --no-pager >&2 || true
    cp -p "$home/bin/tether-agent.prev" "$home/bin/tether-agent"
    systemctl --user restart tether-agent
    exit 1
  fi
  echo "agent $v is connected"
fi
echo "deployed $v. To undo: $backup/rollback.sh"
