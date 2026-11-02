import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.loaded = false,
    this.connection = const HubConnection(url: '', token: ''),
    this.appearance = const Appearance(),
    this.saving = false,
    this.savedId = 0,
    this.failure,
    this.failureId = 0,
  });

  final bool loaded;
  final HubConnection connection;
  final Appearance appearance;
  final bool saving;
  final int savedId;
  final Failure? failure;
  final int failureId;

  SettingsState copyWith({
    bool? loaded,
    HubConnection? connection,
    Appearance? appearance,
    bool? saving,
    int? savedId,
    Failure? failure,
    int? failureId,
  }) =>
      SettingsState(
        loaded: loaded ?? this.loaded,
        connection: connection ?? this.connection,
        appearance: appearance ?? this.appearance,
        saving: saving ?? this.saving,
        savedId: savedId ?? this.savedId,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [loaded, connection, appearance, saving, savedId, failure, failureId];
}

/// View model for settings; also loads them at start-up and connects.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required this._load,
    required this._save,
    required this._pair,
    required this._theme,
    required this._share,
    required this._viaTailnet,
  }) : super(const SettingsState());

  final ConnectOverTailnet _viaTailnet;

  final SharePreferences _share;

  final LoadConnection _load;
  final SaveConnection _save;
  final PairThisDevice _pair;
  final ThemeSettings _theme;

  /// Loads saved settings and connects if they are complete.
  Future<void> start() async {
    final look = await _theme.load();
    final result = await _load();
    await result.fold(
      (f) async => emit(state.copyWith(loaded: true, appearance: look, failure: f, failureId: state.failureId + 1)),
      (conn) async {
        emit(state.copyWith(loaded: true, appearance: look, connection: conn));
        if (conn.viaTailnet) {
          await _viaTailnet(conn.url);
        } else if (conn.isComplete) {
          await save(conn.url, conn.token, quiet: true, fingerprint: conn.fingerprint);
        }
      },
    );
  }

  /// Connects with a token typed in. A pinned certificate is kept while the
  /// address stays the same.
  Future<void> save(String url, String token, {bool quiet = false, String? fingerprint}) async {
    emit(state.copyWith(saving: true));
    final result = await _save(url, token, fingerprint: fingerprint ?? (url == state.connection.url ? state.connection.fingerprint : ''));
    result.fold(
      (f) => emit(state.copyWith(saving: false, failure: f, failureId: state.failureId + 1)),
      (conn) => emit(state.copyWith(saving: false, connection: conn, savedId: quiet ? state.savedId : state.savedId + 1)),
    );
  }

  /// Connects without a token, as the owner's own tailnet machine.
  Future<void> connectOverTailnet(String url) async {
    emit(state.copyWith(saving: true));
    final result = await _viaTailnet(url);
    result.fold(
      (f) => emit(state.copyWith(saving: false, failure: f, failureId: state.failureId + 1)),
      (conn) => emit(state.copyWith(saving: false, connection: conn, savedId: state.savedId + 1)),
    );
  }

  /// Pairs with a one-time code, from a QR code or typed in.
  Future<void> pair(String url, String code, {String fingerprint = ''}) async {
    emit(state.copyWith(saving: true));
    final result = await _pair(url, code, fingerprint: fingerprint);
    result.fold(
      (f) => emit(state.copyWith(saving: false, failure: f, failureId: state.failureId + 1)),
      (conn) => emit(state.copyWith(saving: false, connection: conn, savedId: state.savedId + 1)),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) => _setAppearance(state.appearance.copyWith(mode: mode));

  /// Switching theme drops a custom accent, which was picked against the old one.
  Future<void> setPalette(String id) => _setAppearance(state.appearance.copyWith(palette: id, accent: () => null));

  Future<void> setAccent(int? argb) => _setAppearance(state.appearance.copyWith(accent: () => argb));

  /// Applies settings another device shared, without sharing them back.
  Future<void> applyShared(Appearance a) async {
    if (a == state.appearance) return;
    emit(state.copyWith(appearance: a));
    await _theme.save(a);
  }

  /// Offers this device's settings to the hub, which had none yet.
  Future<void> share() => _share(state.appearance);

  Future<void> _setAppearance(Appearance a) async {
    emit(state.copyWith(appearance: a));
    // Offline, the change stays local; it isn't worth a toast.
    await _share(a);
    final result = await _theme.save(a);
    if (result.failureOrNull case final f?) emit(state.copyWith(failure: f, failureId: state.failureId + 1));
  }
}
