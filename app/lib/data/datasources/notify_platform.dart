import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';

/// The Android background service that asks the hub for news while the app is
/// closed (android/.../NotifyService.kt).
class AndroidNotify implements NotifyDevice {
  AndroidNotify({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('dev.tether/notify');

  final MethodChannel _channel;

  @override
  bool get available => Platform.isAndroid;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> configure({required bool enabled, required String token, required List<String> urls, required Set<NotifyKind> kinds}) =>
      _call<void>('configure', {'enabled': enabled, 'token': token, 'urls': urls, 'kinds': [for (final k in kinds) k.name]});

  @override
  Future<void> setActive(bool active) => _call<void>('setActive', {'active': active});

  @override
  Future<bool> permitted() async => await _call<bool>('permission') ?? false;

  @override
  Future<void> askPermission() => _call<void>('requestPermission');

  @override
  Future<NotifyStatus> status() async {
    final m = await _call<Map<Object?, Object?>>('status');
    if (m == null) return const NotifyStatus();
    final ok = (m['ok'] as num?)?.toInt() ?? 0;
    return NotifyStatus(
      running: m['enabled'] == true,
      lastOk: ok == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ok),
      error: '${m['error'] ?? ''}',
    );
  }
}

/// Where there is no background service: the desktop shows what the open app
/// receives and nothing more.
class NoNotify implements NotifyDevice {
  const NoNotify();

  @override
  bool get available => false;

  @override
  Future<void> configure({required bool enabled, required String token, required List<String> urls, required Set<NotifyKind> kinds}) async {}

  @override
  Future<void> setActive(bool active) async {}

  @override
  Future<bool> permitted() async => false;

  @override
  Future<void> askPermission() async {}

  @override
  Future<NotifyStatus> status() async => const NotifyStatus();
}
