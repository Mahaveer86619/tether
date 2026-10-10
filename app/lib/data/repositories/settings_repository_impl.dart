import 'package:flutter/material.dart' show ThemeMode;

import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/settings_local.dart';
import 'failure_mapper.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._local);

  final SettingsLocalDataSource _local;

  @override
  Future<Result<HubConnection>> loadConnection() => guard(() async {
        final (url, token) = await _local.readConnection();
        return HubConnection(url: url, token: token);
      });

  @override
  Future<Result<void>> saveConnection(HubConnection connection) =>
      guard(() => _local.writeConnection(connection.url, connection.token));

  @override
  Future<ThemeMode> loadThemeMode() async => ThemeMode.values.asNameMap()[await _local.readTheme()] ?? ThemeMode.system;

  @override
  Future<Result<void>> saveThemeMode(ThemeMode mode) => guard(() => _local.writeTheme(mode.name));
}
