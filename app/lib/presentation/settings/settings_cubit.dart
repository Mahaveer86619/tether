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
    this.themeMode = ThemeMode.system,
    this.saving = false,
    this.savedId = 0,
    this.failure,
    this.failureId = 0,
  });

  final bool loaded;
  final HubConnection connection;
  final ThemeMode themeMode;
  final bool saving;
  final int savedId;
  final Failure? failure;
  final int failureId;

  SettingsState copyWith({
    bool? loaded,
    HubConnection? connection,
    ThemeMode? themeMode,
    bool? saving,
    int? savedId,
    Failure? failure,
    int? failureId,
  }) =>
      SettingsState(
        loaded: loaded ?? this.loaded,
        connection: connection ?? this.connection,
        themeMode: themeMode ?? this.themeMode,
        saving: saving ?? this.saving,
        savedId: savedId ?? this.savedId,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [loaded, connection, themeMode, saving, savedId, failure, failureId];
}

/// View model for settings; also loads them at start-up and connects.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({required this._load, required this._save, required this._theme})
      : super(const SettingsState());

  final LoadConnection _load;
  final SaveConnection _save;
  final ThemeSettings _theme;

  /// Loads saved settings and connects if they are complete.
  Future<void> start() async {
    final mode = await _theme.load();
    final result = await _load();
    await result.fold(
      (f) async => emit(state.copyWith(loaded: true, themeMode: mode, failure: f, failureId: state.failureId + 1)),
      (conn) async {
        emit(state.copyWith(loaded: true, themeMode: mode, connection: conn));
        if (conn.isComplete) await save(conn.url, conn.token, quiet: true);
      },
    );
  }

  Future<void> save(String url, String token, {bool quiet = false}) async {
    emit(state.copyWith(saving: true));
    final result = await _save(url, token);
    result.fold(
      (f) => emit(state.copyWith(saving: false, failure: f, failureId: state.failureId + 1)),
      (conn) => emit(state.copyWith(saving: false, connection: conn, savedId: quiet ? state.savedId : state.savedId + 1)),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(state.copyWith(themeMode: mode));
    final result = await _theme.save(mode);
    if (result.failureOrNull case final f?) emit(state.copyWith(failure: f, failureId: state.failureId + 1));
  }
}
