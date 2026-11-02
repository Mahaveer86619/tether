#!/usr/bin/env bash
# Sets up the GitHub side of Tether's releases in one go, idempotently:
#   - a collaborator with admin rights (the account the machines push as)
#   - branch protection on main: pull requests, the ci checks, linear history
#   - a ruleset so only admins create, move or delete v* tags
#   - the minipc environment, with the owner as required reviewer
#   - approval required for workflows from outside contributors
#   - the Android signing secrets (through the gh CLI, which encrypts them)
#   - optionally: register the self-hosted runner, push main and the tags
# Needs GH_TOKEN: a token with admin rights on the repository (the owner's).
# See docs/GITHUB-SETUP.md.
#
# Usage: GH_TOKEN=... deploy/ci/github-bootstrap.sh [options]
#   --repo OWNER/NAME          default Mahaveer86619/tether
#   --collaborator LOGIN       add this account as admin (e.g. MahaveerPanigrahi86619)
#   --reviewer LOGIN           who approves deploys (default: the repo owner)
#   --keystore FILE --alias A  upload the Android signing secrets; the
#                              passwords come from KEYSTORE_PASSWORD and KEY_PASSWORD
#   --register-runner          on the hub's machine: fetch a runner token and run setup-runner.sh
#   --push                     push main and the v* tags to origin
#   --dry-run                  print what would be done; no token needed
set -euo pipefail

repo=Mahaveer86619/tether
collaborator=""
reviewer=""
keystore=""
alias_name=""
register=0
push=0
dry=${DRY_RUN:-0}
while [ $# -gt 0 ]; do
  case $1 in
  --repo) repo=$2; shift 2 ;;
  --collaborator) collaborator=$2; shift 2 ;;
  --reviewer) reviewer=$2; shift 2 ;;
  --keystore) keystore=$2; shift 2 ;;
  --alias) alias_name=$2; shift 2 ;;
  --register-runner) register=1; shift ;;
  --push) push=1; shift ;;
  --dry-run) dry=1; shift ;;
  *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
owner=${repo%%/*}
reviewer=${reviewer:-$owner}
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
api_base=${GITHUB_API:-https://api.github.com}

if [ "$dry" != 1 ] && [ -z "${GH_TOKEN:-}" ]; then
  echo "GH_TOKEN is not set: it needs admin rights on $repo (see docs/GITHUB-SETUP.md)" >&2
  exit 1
fi

# api METHOD PATH [JSON]: prints the response body; in a dry run, prints the
# call and answers GETs with the canned body from DRY_RUN_REPLY_<n> if set.
api() {
  local method=$1 path=$2 body=${3:-}
  if [ "$dry" = 1 ]; then
    echo "DRY $method $path ${body}" >&2
    case $path in
    /users/*) echo '{"id": 1001, "login": "dry"}' ;;
    */rulesets) echo '[]' ;;
    */registration-token) echo '{"token": "DRYTOKEN"}' ;;
    *) echo '{}' ;;
    esac
    return 0
  fi
  local args=(-fsS -X "$method" -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")
  [ -n "$body" ] && args+=(-d "$body")
  curl "${args[@]}" "$api_base$path"
}

json_field() { python3 -c 'import json,sys; v=json.load(sys.stdin); print(v.get(sys.argv[1], "") if isinstance(v, dict) else "")' "$1"; }

step() { echo "== $*"; }

if [ -n "$collaborator" ]; then
  step "collaborator $collaborator (admin)"
  api PUT "/repos/$repo/collaborators/$collaborator" '{"permission":"admin"}' >/dev/null
  echo "   $collaborator gets an invitation to accept, unless already a collaborator"
fi

step "branch protection on main"
api PUT "/repos/$repo/branches/main/protection" '{
  "required_status_checks": {"strict": true, "contexts": ["server", "app"]},
  "enforce_admins": false,
  "required_pull_request_reviews": {"required_approving_review_count": 0},
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}' >/dev/null

step "release tag ruleset (v*: admins only)"
ruleset='{
  "name": "release tags",
  "target": "tag",
  "enforcement": "active",
  "conditions": {"ref_name": {"include": ["refs/tags/v*"], "exclude": []}},
  "rules": [{"type": "creation"}, {"type": "update"}, {"type": "deletion"}],
  "bypass_actors": [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}]
}'
existing=$(api GET "/repos/$repo/rulesets" | python3 -c 'import json,sys
for r in json.load(sys.stdin):
    if r.get("name") == "release tags": print(r["id"])')
if [ -n "$existing" ]; then
  api PUT "/repos/$repo/rulesets/$existing" "$ruleset" >/dev/null
else
  api POST "/repos/$repo/rulesets" "$ruleset" >/dev/null
fi

step "environment minipc (reviewer: $reviewer)"
reviewer_id=$(api GET "/users/$reviewer" | json_field id)
api PUT "/repos/$repo/environments/minipc" "{\"reviewers\": [{\"type\": \"User\", \"id\": $reviewer_id}]}" >/dev/null

step "workflows from outside contributors need approval"
api PUT "/repos/$repo/actions/permissions/fork-pr-contributor-approval" '{"approval_policy": "all_external_contributors"}' >/dev/null

if [ -n "$keystore" ]; then
  step "Android signing secrets"
  [ -n "$alias_name" ] || { echo "--keystore needs --alias" >&2; exit 2; }
  [ -n "${KEYSTORE_PASSWORD:-}" ] || { echo "set KEYSTORE_PASSWORD (and KEY_PASSWORD if it differs)" >&2; exit 2; }
  set_secret() {
    if [ "$dry" = 1 ]; then
      echo "DRY secret $1" >&2
    else
      gh secret set "$1" --repo "$repo" --body "$2" >/dev/null
    fi
  }
  set_secret ANDROID_KEYSTORE_BASE64 "$(base64 -w0 "$keystore")"
  set_secret ANDROID_KEYSTORE_PASSWORD "$KEYSTORE_PASSWORD"
  set_secret ANDROID_KEY_ALIAS "$alias_name"
  set_secret ANDROID_KEY_PASSWORD "${KEY_PASSWORD:-$KEYSTORE_PASSWORD}"
fi

if [ $register = 1 ]; then
  step "self-hosted runner"
  token=$(api POST "/repos/$repo/actions/runners/registration-token" | json_field token)
  if [ "$dry" = 1 ]; then
    echo "DRY run $here/setup-runner.sh --token <token>" >&2
  else
    REPO=$repo "$here/setup-runner.sh" --token "$token"
  fi
fi

if [ $push = 1 ]; then
  step "push main and tags"
  if [ "$dry" = 1 ]; then
    echo "DRY git push origin main --follow-tags" >&2
  else
    git -C "$root" push origin main
    git -C "$root" push origin --tags
  fi
fi

echo done
