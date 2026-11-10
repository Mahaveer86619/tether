import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/injection.dart';
import 'package:tether/presentation/app.dart';

import '../helpers/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeHubRepository repo;

  setUp(() async {
    await sl.reset();
    repo = FakeHubRepository(HubSnapshot(
      status: ConnectionStatus.connected,
      hubVersion: '0.17.0',
      hubNode: 'minipc',
      nodes: {'laptop': laptop, 'minipc': minipc},
      sessions: {'s1': session('s1', cwd: '/srv/app')},
      chats: {'c1': Chat(id: 'c1', title: 'Fix login', activeSession: 's1', links: const [ChatLink(session: 's1')], updated: DateTime(2026, 10, 11))},
    ))
      ..remote = const ChatRemote(repo: 'app-a1b2c3');
    sl
      ..registerSingleton<HubRepository>(repo)
      ..registerSingleton<TransferRepository>(FakeTransferRepository())
      ..registerSingleton<SettingsRepository>(FakeSettingsRepository()..saved = const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 't'))
      ..registerSingleton<UpdateRepository>(FakeUpdateRepository())
      ..registerSingleton<TailscaleRepository>(FakeTailscale())
      ..registerSingleton<HubProbe>(FakeHubProbe())
      ..registerSingleton<NotifyDevice>(FakeNotifyDevice())
      ..registerSingleton<DesktopUpdater>(FakeDesktopUpdater());
    configureDependencies(withData: false);
  });

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TetherApp());
    await settle(tester);
    await tester.tap(find.byKey(const Key('recent-c1')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('remote-chat')));
    await settle(tester);
  }

  testWidgets('a chat in a project is made remote on another device, and stopped', (tester) async {
    await openSheet(tester);
    expect(find.text('Remote project'), findsOneWidget);
    expect(find.byKey(const Key('remote-device-minipc')), findsNothing, reason: 'it is already there');
    expect(find.byKey(const Key('remote-start')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('remote-start'))).onPressed, isNull, reason: 'pick a device first');

    await tester.tap(find.byKey(const Key('remote-device-laptop')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('remote-start')));
    await settle(tester);
    expect(repo.remoteCalls, ['on:c1:laptop:true']);
    expect(find.byKey(const Key('remote-state')), findsOneWidget);
    expect(find.text('In step'), findsOneWidget);

    await tester.tap(find.byKey(const Key('remote-stop')));
    await settle(tester);
    expect(repo.remoteCalls.last, 'off:c1::false');
    expect(find.byKey(const Key('remote-start')), findsOneWidget);
  });

  testWidgets('setup files are added with their contents hidden, and removed', (tester) async {
    await openSheet(tester);
    expect(find.byKey(const Key('no-project-files')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-project-file')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('project-file-content')), 'API_KEY=abc123\nDB_URL=postgres://x');
    await tester.tap(find.byKey(const Key('save-project-file')));
    await settle(tester);
    expect(find.byKey(const Key('project-file-.env')), findsOneWidget);
    expect(find.textContaining('API_KEY, DB_URL'), findsOneWidget);
    expect(find.textContaining('abc123'), findsNothing, reason: 'values are never shown');

    await tester.tap(find.byTooltip('Delete'));
    await settle(tester);
    expect(find.byKey(const Key('no-project-files')), findsOneWidget);
  });

  testWidgets('a chat with no project folder says so', (tester) async {
    repo.remote = const ChatRemote();
    await openSheet(tester);
    expect(find.textContaining('Only a chat that works in a project folder'), findsOneWidget);
    expect(find.byKey(const Key('remote-start')), findsNothing);
  });
}
