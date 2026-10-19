import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tether/data/datasources/settings_local.dart';
import 'package:tether/data/repositories/settings_repository_impl.dart';
import 'package:tether/domain/entities/entities.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an outbox is stored per session and read back as it was', () async {
    final repo = SettingsRepositoryImpl(SettingsLocalDataSource(environment: const {}));
    final entries = [
      OutboxEntry(id: 'c1', session: 's1', text: 'run it', created: DateTime(2026, 10, 20, 9), attachments: const ['a1']),
      OutboxEntry(
        id: 'c2',
        session: 's1',
        text: 'and then',
        created: DateTime(2026, 10, 20, 10),
        state: OutboxState.failed,
        sentAt: DateTime(2026, 10, 20, 10, 1),
        error: 'offline',
      ),
    ];
    await repo.saveOutbox('s1', entries);
    expect(await repo.loadOutbox('s1'), entries);
    expect(await repo.loadOutbox('s2'), isEmpty);

    await repo.saveOutbox('s1', const []);
    expect((await SharedPreferences.getInstance()).containsKey('outbox:s1'), isFalse, reason: 'an empty outbox leaves nothing behind');
  });

  test('a damaged outbox reads as empty rather than failing', () async {
    SharedPreferences.setMockInitialValues({'outbox:s1': '{not json'});
    final repo = SettingsRepositoryImpl(SettingsLocalDataSource(environment: const {}));
    expect(await repo.loadOutbox('s1'), isEmpty);
  });
}
