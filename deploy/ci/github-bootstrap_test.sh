#!/usr/bin/env bash
# Runs github-bootstrap.sh as a dry run and checks the calls it would make.
# Usage: deploy/ci/github-bootstrap_test.sh
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
key=$(mktemp)
trap 'rm -f "$key"' EXIT
printf 'not really a keystore' > "$key"

out=$(KEYSTORE_PASSWORD=pw "$here/github-bootstrap.sh" --dry-run --repo owner/tether --collaborator helper \
  --keystore "$key" --alias tether --register-runner --push 2>&1)

fail() { echo "FAIL: $*" >&2; echo "$out" >&2; exit 1; }
has() { grep -qF -- "$1" <<<"$out" || fail "missing: $1"; }

has 'DRY PUT /repos/owner/tether/collaborators/helper {"permission":"admin"}'
has 'DRY PUT /repos/owner/tether/branches/main/protection'
has '"contexts": ["server", "app"]'
has 'DRY GET /repos/owner/tether/rulesets'
has 'DRY POST /repos/owner/tether/rulesets'
has '"include": ["refs/tags/v*"]'
has 'DRY GET /users/owner'
has 'DRY PUT /repos/owner/tether/environments/minipc {"reviewers": [{"type": "User", "id": 1001}]}'
has 'DRY PUT /repos/owner/tether/actions/permissions/fork-pr-contributor-approval'
for s in ANDROID_KEYSTORE_BASE64 ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD; do has "DRY secret $s"; done
has 'DRY POST /repos/owner/tether/actions/runners/registration-token'
has 'DRY run'
has 'DRY git push origin main --follow-tags'
[ "$(grep -cE '^DRY (GET|PUT|POST) ' <<<"$out")" = 8 ] || fail "expected 8 API calls"
grep -q 'not really a keystore\|pw' <<<"$out" && fail "a secret value was printed"

# Without a token and not a dry run, it refuses before calling anything.
if GH_TOKEN= "$here/github-bootstrap.sh" --repo owner/tether 2>/dev/null; then
  fail "ran without a token"
fi
echo PASS
