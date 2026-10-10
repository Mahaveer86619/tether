#!/usr/bin/env bash
# Installs tether-hub and/or tether-agent as systemd user services.
# Usage: install.sh <dir-with-binaries> [hub] [agent]
set -euo pipefail

src=${1:?usage: install.sh <dir-with-binaries> [hub] [agent]}
shift
roles=("$@")
[ ${#roles[@]} -eq 0 ] && roles=(hub agent)

here=$(cd "$(dirname "$0")" && pwd)
mkdir -p ~/tether/bin ~/.config/systemd/user

if [ ! -f ~/tether/tether.env ]; then
  cp "$here/tether.env.example" ~/tether/tether.env
  chmod 600 ~/tether/tether.env
  echo "Created ~/tether/tether.env; set TETHER_TOKEN and addresses, then rerun." >&2
  exit 1
fi

for role in "${roles[@]}"; do
  install -m 755 "$src/tether-$role" ~/tether/bin/
  cp "$here/tether-$role.service" ~/.config/systemd/user/
done
[ -f "$src/tetherctl" ] && install -m 755 "$src/tetherctl" ~/tether/bin/

systemctl --user daemon-reload
for role in "${roles[@]}"; do
  systemctl --user enable "tether-$role.service"
  systemctl --user restart "tether-$role.service"
done

if [ "$(loginctl show-user "$USER" -p Linger --value)" != "yes" ]; then
  echo "Note: run 'sudo loginctl enable-linger $USER' so the services keep running after you log out." >&2
fi
systemctl --user --no-pager status "${roles[@]/#/tether-}" | grep -E "●|Active:"
