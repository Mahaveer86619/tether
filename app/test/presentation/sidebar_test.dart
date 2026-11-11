import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/injection.dart';
import 'package:tether/presentation/app.dart';
import 'package:tether/presentation/chats/chats_page.dart';

import '../helpers/fakes.dart';

Chat chat(String id, String title, String session, {DateTime? at, ChatTarget target = const ChatTarget()}) =>
    Chat(id: id, title: title, activeSession: session, links: [ChatLink(session: session)], updated: at ?? DateTime(2026, 10, 11), target: target);

void main() {
  group('which chats are projects', () {
    final hub = HubSnapshot(
      hubVersion: '0.17.0',
      sessions: {
        's1': session('s1', cwd: '/home/me/tether'),
        's2': session('s2', cwd: '/home/me/tether'),
        's3': session('s3', cwd: '/home/me'),
        's4': session('s4', cwd: 'C:\\Users\\me\\api', node: 'laptop'),
        's5': session('s5', cwd: ''),
      },
      chats: {
        'c1': chat('c1', 'Fix login', 's1', at: DateTime(2026, 10, 12)),
        'c2': chat('c2', 'Add tests', 's2', at: DateTime(2026, 10, 11)),
        'c3': chat('c3', 'What is a monad', 's3'),
        'c4': chat('c4', 'API work', 's4', at: DateTime(2026, 10, 13)),
        'c5': chat('c5', 'No folder', 's5'),
        'c6': chat('c6', 'Scratch', 'gone', target: const ChatTarget.scratch()),
      },
    );

    test('chats in a folder that is not a home folder are grouped by it, the newest project first', () {
      final projects = hub.chatProjects();
      expect([for (final p in projects) p.name], ['api', 'tether']);
      expect([for (final c in projects.last.chats) c.id], ['c1', 'c2']);
      expect(projects.first.node, 'laptop');
    });

    test('one-off chats, in a home folder, no folder or a scratch folder, are in no project', () {
      for (final id in ['c3', 'c5', 'c6']) {
        expect(hub.projectOf(hub.chats[id]!), isNull, reason: id);
      }
    });

    test('a folder is a project unless it is nothing or somebody\'s home', () {
      expect(isProjectFolder('/home/me/code/tether'), isTrue);
      expect(isProjectFolder('/srv/app'), isTrue);
      expect(isProjectFolder('C:\\Users\\me\\code'), isTrue);
      for (final f in ['', '  ', '/home/me', '/home/me/', '/Users/me', '/root', 'C:\\Users\\me', 'C:/Users/me/']) {
        expect(isProjectFolder(f), isFalse, reason: f);
      }
    });
  });

  group('the sidebar and the first place', () {
    late FakeHubRepository repo;

    setUp(() async {
      await sl.reset();
      repo = FakeHubRepository(HubSnapshot(
        status: ConnectionStatus.connected,
        hubVersion: '0.17.0',
        hubNode: 'minipc',
        nodes: {'laptop': laptop, 'minipc': minipc},
        sessions: {'s1': session('s1', cwd: '/home/me/tether'), 's3': session('s3', cwd: '/home/me')},
        chats: {
          'c1': chat('c1', 'Fix login', 's1'),
          'c3': chat('c3', 'What is a monad', 's3', at: DateTime(2026, 10, 10)),
        },
      ));
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

    Future<void> open(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TetherApp());
      await settle(tester);
    }

    testWidgets('Home is where a chat is started, with the folders you work in to pick from', (tester) async {
      await open(tester, const Size(1400, 900));
      expect(find.byKey(const Key('greeting')), findsOneWidget);
      expect(find.byKey(const Key('new-chat-input')), findsOneWidget);
      expect(find.byKey(const Key('project-chip-minipc|/home/me/tether')), findsOneWidget);
      expect(find.byType(ChatsPage), findsNothing, reason: 'the list of chats is its own screen');
    });

    testWidgets('the sidebar lists projects with their chats, and every chat; a one-off is only in the second', (tester) async {
      await open(tester, const Size(1400, 900));
      expect(find.byKey(const Key('section-projects')), findsOneWidget);
      expect(find.byKey(const Key('project-chat-c1')), findsNothing, reason: 'a project starts shut');
      await tester.tap(find.byKey(const Key('project-minipc|/home/me/tether')));
      await settle(tester);
      expect(find.byKey(const Key('project-chat-c1')), findsOneWidget);
      expect(find.byKey(const Key('recent-c1')), findsOneWidget);
      expect(find.byKey(const Key('recent-c3')), findsOneWidget);
      expect(find.byKey(const Key('project-chat-c3')), findsNothing);
    });

    testWidgets('a switch in the header goes between starting a chat and the list of chats', (tester) async {
      await open(tester, const Size(1400, 900));
      await tester.tap(find.byKey(const Key('nav-chats')));
      await settle(tester);
      expect(find.byType(ChatsPage), findsOneWidget);
      expect(find.byKey(const Key('new-chat-input')), findsNothing);
      await tester.tap(find.byKey(const Key('nav-home')));
      await settle(tester);
      expect(find.byKey(const Key('new-chat-input')), findsOneWidget);
    });

    testWidgets('the sidebar folds away and comes back', (tester) async {
      await open(tester, const Size(1400, 900));
      await tester.tap(find.byKey(const Key('collapse-sidebar')));
      await settle(tester);
      expect(find.byKey(const Key('section-chats')), findsNothing);
      expect(find.byKey(const Key('new-chat')), findsOneWidget, reason: 'new chat stays within reach');
      await tester.tap(find.byKey(const Key('open-sidebar')));
      await settle(tester);
      expect(find.byKey(const Key('section-chats')), findsOneWidget);
    });

    testWidgets('on a phone the sidebar is a drawer, and choosing a chat closes it', (tester) async {
      await open(tester, const Size(400, 860));
      expect(find.byKey(const Key('section-chats')), findsNothing);
      await tester.tap(find.byKey(const Key('open-sidebar')));
      await settle(tester);
      expect(find.byKey(const Key('section-chats')), findsOneWidget);
      await tester.tap(find.byKey(const Key('recent-c3')));
      await settle(tester);
      expect(find.byKey(const Key('section-chats')), findsNothing, reason: 'the drawer closed');
      expect(find.text('What is a monad'), findsWidgets);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
