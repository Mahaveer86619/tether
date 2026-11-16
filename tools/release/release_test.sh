#!/usr/bin/env bash
# Tests for the helpers in release.sh that need no GitHub: version order, the
# next version, and putting a release's notes into the changelog.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
RELEASE_LIB=1 . "$here/release.sh"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got [$2] want [$3]"; fail=1; fi; }
yes_no() { if "$@"; then echo yes; else echo no; fi; }

check "a patch is newer"            "$(yes_no version_gt 0.18.2 0.18.1)" yes
check "a minor beats a larger patch" "$(yes_no version_gt 0.19.0 0.18.9)" yes
check "ten is more than nine"       "$(yes_no version_gt 0.17.10 0.17.9)" yes
check "the same is not newer"       "$(yes_no version_gt 0.18.1 0.18.1)" no
check "older is not newer"          "$(yes_no version_gt 0.17.9 0.18.0)" no

check "next patch" "$(next_version 0.18.1 patch)" 0.18.2
check "next minor resets the patch" "$(next_version 0.18.7 minor)" 0.19.0
check "next major" "$(next_version 0.18.7 major)" 1.0.0
check "an unknown kind fails" "$(yes_no next_version 0.1.0 huge)" no

tmp=$(mktemp -d)
printf '# Changelog\r\n\r\nIntro line.\r\n\r\n## 0.18.0\r\n\r\n- **Old.** Old text.\r\n' > "$tmp/CHANGELOG.md"
printf -- '- **New.** New text.\n- Another.\n' > "$tmp/notes"
insert_notes "$tmp/CHANGELOG.md" 0.18.1 "$tmp/notes"
check "the new section is above the newest" "$(grep -n '^## ' "$tmp/CHANGELOG.md" | tr '\n' ' ')" "5:## 0.18.1 10:## 0.18.0 "
check "the intro is kept" "$(sed -n 3p "$tmp/CHANGELOG.md")" "Intro line."
check "the bullets are in" "$(sed -n 7,8p "$tmp/CHANGELOG.md" | tr '\n' '|')" "- **New.** New text.|- Another.|"
check "no carriage returns are left" "$(tr -cd '\r' < "$tmp/CHANGELOG.md" | wc -c | tr -d ' ')" 0
rm -rf "$tmp"
exit $fail
