import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/error/exceptions.dart';

/// What installing an update takes on this device: Android hands the APK to
/// the system installer; Windows swaps the app folder after the app exits.
abstract interface class UpdatePlatform {
  /// The release's key for this platform's app (android, windows), or
  /// null where the app can't update itself.
  String? get key;

  /// Where downloads wait to be installed.
  Future<Directory> downloads();

  /// Starts installing [file]. On Windows the app must exit right after.
  Future<void> install(File file);

  /// A system notification, where the platform has them.
  Future<void> notify(String title, String body);
}

class NativeUpdatePlatform implements UpdatePlatform {
  static const _channel = MethodChannel('dev.tether/update');

  @override
  String? get key => Platform.isAndroid ? 'android' : (Platform.isWindows ? 'windows' : null);

  @override
  Future<Directory> downloads() async {
    // Android's FileProvider shares the cache's updates/ folder with the installer.
    final base = Platform.isAndroid ? await getTemporaryDirectory() : await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}updates').create(recursive: true);
  }

  @override
  Future<void> install(File file) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('installApk', {'path': file.path});
      } on PlatformException catch (e) {
        throw StorageException(e.message ?? e.code);
      }
      return;
    }
    if (Platform.isWindows) return _applyOnExit(file);
    throw const StorageException('this platform updates through its package manager');
  }

  /// Writes a helper that waits for the app to exit, swaps its folder for
  /// the update (keeping the old one as `<folder>.prev`, and putting it back
  /// if the copy fails), and starts the app again.
  Future<void> _applyOnExit(File zip) async {
    final app = File(Platform.resolvedExecutable).parent;
    final script = File('${zip.parent.path}\\apply-update.ps1');
    await script.writeAsString(windowsHelperScript(zip: zip.path, app: app.path, appPid: pid));
    await Process.start('cmd.exe', windowsHelperLaunch(script.path), mode: ProcessStartMode.detached);
  }

  @override
  Future<void> notify(String title, String body) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('notify', {'title': title, 'body': body});
    } on PlatformException {
      // No permission to notify: the banner still shows in the app.
    }
  }
}

const _windowsHelper = r'''
$ErrorActionPreference = 'Stop'
$log = Join-Path (Split-Path $Zip) 'apply-update.log'
function Note($m) { Add-Content -Path $log -Value "$(Get-Date -Format s) $m" }
try {
    Wait-Process -Id $AppPid -Timeout 60 -ErrorAction SilentlyContinue
    $staging = "$App.new"
    $prev = "$App.prev"
    Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $Zip -DestinationPath $staging -Force
    if (-not (Test-Path (Join-Path $staging 'tether.exe'))) { throw 'the update has no tether.exe' }
    Remove-Item $prev -Recurse -Force -ErrorAction SilentlyContinue
    # Windows can hold the old DLLs for a moment after the app exits.
    foreach ($try in 1..20) {
        try { Rename-Item $App $prev; break } catch { if ($try -eq 20) { throw }; Start-Sleep -Milliseconds 500 }
    }
    try { Rename-Item $staging $App }
    catch { Rename-Item $prev $App; throw }
    Note "updated from $Zip"
    Remove-Item $Zip -Force -ErrorAction SilentlyContinue
}
catch { Note "update failed: $_" }
Start-Process (Join-Path $App 'tether.exe')
''';

String _quoted(String v) => "'${v.replaceAll("'", "''")}'";

/// The helper with its three values written in, so nothing depends on how
/// the arguments survive being passed on.
String windowsHelperScript({required String zip, required String app, required int appPid}) =>
    '\$Zip = ${_quoted(zip)}\n\$App = ${_quoted(app)}\n\$AppPid = $appPid\n$_windowsHelper';

/// How to start the helper so it outlives the app. PowerShell started
/// straight from a detached process never runs; going through `cmd start`
/// does, and `-WindowStyle Hidden` keeps it from showing.
List<String> windowsHelperLaunch(String script) =>
    ['/c', 'start', '', '/b', 'powershell.exe', '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', script];
