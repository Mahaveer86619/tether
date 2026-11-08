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

  /// Hands the unpacking to tether-updater.exe, a small program that ships
  /// next to the app: it waits for this process to exit, swaps the app's
  /// folder for the update, starts the new app and goes back to the old one
  /// if the new one does not come up. It runs from a copy in the temp folder,
  /// since it replaces the folder it lives in.
  Future<void> _applyOnExit(File zip) async {
    final app = File(Platform.resolvedExecutable).parent;
    final updater = File('${app.path}${Platform.pathSeparator}$updaterName');
    if (!await updater.exists()) {
      throw const StorageException('this install has no updater; install the new version once by hand');
    }
    final work = await Directory.systemTemp.createTemp('tether-update-');
    final copy = await updater.copy('${work.path}${Platform.pathSeparator}$updaterName');
    final sep = Platform.pathSeparator;
    await Process.start(
      copy.path,
      updaterArguments(zip: zip.path, app: app.path, appPid: pid, log: '${zip.parent.path}${sep}apply-update.log', ok: '${zip.parent.path}${sep}update-ok'),
      mode: ProcessStartMode.detached,
    );
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

const updaterName = 'tether-updater.exe';

/// The updater's command line.
List<String> updaterArguments({required String zip, required String app, required int appPid, required String log, required String ok}) =>
    ['-zip', zip, '-app', app, '-pid', '$appPid', '-log', log, '-ok', ok];
