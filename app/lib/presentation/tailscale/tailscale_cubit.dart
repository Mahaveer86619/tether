import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

/// Whether the hub's address is one that goes through Tailscale: a tailnet
/// address (100.64.0.0/10), a `.ts.net` name or a bare MagicDNS name. A hub on
/// the local network needs none of this.
bool isTailnetEndpoint(String endpoint) {
  if (endpoint.isEmpty) return false;
  final host = (Uri.tryParse(endpoint.contains('://') ? endpoint : 'ws://$endpoint')?.host ?? '').toLowerCase();
  if (host.isEmpty || host == 'localhost') return false;
  if (host.endsWith('.ts.net')) return true;
  final ip = RegExp(r'^100\.(\d{1,3})\.\d{1,3}\.\d{1,3}$').firstMatch(host);
  if (ip != null) {
    final second = int.parse(ip.group(1)!);
    return second >= 64 && second <= 127;
  }
  // A name without a dot is a MagicDNS short name, which only a tailnet resolves.
  return !host.contains('.') && !host.contains(':');
}

class TailscaleViewState extends Equatable {
  const TailscaleViewState({this.status = const TailscaleStatus(TailscaleState.unknown), this.busy = false, this.relevant = false, this.hubConnected = false});

  final TailscaleStatus status;

  /// Checking or starting Tailscale right now.
  final bool busy;

  /// The hub is on the tailnet, so Tailscale matters.
  final bool relevant;
  final bool hubConnected;

  /// Worth telling the owner about: the hub can't be reached, it is a tailnet
  /// hub, and Tailscale is being started or needs something from them.
  bool get visible {
    if (!relevant || hubConnected) return false;
    if (busy) return true;
    return switch (status.state) {
      TailscaleState.notInstalled || TailscaleState.serviceStopped || TailscaleState.stopped || TailscaleState.needsLogin || TailscaleState.starting => true,
      _ => false,
    };
  }

  TailscaleViewState copyWith({TailscaleStatus? status, bool? busy, bool? relevant, bool? hubConnected}) => TailscaleViewState(
        status: status ?? this.status,
        busy: busy ?? this.busy,
        relevant: relevant ?? this.relevant,
        hubConnected: hubConnected ?? this.hubConnected,
      );

  @override
  List<Object?> get props => [status, busy, relevant, hubConnected];
}

/// Looks after Tailscale in the background: when the hub is on the tailnet and
/// can't be reached, it checks Tailscale and brings it up where the device
/// lets it (a desktop can; a phone is asked, then the owner is pointed at the
/// app), and tells the hub connection to try again once it's up.
class TailscaleCubit extends Cubit<TailscaleViewState> {
  TailscaleCubit({
    required this._ensure,
    required WatchHub watchHub,
    required this._retryHub,
    this.grace = const Duration(seconds: 4),
    this.minGap = const Duration(seconds: 45),
  }) : super(const TailscaleViewState()) {
    _sub = watchHub().listen(_onHub);
  }

  final EnsureTailscale _ensure;
  final RetryConnection _retryHub;

  /// How long the hub may stay unreachable before Tailscale is looked at, and
  /// the least time between two attempts.
  final Duration grace, minGap;
  late final StreamSubscription<HubSnapshot> _sub;
  Timer? _timer;
  DateTime? _lastRun;

  bool get canStart => _ensure.canStart;

  void _onHub(HubSnapshot hub) {
    final relevant = isTailnetEndpoint(hub.endpoint);
    emit(state.copyWith(relevant: relevant, hubConnected: hub.connected));
    if (hub.connected || !relevant) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null || state.busy) return;
    final since = _lastRun == null ? minGap : DateTime.now().difference(_lastRun!);
    final wait = since >= minGap ? grace : minGap - since;
    _timer = Timer(wait < grace ? grace : wait, () {
      _timer = null;
      ensure();
    });
  }

  /// Checks Tailscale and brings it up if it isn't. [force] does so even when
  /// the hub isn't on the tailnet, for the owner's Try again.
  Future<void> ensure({bool force = false}) async {
    if (state.busy || isClosed) return;
    if (!force && (!state.relevant || state.hubConnected)) return;
    _lastRun = DateTime.now();
    emit(state.copyWith(busy: true));
    var last = await _ensure.check();
    if (isClosed) return;
    emit(state.copyWith(status: last));
    if (!last.running && last.state != TailscaleState.notInstalled && last.state != TailscaleState.unsupported) {
      await for (final s in _ensure.start()) {
        if (isClosed) return;
        last = s;
        emit(state.copyWith(status: s));
      }
    }
    if (isClosed) return;
    emit(state.copyWith(busy: false));
    // Tailscale is up: don't wait for the hub connection's own backoff.
    if (last.running && !state.hubConnected) _retryHub();
  }

  Future<void> retry() => ensure(force: true);

  Future<void> openApp() => _ensure.openApp();

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _sub.cancel();
    return super.close();
  }
}
