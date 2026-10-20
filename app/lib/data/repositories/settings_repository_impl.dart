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
        final (url, token, fingerprint, viaTailnet) = await _local.readConnection();
        return HubConnection(url: url, token: token, fingerprint: fingerprint, viaTailnet: viaTailnet);
      });

  @override
  Future<Result<void>> saveConnection(HubConnection connection) =>
      guard(() => _local.writeConnection(connection.url, connection.token, connection.fingerprint, viaTailnet: connection.viaTailnet));

  @override
  Future<Result<void>> clearConnection() => guard(_local.clearConnection);

  @override
  Future<String> loadDraft(String key) => _local.readDraft(key);

  @override
  Future<void> saveDraft(String key, String text) => _local.writeDraft(key, text);

  @override
  Future<Appearance> loadAppearance() async {
    final (mode, palette, accent) = await _local.readAppearance();
    return Appearance(mode: ThemeMode.values.asNameMap()[mode] ?? ThemeMode.system, palette: palette ?? 'claude', accent: accent);
  }

  @override
  Future<Result<void>> saveAppearance(Appearance a) => guard(() => _local.writeAppearance(a.mode.name, a.palette, a.accent));
}
