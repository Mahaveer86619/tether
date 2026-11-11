import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';

/// Tailscale on a phone. The app can't switch it on or look inside it, so it
/// notices the VPN, asks Tailscale to connect through the intent it listens
/// for, and otherwise opens the Tailscale app for the owner. Whether the hub
/// answers is the real test; this only helps get there.
class AndroidTailscale implements TailscaleRepository {
  AndroidTailscale({Future<bool> Function()? vpnUp, MethodChannel? channel, this.wait = const Duration(seconds: 8), this.poll = const Duration(seconds: 1)})
      : _vpnUp = vpnUp ?? _connectivityHasVpn,
        _channel = channel ?? const MethodChannel('dev.tether/tailscale');

  final Future<bool> Function() _vpnUp;
  final MethodChannel _channel;
  final Duration wait, poll;

  static Future<bool> _connectivityHasVpn() async => (await Connectivity().checkConnectivity()).contains(ConnectivityResult.vpn);

  @override
  bool get canStart => false;

  Future<bool> _installed() async {
    try {
      return await _channel.invokeMethod<bool>('installed') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<TailscaleStatus> status() async {
    if (await _vpnUp()) return const TailscaleStatus(TailscaleState.running);
    if (!await _installed()) {
      return const TailscaleStatus(TailscaleState.notInstalled, message: "Tailscale isn't installed on this phone.");
    }
    return const TailscaleStatus(TailscaleState.stopped, message: 'Tailscale is off. Turn it on, then come back.');
  }

  @override
  Stream<TailscaleStatus> start() async* {
    final s = await status();
    yield s;
    if (s.state != TailscaleState.stopped) return;
    // Quietly ask Tailscale to connect; whether it listens depends on its version and settings.
    try {
      await _channel.invokeMethod<bool>('connect');
    } on PlatformException {
      // Fall through to the wait: the owner may switch it on by hand.
    } on MissingPluginException {
      return;
    }
    final until = DateTime.now().add(wait);
    while (DateTime.now().isBefore(until)) {
      await Future<void>.delayed(poll);
      if (await _vpnUp()) {
        yield const TailscaleStatus(TailscaleState.running);
        return;
      }
    }
    yield s;
  }

  @override
  Future<void> openApp() async {
    try {
      await _channel.invokeMethod<bool>('open');
    } on PlatformException {
      // Nothing to open.
    } on MissingPluginException {
      // Not on a phone.
    }
  }

  /// A phone's Tailscale app does not say who else is on the tailnet.
  @override
  Future<List<TailnetPeer>> peers() async => const [];
}

/// Where Tailscale can't be checked: iOS, the web, anything else.
class NoTailscale implements TailscaleRepository {
  const NoTailscale();

  @override
  bool get canStart => false;

  @override
  Future<TailscaleStatus> status() async => const TailscaleStatus(TailscaleState.unsupported);

  @override
  Stream<TailscaleStatus> start() => Stream.value(const TailscaleStatus(TailscaleState.unsupported));

  @override
  Future<void> openApp() async {}

  @override
  Future<List<TailnetPeer>> peers() async => const [];
}
