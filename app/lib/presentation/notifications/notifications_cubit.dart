import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class NotificationsState extends Equatable {
  const NotificationsState({
    this.loaded = false,
    this.available = false,
    this.settings = const NotifySettings(),
    this.permitted = false,
    this.status = const NotifyStatus(),
    this.tunnel = '',
    this.busy = false,
    this.notice = '',
    this.noticeId = 0,
    this.failure,
    this.failureId = 0,
  });

  final bool loaded, available, permitted, busy;
  final NotifySettings settings;
  final NotifyStatus status;

  /// The hub's tunnel address; empty when it has none.
  final String tunnel;
  final String notice;
  final int noticeId;
  final Failure? failure;
  final int failureId;

  NotificationsState copyWith({
    bool? loaded,
    bool? available,
    NotifySettings? settings,
    bool? permitted,
    NotifyStatus? status,
    String? tunnel,
    bool? busy,
    String? notice,
    int? noticeId,
    Failure? failure,
    int? failureId,
  }) =>
      NotificationsState(
        loaded: loaded ?? this.loaded,
        available: available ?? this.available,
        settings: settings ?? this.settings,
        permitted: permitted ?? this.permitted,
        status: status ?? this.status,
        tunnel: tunnel ?? this.tunnel,
        busy: busy ?? this.busy,
        notice: notice ?? this.notice,
        noticeId: noticeId ?? this.noticeId,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [loaded, available, settings, permitted, status, tunnel, busy, notice, noticeId, failure, failureId];
}

/// Being told when Claude finishes or needs you with the app closed: the
/// switch, the kinds, and keeping the background service pointed at the hub,
/// over Tailscale and through its tunnel, as the hub's address and the
/// tunnel's change.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({required this._notifications, required this._watchHub}) : super(const NotificationsState());

  final Notifications _notifications;
  final WatchHub _watchHub;
  StreamSubscription<HubSnapshot>? _sub;
  String _hubUrl = '';
  String _applied = '';

  Future<void> load() async {
    final settings = await _notifications.load();
    final permitted = await _notifications.permitted();
    if (isClosed) return;
    emit(state.copyWith(loaded: true, available: _notifications.available, settings: settings, permitted: permitted));
    _sub = _watchHub().listen(_onHub);
    _onHub(_watchHub.current);
  }

  void _onHub(HubSnapshot hub) {
    if (isClosed) return;
    if (hub.notifyUrl != state.tunnel) emit(state.copyWith(tunnel: hub.notifyUrl));
    _hubUrl = hub.connected ? hub.endpoint : _hubUrl;
    // Re-point the service when the hub, or its tunnel's address, is new.
    final key = '$_hubUrl|${hub.notifyUrl}|${state.settings.enabled}|${state.settings.kinds.map((k) => k.name).join(',')}';
    if (hub.connected && state.loaded && key != _applied) unawaited(_apply(key));
  }

  // Applying one thing after another, each with the settings as they are when
  // its turn comes, so a late start never undoes a later choice.
  Future<void> _chain = Future.value();

  Future<void> _apply(String key) {
    _applied = key;
    return _chain = _chain.then((_) => _run());
  }

  Future<void> _run() async {
    if (isClosed) return;
    final r = await _notifications.apply(state.settings, hubUrl: _hubUrl, tunnel: state.tunnel);
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)),
      // Only the token comes back: the choices may have changed while this ran.
      (s) => emit(state.copyWith(settings: state.settings.copyWith(token: state.settings.enabled ? s.token : ''))),
    );
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    final s = await _notifications.status();
    final permitted = await _notifications.permitted();
    if (!isClosed) emit(state.copyWith(status: s, permitted: permitted));
  }

  Future<void> setEnabled(bool on) async {
    if (on && _notifications.available && !state.permitted) {
      await _notifications.askPermission();
    }
    await _change(state.settings.copyWith(enabled: on, token: on ? state.settings.token : ''));
  }

  Future<void> setKind(NotifyKind kind, bool on) =>
      _change(state.settings.copyWith(kinds: on ? {...state.settings.kinds, kind} : ({...state.settings.kinds}..remove(kind))));

  Future<void> _change(NotifySettings next) async {
    emit(state.copyWith(settings: next, busy: true));
    await _notifications.save(next);
    _applied = '';
    await _apply('$_hubUrl|${state.tunnel}|${next.enabled}|${next.kinds.map((k) => k.name).join(',')}');
    if (!isClosed) emit(state.copyWith(busy: false));
  }

  Future<void> sendTest() async {
    final r = await _notifications.test();
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)),
      (_) => emit(state.copyWith(notice: 'Test sent. It reaches the phone within a few seconds.', noticeId: state.noticeId + 1)),
    );
  }

  /// The app is on screen or not: the background service stays quiet while it is.
  void appActive(bool active) => unawaited(_notifications.appActive(active));

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
