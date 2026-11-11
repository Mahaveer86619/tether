import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/error/exceptions.dart';

/// What installing an update takes on this device: Android hands the APK to
/// the system installer; Windows has an updater of its own.
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
  // Windows updates through WinSparkle (see desktop_updater.dart), not through this.
  String? get key => Platform.isAndroid ? 'android' : null;

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
    throw const StorageException('this platform updates through its own updater');
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
