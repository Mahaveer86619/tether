import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/domain/usecases/usecases.dart';
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

    test('a session from a terminal makes its folder a project, and one a chat holds is not listed twice', () {
      final withLoose = HubSnapshot(
        status: ConnectionStatus.connected,
        sessions: {
          's1': session('s1', cwd: '/home/me/tether'),
          'a': session('a', cwd: '/work/fk-ims-wvs', node: 'laptop'),
          'b': session('b', cwd: '/home/me'),
          'c': session('c', cwd: '/home/me/tether/.tether/x'),
        },
        chats: {'c1': chat('c1', 'Fix login', 's1')},
      );
      final projects = withLoose.chatProjects();
      expect([for (final p in projects) p.name], unorderedEquals(['tether', 'fk-ims-wvs']));
      final loose = projects.firstWhere((p) => p.name == 'fk-ims-wvs');
      expect(loose.chats, isEmpty);
      expect([for (final s in loose.sessions) s.id], ['a']);
      expect(projects.firstWhere((p) => p.name == 'tether').sessions, isEmpty);
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

  group('projects, unfiled folders and one-offs', () {
    const wh = ProjectInfo(id: 'p1', name: 'warehouse-sync', folders: [ProjectFolder(node: 'laptop', cwd: '/src/wh'), ProjectFolder(node: 'minipc', cwd: '/srv/wh')]);
    final lead = Chat(
      id: 'lead',
      title: 'Fix the upload failure',
      activeSession: 'l1',
      links: const [ChatLink(session: 'l1'), ChatLink(session: 't1', role: 'started'), ChatLink(session: 't2', role: 'started')],
      updated: DateTime(2026, 10, 12),
    );
    HubSnapshot hubWith({Map<String, Chat> more = const {}, Map<String, Session> sessions = const {}}) => HubSnapshot(
          hubVersion: '0.19.0',
          projectsSupported: true,
          projectInfos: const {'p1': wh},
          chatProjectIds: const {'lead': 'p1', 'plan': 'p1'},
          sessions: {
            'l1': session('l1', node: 'laptop', cwd: '/src/wh', state: SessionState.idle),
            't1': session('t1', node: 'laptop', cwd: '/src/wh', state: SessionState.running),
            't2': session('t2', node: 'minipc', cwd: '/srv/wh', state: SessionState.idle),
            'u1': session('u1', cwd: '/work/api'),
            'loose': session('loose', node: 'minipc', cwd: '/srv/wh/'),
            ...sessions,
          },
          chats: {
            'lead': lead,
            'plan': chat('plan', 'Plan the v3 rollout', 'gone', at: DateTime(2026, 10, 1)),
            'api': chat('api', 'API work', 'u1'),
            for (var i = 0; i < 7; i++) 'o$i': chat('o$i', 'Question $i', 'none-$i', at: DateTime(2026, 9, 1 + i)),
            ...more,
          },
        );

    test('a project lists its chats, and each chat the sessions it started, which are nowhere else', () {
      final tree = hubWith().sidebarTree();
      expect(tree.projects.single.info.id, 'p1');
      final chats = tree.projects.single.chats;
      expect([for (final c in chats) c.chat.id], ['lead', 'plan']);
      expect([for (final s in chats.first.spawned) s.id], ['t1', 't2'], reason: 'the running task first');
      expect(chats.first.running, isTrue);
      expect(tree.projects.single.running, isTrue, reason: 'working rolls up to the project');
      expect([for (final s in tree.projects.single.sessions) s.id], ['loose'], reason: 'a terminal session in its folder');
      final elsewhere = [for (final c in tree.oneOffs) c.id, for (final f in tree.unfiled) ...[for (final c in f.chats) c.id, for (final s in f.sessions) s.id]];
      for (final id in ['lead', 'plan', 't1', 't2', 'l1', 'loose']) {
        expect(elsewhere, isNot(contains(id)), reason: id);
      }
    });

    test('a folder in no project is unfiled, and the rest are one-offs, newest first', () {
      final tree = hubWith().sidebarTree();
      expect([for (final f in tree.unfiled) f.cwd], ['/work/api']);
      expect([for (final c in tree.unfiled.single.chats) c.id], ['api']);
      expect([for (final c in tree.oneOffs) c.id], ['o6', 'o5', 'o4', 'o3', 'o2', 'o1', 'o0']);
    });

    test('an approval on a spawned session marks its chat and its project', () {
      final hub = hubWith(sessions: {'t2': session('t2', node: 'minipc', cwd: '/srv/wh', state: SessionState.awaitingApproval)});
      final p = hub.sidebarTree().projects.single;
      expect(p.needsYou, isTrue);
      expect(p.chats.first.needsYou, isTrue);
      expect(p.chats.last.needsYou, isFalse);
    });

    test('folders match however the path is written', () {
      expect(folderKey('laptop', r'C:\Src\Tether\'), folderKey('laptop', 'c:/src/tether'));
      expect(folderKey('laptop', '/src/x/'), folderKey('laptop', '/src/x'));
      expect(folderKey('laptop', '/src/x'), isNot(folderKey('minipc', '/src/x')));
    });
  });

  group('projects in the sidebar', () {
    late FakeHubRepository repo;

    setUp(() async {
      await sl.reset();
      repo = FakeHubRepository(HubSnapshot(
        status: ConnectionStatus.connected,
        hubVersion: '0.19.0',
        hubNode: 'minipc',
        nodes: {'laptop': laptop, 'minipc': minipc},
        projectsSupported: true,
        projectInfos: const {'p1': ProjectInfo(id: 'p1', name: 'warehouse-sync', folders: [ProjectFolder(node: 'laptop', cwd: '/src/wh')])},
        chatProjectIds: const {'lead': 'p1'},
        sessions: {
          'l1': session('l1', node: 'laptop', cwd: '/src/wh', state: SessionState.idle),
          't1': session('t1', node: 'laptop', cwd: '/src/wh', state: SessionState.awaitingApproval),
          'u1': session('u1', cwd: '/work/api'),
          'term': session('term', cwd: '/work/cli'),
        },
        chats: {
          'lead': Chat(
            id: 'lead',
            title: 'Fix the upload failure',
            activeSession: 'l1',
            links: const [ChatLink(session: 'l1'), ChatLink(session: 't1', role: 'started')],
            updated: DateTime(2026, 10, 12),
          ),
          'api': chat('api', 'API work', 'u1'),
          for (var i = 0; i < 7; i++) 'o$i': chat('o$i', 'Question $i', 'none-$i', at: DateTime(2026, 9, 1 + i)),
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

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TetherApp());
      await settle(tester);
    }

    double top(WidgetTester tester, String key) => tester.getTopLeft(find.byKey(Key(key))).dy;

    testWidgets('projects come first, then unfiled folders, then the one-offs, capped at five', (tester) async {
      await open(tester);
      expect(top(tester, 'section-projects'), lessThan(top(tester, 'section-unfiled')));
      expect(top(tester, 'section-unfiled'), lessThan(top(tester, 'section-one-offs')));
      expect(find.byKey(const Key('needs-you-p1')), findsOneWidget, reason: 'a waiting task marks the closed project');
      for (var i = 6; i >= 2; i--) {
        expect(find.byKey(Key('oneoff-o$i')), findsOneWidget, reason: 'o$i');
      }
      expect(find.byKey(const Key('oneoff-o1')), findsNothing);
      expect(find.byKey(const Key('all-chats')), findsOneWidget);
      for (final id in ['lead', 'api']) {
        expect(find.byKey(Key('oneoff-$id')), findsNothing, reason: id);
      }
    });

    testWidgets('a project opens to its chats, and a chat to the sessions it spawned', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('project-chat-lead')), findsNothing, reason: 'a project starts shut');
      await tester.tap(find.byKey(const Key('named-project-p1')));
      await settle(tester);
      expect(find.byKey(const Key('project-chat-lead')), findsOneWidget);
      expect(find.byKey(const Key('spawned-t1')), findsOneWidget, reason: 'a task waiting on you shows without asking');
      expect(find.textContaining('needs you'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-tasks-lead')));
      await settle(tester);
      expect(find.byKey(const Key('spawned-t1')), findsNothing);
    });

    testWidgets('an unfiled folder becomes a project, and a session card files its chat', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('section-unfiled')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('file-minipc|/work/api')));
      await settle(tester);
      final made = repo.current.projectInfos.values.firstWhere((p) => p.name == 'api');
      expect(repo.current.chatProjectIds['api'], made.id, reason: 'the chat in the folder goes with it');
      expect(find.byKey(Key('named-project-${made.id}')), findsOneWidget);
      expect(find.byKey(const Key('file-minipc|/work/api')), findsNothing);

      final r = await sl<Chats>().addToProject('term');
      expect(r.valueOrNull?.name, 'cli');
      final cli = repo.current.projectInfos.values.firstWhere((p) => p.name == 'cli');
      expect(repo.current.chatProjectIds['chat-of-term'], cli.id);
      final again = await sl<Chats>().addToProject('l1');
      expect(again.valueOrNull?.id, 'p1', reason: 'a folder already in a project is filed there');
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

    testWidgets('Home is only where a chat is started: no cards and no folder chips', (tester) async {
      await open(tester, const Size(1400, 900));
      expect(find.byKey(const Key('greeting')), findsOneWidget);
      expect(find.byKey(const Key('new-chat-input')), findsOneWidget);
      expect(find.byKey(const Key('project-chip-minipc|/home/me/tether')), findsNothing);
      expect(find.text('NEEDS YOU'), findsNothing);
      expect(find.text('RUNNING NOW'), findsNothing);
      expect(find.byType(ChatsPage), findsNothing, reason: 'the list of chats is its own screen');
    });

    testWidgets('on a hub without projects, chats in a folder list under it as unfiled, and a one-off only among the one-offs', (tester) async {
      await open(tester, const Size(1400, 900));
      expect(find.byKey(const Key('section-projects')), findsNothing);
      expect(find.byKey(const Key('section-unfiled')), findsOneWidget);
      expect(find.byKey(const Key('project-chat-c1')), findsNothing, reason: 'a folder starts shut');
      await tester.tap(find.byKey(const Key('project-minipc|/home/me/tether')));
      await settle(tester);
      expect(find.byKey(const Key('project-chat-c1')), findsOneWidget);
      expect(find.byKey(const Key('oneoff-c1')), findsNothing);
      expect(find.byKey(const Key('oneoff-c3')), findsOneWidget);
      expect(find.byKey(const Key('project-chat-c3')), findsNothing);
      expect(find.byKey(const Key('file-minipc|/home/me/tether')), findsNothing, reason: 'an older hub cannot make projects');
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
      expect(find.byKey(const Key('section-one-offs')), findsNothing);
      expect(find.byKey(const Key('new-chat')), findsOneWidget, reason: 'new chat stays within reach');
      await tester.tap(find.byKey(const Key('open-sidebar')));
      await settle(tester);
      expect(find.byKey(const Key('section-one-offs')), findsOneWidget);
    });

    testWidgets('on a phone the sidebar is a drawer, and choosing a chat closes it', (tester) async {
      await open(tester, const Size(400, 860));
      expect(find.byKey(const Key('section-one-offs')), findsNothing);
      await tester.tap(find.byKey(const Key('open-sidebar')));
      await settle(tester);
      expect(find.byKey(const Key('section-one-offs')), findsOneWidget);
      await tester.tap(find.byKey(const Key('oneoff-c3')));
      await settle(tester);
      expect(find.byKey(const Key('section-one-offs')), findsNothing, reason: 'the drawer closed');
      expect(find.text('What is a monad'), findsWidgets);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
