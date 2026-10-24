#!/usr/bin/env bash
# Sets up the hub's machine to build and deploy Tether by itself: Go,
# a JDK, the Android SDK and Flutter under ~/ci (nothing system-wide), and
# a self-hosted GitHub Actions runner as a systemd user service.
#
# Usage: setup-runner.sh                       install or update the toolchains
#        setup-runner.sh --token TOKEN         also register the runner
#        setup-runner.sh --keystore FILE.jks   also set up APK signing for `make dist`
# TOKEN is a runner registration token: repo Settings > Actions > Runners >
# New self-hosted runner, or `gh api -X POST repos/OWNER/tether/actions/runners/registration-token`.
# See docs/releasing.md.
set -euo pipefail

ci=${CI_HOME:-$HOME/ci}
repo=${REPO:-Mahaveer86619/tether}
go_version=${GO_VERSION:-1.27.1}
flutter_version=${FLUTTER_VERSION:-3.47.7}
android_platform=${ANDROID_PLATFORM:-android-36}
build_tools=${ANDROID_BUILD_TOOLS:-36.0.0}
cmdline_tools=${ANDROID_CMDLINE_TOOLS:-13114758}
token=""
keystore=""
while [ $# -gt 0 ]; do
  case $1 in
  --token) token=$2; shift 2 ;;
  --keystore) keystore=$2; shift 2 ;;
  *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$ci"
for tool in curl tar unzip git xz; do
  command -v $tool >/dev/null || { echo "needs $tool: sudo apt-get install -y $tool" >&2; exit 1; }
done

fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }

if [ "$("$ci/go/bin/go" version 2>/dev/null | awk '{print $3}')" != "go$go_version" ]; then
  echo "Go $go_version"
  rm -rf "$ci/go"
  fetch "https://go.dev/dl/go$go_version.linux-amd64.tar.gz" "$ci/go.tgz"
  tar -C "$ci" -xzf "$ci/go.tgz" && rm "$ci/go.tgz"
fi

if [ ! -x "$ci/jdk/bin/java" ]; then
  echo "JDK 17"
  fetch "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse" "$ci/jdk.tgz"
  mkdir -p "$ci/jdk" && tar -C "$ci/jdk" --strip-components=1 -xzf "$ci/jdk.tgz" && rm "$ci/jdk.tgz"
fi
export JAVA_HOME=$ci/jdk

sdk=$ci/android-sdk
if [ ! -x "$sdk/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "Android command-line tools"
  fetch "https://dl.google.com/android/repository/commandlinetools-linux-${cmdline_tools}_latest.zip" "$ci/cmdline-tools.zip"
  mkdir -p "$sdk/cmdline-tools" && unzip -q -o "$ci/cmdline-tools.zip" -d "$sdk/cmdline-tools"
  rm -rf "$sdk/cmdline-tools/latest" && mv "$sdk/cmdline-tools/cmdline-tools" "$sdk/cmdline-tools/latest" && rm "$ci/cmdline-tools.zip"
fi
yes | "$sdk/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$sdk" --licenses >/dev/null || true
"$sdk/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$sdk" "platform-tools" "platforms;$android_platform" "build-tools;$build_tools" >/dev/null

if [ ! -d "$ci/flutter" ]; then
  echo "Flutter $flutter_version"
  git clone --quiet --depth 1 --branch "$flutter_version" https://github.com/flutter/flutter.git "$ci/flutter"
elif [ "$(git -C "$ci/flutter" describe --tags 2>/dev/null)" != "$flutter_version" ]; then
  echo "Flutter $flutter_version"
  git -C "$ci/flutter" fetch --quiet --depth 1 origin tag "$flutter_version"
  git -C "$ci/flutter" checkout --quiet "$flutter_version"
fi

# The environment builds run with: the runner reads .env and .path from its
# folder, and `make` gets the same through ci-env.sh.
cat > "$ci/ci-env.sh" <<EOF
export PATH=$ci/go/bin:$ci/flutter/bin:$ci/jdk/bin:$sdk/platform-tools:$ci/gopath/bin:\$PATH
export JAVA_HOME=$ci/jdk
export ANDROID_HOME=$sdk
export ANDROID_SDK_ROOT=$sdk
export GOPATH=$ci/gopath
export GOMODCACHE=$ci/gopath/pkg/mod
export GOCACHE=$ci/go-build
export PUB_CACHE=$ci/pub-cache
export GRADLE_USER_HOME=$ci/gradle
EOF
# shellcheck disable=SC1091
. "$ci/ci-env.sh"
mkdir -p "$GRADLE_USER_HOME"
# The machine has ~7 GB and runs other services: the app's gradle.properties
# asks for 8 GB, which this (user-level, so it wins) replaces.
cat > "$GRADLE_USER_HOME/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=1g
org.gradle.daemon=false
org.gradle.workers.max=2
kotlin.daemon.jvmargs=-Xmx1g
EOF
flutter config --no-analytics >/dev/null
flutter config --android-sdk "$sdk" >/dev/null
flutter precache --android >/dev/null
flutter doctor --android-licenses >/dev/null 2>&1 <<<"$(yes)" || true

if [ -n "$keystore" ]; then
  # For `make dist` by hand; CI writes its own from GitHub secrets.
  mkdir -p "$ci/signing" && chmod 700 "$ci/signing"
  cp "$keystore" "$ci/signing/release.jks" && chmod 600 "$ci/signing/release.jks"
  read -r -p "Keystore password: " -s store_pw; echo
  read -r -p "Key alias: " alias
  read -r -p "Key password (empty: same as the keystore): " -s key_pw; echo
  cat > "$ci/signing/key.properties" <<EOF
storeFile=$ci/signing/release.jks
storePassword=$store_pw
keyAlias=$alias
keyPassword=${key_pw:-$store_pw}
EOF
  chmod 600 "$ci/signing/key.properties"
  echo "signing set up; link it into a checkout with: ln -sf $ci/signing/key.properties app/android/key.properties"
fi

runner=$ci/runner
if [ ! -x "$runner/run.sh" ]; then
  echo "GitHub Actions runner"
  rv=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')
  mkdir -p "$runner"
  fetch "https://github.com/actions/runner/releases/download/v$rv/actions-runner-linux-x64-$rv.tar.gz" "$ci/runner.tgz"
  tar -C "$runner" -xzf "$ci/runner.tgz" && rm "$ci/runner.tgz"
fi
{
  grep -v '^#' "$ci/ci-env.sh" | sed 's/^export //' | grep -v '^PATH='
} > "$runner/.env"
echo "$PATH" > "$runner/.path"

if [ -n "$token" ]; then
  (cd "$runner" && ./config.sh --unattended --replace --url "https://github.com/$repo" --token "$token" \
    --name "$(hostname)-tether" --labels tether,minipc --work _work)
fi

if [ -f "$runner/.runner" ]; then
  mkdir -p "$HOME/.config/systemd/user"
  sed "s#@RUNNER@#$runner#g" "$(dirname "$0")/tether-ci-runner.service" > "$HOME/.config/systemd/user/tether-ci-runner.service"
  systemctl --user daemon-reload
  systemctl --user enable --now tether-ci-runner.service
  systemctl --user --no-pager status tether-ci-runner.service | grep -E "●|Active:"
else
  echo "toolchains ready in $ci. Register the runner with: $0 --token <registration token>"
fi
