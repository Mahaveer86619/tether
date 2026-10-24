#!/usr/bin/env bash
# Tests deploy.sh in a sandbox: a temporary HOME, a hub on its own port, and
# stand-ins for systemctl, journalctl and loginctl that run the binaries
# directly. The real services are never touched. Needs Go and python3.
# Usage: deploy/linux/deploy_test.sh
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
sandbox=$(mktemp -d)
port=${TEST_PORT:-7498}
export HOME=$sandbox/home TETHER_HOME=$sandbox/home/tether
mkdir -p "$TETHER_HOME/bin" "$HOME/.config/systemd/user" "$sandbox/shims" "$sandbox/projects"
cleanup() {
  for pid in "$sandbox"/*.pid; do [ -f "$pid" ] && kill "$(cat "$pid")" 2>/dev/null || true; done
  rm -rf "$sandbox"
}
trap cleanup EXIT

cat > "$TETHER_HOME/tether.env" <<EOF
TETHER_TOKEN=test-token
TETHER_ADDR=127.0.0.1:$port
TETHER_HUB=ws://127.0.0.1:$port/ws
TETHER_NODE=sandbox
TETHER_HUB_FLAGS=
EOF

# systemctl --user start|stop|restart <units>: runs the binaries in bin/.
cat > "$sandbox/shims/systemctl" <<EOF
#!/usr/bin/env bash
[ "\$1" = --user ] && shift
if [[ " \$* " == *" status "* ]]; then echo "● sandbox"; echo "   Active: active (running)"; exit 0; fi
cmd=\$1; shift
for unit in "\$@"; do
  name=\${unit%.service}
  pid=$sandbox/\$name.pid
  case \$cmd in
  stop|restart)
    if [ -f "\$pid" ]; then kill "\$(cat "\$pid")" 2>/dev/null || true; rm -f "\$pid"; sleep 0.5; fi ;;
  esac
  case \$cmd in
  start|restart)
    case \$name in
    tether-hub) TETHER_TOKEN=test-token nohup "$TETHER_HOME/bin/tether-hub" -addr 127.0.0.1:$port -db "$TETHER_HOME/hub.db" -update-feed "" > "$sandbox/hub.log" 2>&1 & ;;
    tether-agent) TETHER_TOKEN=test-token nohup "$TETHER_HOME/bin/tether-agent" -hub ws://127.0.0.1:$port/ws -node sandbox -host headless \
        -hook-addr "" -hooks=false -mcp=false -self-update=false -claude /bin/true -projects "$sandbox/projects" -scratch-dir "$sandbox/scratch" > "$sandbox/agent.log" 2>&1 & ;;
    *) continue ;;
    esac
    echo \$! > "\$pid" ;;
  esac
done
exit 0
EOF
printf '#!/bin/sh\nexit 0\n' > "$sandbox/shims/journalctl"
printf '#!/bin/sh\necho yes\n' > "$sandbox/shims/loginctl"
chmod +x "$sandbox/shims"/*
export PATH=$sandbox/shims:$PATH

build() { # version dir
  mkdir -p "$2"
  (cd "$root/server" && for bin in tether-hub tether-agent tetherctl; do
    CGO_ENABLED=0 go build -ldflags "-X github.com/Mahaveer86619/tether/server/internal/version.Version=$1" -o "$2/$bin-linux-amd64" "./cmd/$bin"
  done)
  printf '{\n  "version": "%s",\n  "platforms": {}\n}\n' "$1" > "$2/latest.json"
}

hub_version() { curl -fsS -m 3 -H "Authorization: Bearer test-token" "http://127.0.0.1:$port/api/v1/state" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hubVersion"])'; }
fail() { echo "FAIL: $*" >&2; exit 1; }

echo "building 9.0.1 and 9.0.2"
build 9.0.1 "$sandbox/dist-old"
build 9.0.2 "$sandbox/dist-new"

# Start from 9.0.1, installed the way install.sh does it.
for b in tether-hub tether-agent tetherctl; do cp "$sandbox/dist-old/$b-linux-amd64" "$TETHER_HOME/bin/$b"; done
systemctl --user start tether-hub tether-agent
sleep 2
[ "$(hub_version)" = 9.0.1 ] || fail "the old hub didn't start"

echo "1. a good deploy"
"$root/deploy/linux/deploy.sh" "$sandbox/dist-new" > "$sandbox/deploy1.log" 2>&1 || { cat "$sandbox/deploy1.log"; fail "deploy failed"; }
[ "$(hub_version)" = 9.0.2 ] || fail "the hub isn't 9.0.2"
cmp -s "$TETHER_HOME/bin/tether-hub.prev" "$sandbox/dist-old/tether-hub-linux-amd64" || fail "no .prev of the old hub"
[ -f "$TETHER_HOME/updates/9.0.2/latest.json" ] || fail "the release isn't in the updates folder"
backup=$(ls -d "$TETHER_HOME"/backups/*-pre-9.0.2 | head -1)
[ -f "$backup/hub.db" ] && [ -x "$backup/rollback.sh" ] || fail "no backup"
grep -q "agent 9.0.2 is connected" "$sandbox/deploy1.log" || fail "the agent wasn't checked"

echo "2. rollback.sh puts the old version back, keeping the database"
"$backup/rollback.sh" > /dev/null
sleep 2
[ "$(hub_version)" = 9.0.1 ] || fail "rollback.sh didn't bring back 9.0.1"

echo "3. a hub that won't start is rolled back by itself"
mkdir -p "$sandbox/dist-broken"
cp "$sandbox/dist-new"/* "$sandbox/dist-broken"/
printf '#!/bin/sh\nexit 1\n' > "$sandbox/dist-broken/tether-hub-linux-amd64"
sed -i 's/9.0.2/9.0.3/' "$sandbox/dist-broken/latest.json"
if "$root/deploy/linux/deploy.sh" "$sandbox/dist-broken" > "$sandbox/deploy3.log" 2>&1; then
  fail "a broken hub deployed"
fi
grep -q "rolling back" "$sandbox/deploy3.log" || fail "no rollback message"
sleep 2
[ "$(hub_version)" = 9.0.1 ] || fail "not back on 9.0.1 after the failed deploy"
[ ! -d "$TETHER_HOME/updates/9.0.3" ] || fail "the failed release stayed in the updates folder"

echo "PASS"
