import 'dart:io';

import 'package:auto_updater/auto_updater.dart';

import '../../core/version.dart';
import '../../domain/repositories/repositories.dart';

/// Windows updates through WinSparkle (the auto_updater package). It reads the
/// appcast on GitHub, checks the installer's signature against the public key
/// built into the app, runs the installer and restarts the app. It shows its
/// own dialogs, so the app has no banner for it.
class WinSparkleUpdater with UpdaterListener implements DesktopUpdater {
  WinSparkleUpdater({this.every = const Duration(hours: 6), void Function()? quit}) : _quit = quit ?? (() => exit(0));

  final Duration every;
  final void Function() _quit;
  bool _started = false;

  @override
  bool get available => Platform.isWindows;

  @override
  Future<void> start() async {
    if (!available || _started) return;
    _started = true;
    autoUpdater.addListener(this);
    await autoUpdater.setFeedURL(appcastUrl);
    await autoUpdater.setScheduledCheckInterval(every.inSeconds);
  }

  @override
  Future<void> checkNow() async {
    if (!available) return;
    await start();
    await autoUpdater.checkForUpdates();
  }

  /// WinSparkle is about to run the installer, which replaces the files this
  /// app is running from: leave.
  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? appcastItem) => _quit();

  @override
  void onUpdaterError(UpdaterError? error) {}

  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) {}

  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) {}

  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) {}

  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {}
}

/// Where the platform has no updater of its own.
class NoDesktopUpdater implements DesktopUpdater {
  const NoDesktopUpdater();

  @override
  bool get available => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> checkNow() async {}
}
