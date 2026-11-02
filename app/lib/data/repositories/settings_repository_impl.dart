import 'dart:convert';

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
  Future<List<OutboxEntry>> loadOutbox(String session) async {
    final raw = await _local.readOutbox(session);
    if (raw.isEmpty) return const [];
    try {
      return [for (final m in jsonDecode(raw) as List<dynamic>) _entryFrom(m as Map<String, dynamic>, session)];
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  @override
  Future<void> saveOutbox(String session, List<OutboxEntry> entries) =>
      _local.writeOutbox(session, entries.isEmpty ? '' : jsonEncode([for (final e in entries) _entryTo(e)]));

  static Map<String, dynamic> _entryTo(OutboxEntry e) => {
        'id': e.id,
        'text': e.text,
        'attachments': e.attachments,
        if (e.files.isNotEmpty) 'files': [for (final f in e.files) {'path': f.path, 'name': f.name, 'size': f.size, 'uploadId': f.uploadId}],
        'created': e.created.millisecondsSinceEpoch,
        'state': e.state.name,
        if (e.sentAt != null) 'sentAt': e.sentAt!.millisecondsSinceEpoch,
        if (e.error.isNotEmpty) 'error': e.error,
      };

  static OutboxEntry _entryFrom(Map<String, dynamic> m, String session) => OutboxEntry(
        id: m['id'] as String,
        session: session,
        text: m['text'] as String? ?? '',
        attachments: [for (final a in m['attachments'] as List<dynamic>? ?? const []) a as String],
        files: [
          for (final f in m['files'] as List<dynamic>? ?? const [])
            LocalFile(path: f['path'] as String, name: f['name'] as String, size: f['size'] as int, uploadId: f['uploadId'] as String? ?? ''),
        ],
        created: DateTime.fromMillisecondsSinceEpoch(m['created'] as int? ?? 0),
        state: OutboxState.values.asNameMap()[m['state']] ?? OutboxState.failed,
        sentAt: m['sentAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['sentAt'] as int),
        error: m['error'] as String? ?? '',
      );

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
