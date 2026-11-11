#!/usr/bin/env bash
# Writes appcast.xml for a release's dist folder: the feed the Windows app's
# updater (WinSparkle, through the auto_updater package) reads. It signs the
# installer with the private key and checks the signature against the public
# key built into the app, so a wrong or missing key stops the release rather
# than shipping an update nobody's app will accept.
#
# Usage: APPCAST_KEY=path/to/dsa_priv.pem appcast.sh dist/<version>
# Needs openssl. The installer is dist/<version>/Tether-Setup-<version>.exe.
# See docs/operations/releasing.md.
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
dist=$(cd "${1:?usage: APPCAST_KEY=dsa_priv.pem appcast.sh dist/<version>}" && pwd)
key=${APPCAST_KEY:?set APPCAST_KEY to the private key file}
v=$(tr -d ' \r\n' < "$root/VERSION")
code=$("$root/tools/release/version.sh" code)
pub=$root/app/dsa_pub.pem
installer=$dist/Tether-Setup-$v.exe
repo=${GITHUB_REPOSITORY:-Mahaveer86619/tether}
[ -f "$installer" ] || { echo "no $installer" >&2; exit 1; }

sig=$(openssl dgst -sha1 -binary < "$installer" | openssl dgst -sha1 -sign "$key" | openssl enc -base64 -A)
# The app's public key must verify what the private key signed.
printf '%s' "$sig" | openssl enc -base64 -d -A > "$dist/.sig.bin"
openssl dgst -sha1 -binary < "$installer" | openssl dgst -sha1 -verify "$pub" -signature "$dist/.sig.bin" > /dev/null \
  || { rm -f "$dist/.sig.bin"; echo "the private key does not match app/dsa_pub.pem" >&2; exit 1; }
rm -f "$dist/.sig.bin"

len=$(wc -c < "$installer" | tr -d ' ')
# This version's notes from CHANGELOG.md, as a short HTML list.
notes=$(awk -v h="## $v" '$0==h{f=1;next} /^## /{f=0} f' "$root/CHANGELOG.md" \
  | sed -e 's/\r$//' -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/^- \(.*\)$/<li>\1<\/li>/' -e 's/\*\*\([^*]*\)\*\*/<b>\1<\/b>/g' -e '/^$/d')
cat > "$dist/appcast.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Tether</title>
    <item>
      <title>Tether $v</title>
      <description><![CDATA[<ul>$notes</ul>]]></description>
      <pubDate>$(date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <enclosure url="https://github.com/$repo/releases/download/v$v/Tether-Setup-$v.exe"
                 sparkle:version="$v+$code"
                 sparkle:os="windows"
                 sparkle:dsaSignature="$sig"
                 sparkle:installerArguments="/SILENT"
                 length="$len"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF
echo "  appcast.xml"
