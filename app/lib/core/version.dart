/// This app's version, sent to the hub so the devices screen can show
/// which apps need an update. Keep in step with pubspec.yaml.
const appVersion = '0.17.7';

/// Where releases are published. The apps look here first, so a release does
/// not depend on the hub being reachable; the hub's own copy is the fallback.
const githubRepository = 'Mahaveer86619/tether';
const releaseDownloads = 'https://github.com/$githubRepository/releases/latest/download';

/// The Windows updater's feed: an appcast signed with the key built into the app.
const appcastUrl = '$releaseDownloads/appcast.xml';

/// The release manifest the other platforms read.
const releaseFeedUrl = '$releaseDownloads/latest.json';

/// Whether [version] is older than [than] (dotted numbers like 0.14.2).
/// Builds without a release number ("dev", "") are never called out.
bool isOlderVersion(String version, String than) {
  List<int>? parts(String v) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(v.trim());
    return m == null ? null : [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
  }

  final a = parts(version), b = parts(than);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return false;
}
