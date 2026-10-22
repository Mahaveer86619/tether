import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/core/error/failures.dart';
import 'package:tether/core/result.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/presentation/hub/hub_cubit.dart';
import 'package:tether/presentation/new_session/new_session_cubit.dart';
import 'package:tether/presentation/session/session_bloc.dart';
import 'package:tether/presentation/session/terminal_cubit.dart';
import 'package:tether/presentation/settings/settings_cubit.dart';

import '../helpers/fakes.dart';

SessionBloc sessionBloc(FakeHubRepository repo, String id) => SessionBloc(
      sessionId: id,
      watchHub: WatchHub(repo),
      watchTimeline: WatchTimeline(repo),
      sendMessage: SendMessage(repo),
      interrupt: InterruptSession(repo),
      endSession: EndSession(repo),
      drafts: Drafts(FakeSettingsRepository()),
      setGlobal: SetSessionGlobal(repo),
      continueOnHub: ContinueOnHub(repo),
      outbox: Outbox(FakeSettingsRepository()),
    );

void main() {
  group('SessionBloc', () {
    late FakeHubRepository repo;
    setUp(() => repo = FakeHubRepository(snapshotWith([session('s1'), session('t1', host: SessionHost.terminal, state: SessionState.running)])));

    blocTest<SessionBloc, SessionViewState>(
      'shows the session and its live timeline',
      build: () => sessionBloc(repo, 's1'),
      act: (b) async {
        b.add(const SessionOpened());
        await Future<void>.delayed(Duration.zero);
        repo.emitTimeline('s1', [rpb.TimelineItem(itemId: 'a', user: rpb.UserText(text: 'hi'))]);
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.session?.id, 's1');
        expect(b.state.nodeOnline, isTrue);
        expect(b.state.items.single.user.text, 'hi');
        expect(b.state.loading, isFalse);
        expect(b.state.canType, isTrue);
      },
    );

    blocTest<SessionBloc, SessionViewState>(
      'a sent message bumps sentId so the composer clears',
      build: () => sessionBloc(repo, 's1'),
      act: (b) async {
        b.add(const SessionOpened());
        await Future<void>.delayed(Duration.zero);
        b.add(const MessageSubmitted('continue'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(repo.sent.single, ('s1', 'continue', false));
        expect(b.state.sentId, 1);
        expect(b.state.sending, isFalse);
        expect(b.state.failure, isNull);
      },
    );

    blocTest<SessionBloc, SessionViewState>(
      'typing into your own terminal session is refused with a failure',
      build: () => sessionBloc(repo, 't1'),
      act: (b) async {
        b.add(const SessionOpened());
        await Future<void>.delayed(Duration.zero);
        b.add(const MessageSubmitted('hi'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.canType, isFalse);
        expect(b.state.failure, isA<TerminalActiveFailure>());
        expect(b.state.failureId, 1);
        expect(repo.sent, isEmpty);
      },
    );

    blocTest<SessionBloc, SessionViewState>(
      'forking a terminal session opens the new fork',
      build: () => sessionBloc(repo, 't1'),
      act: (b) async {
        b.add(const SessionOpened());
        await Future<void>.delayed(Duration.zero);
        b.add(const ForkModeChanged(true));
        b.add(const MessageSubmitted('try another way'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(repo.sent.single, ('t1', 'try another way', true));
        expect(b.state.forkedTo, 'fork-of-t1');
        expect(b.state.forking, isFalse);
      },
    );

    blocTest<SessionBloc, SessionViewState>(
      'files go with the message, even with no text',
      build: () => sessionBloc(repo, 's1'),
      act: (b) async {
        b.add(const SessionOpened());
        await Future<void>.delayed(Duration.zero);
        b.add(const MessageSubmitted('', attachments: ['a1', 'a2']));
      },
      wait: const Duration(milliseconds: 20),
      verify: (_) {
        expect(repo.attachmentsSent.single, ['a1', 'a2']);
        expect(repo.sent.single.$2, isNotEmpty);
      },
    );

    blocTest<SessionBloc, SessionViewState>(
      'keeping a copy on the hub, then continuing there',
      build: () => sessionBloc(repo, 's1'),
      act: (b) => b
        ..add(const GlobalToggled(true))
        ..add(const ContinueOnHubRequested('carry on')),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(repo.globalCalls.single, ('s1', true));
        expect(b.state.forkedTo, 'continued-s1');
      },
    );

    blocTest<SessionBloc, SessionViewState>(
      'hub failures surface as failures, not crashes',
      build: () {
        repo.onSend = (_, _) => const Err(NodeOfflineFailure());
        return sessionBloc(repo, 's1');
      },
      act: (b) async {
        b.add(const SessionOpened());
        await Future<void>.delayed(Duration.zero);
        b.add(const MessageSubmitted('x'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) => expect(b.state.failure, isA<NodeOfflineFailure>()),
    );
  });

  group('SessionBloc controls', () {
    blocTest<SessionBloc, SessionViewState>(
      'interrupt and end reach the hub',
      build: () => sessionBloc(FakeHubRepository(snapshotWith([session('s1', state: SessionState.running)])), 's1'),
      act: (b) => b
        ..add(const InterruptRequested())
        ..add(const EndRequested()),
      wait: const Duration(milliseconds: 20),
      verify: (b) => expect(b.state.failure, isNull),
    );

    test('a Windows terminal session takes typed input; others refuse', () async {
      final typed = session('w1', node: 'laptop', host: SessionHost.terminal, state: SessionState.ready);
      final repo = FakeHubRepository(snapshotWith([
        Session(id: 'w1', node: 'laptop', host: SessionHost.terminal, state: SessionState.ready, terminalInput: true),
        typed.copyWithId('l1'),
      ]));
      expect((await SendMessage(repo)('w1', 'hi')).valueOrNull, 'w1');
      expect((await SendMessage(repo)('l1', 'hi')).failureOrNull, isA<TerminalActiveFailure>());
      expect((await EndSession(repo)('w1')).failureOrNull, isA<ValidationFailure>());
      expect(repo.ended, isEmpty);
    });
  });

  test('projects group sessions by folder and leave done sessions out', () {
    final hub = snapshotWith([
      session('a', state: SessionState.idle),
      session('b', state: SessionState.idle, cwd: '/srv/other'),
      const Session(id: 'c', node: 'minipc', cwd: '/srv/app', archived: true),
      const Session(id: 'd', node: 'minipc', cwd: '/srv/gone', archived: true),
    ]);
    final projects = hub.projects();
    expect(projects.map((p) => p.cwd), unorderedEquals(['/srv/app', '/srv/other']));
    expect(projects.firstWhere((p) => p.cwd == '/srv/app').sessions.map((s) => s.id), ['a']);
    expect(hub.projects(includeArchived: true).length, 3);
  });

  test('a draft comes back when the session reopens, and goes once sent', () async {
    final repo = FakeHubRepository(snapshotWith([session('s1')]));
    final settings = FakeSettingsRepository()..drafts['s1'] = 'half-written';
    SessionBloc open() => SessionBloc(
          sessionId: 's1',
          watchHub: WatchHub(repo),
          watchTimeline: WatchTimeline(repo),
          sendMessage: SendMessage(repo),
          interrupt: InterruptSession(repo),
          endSession: EndSession(repo),
          drafts: Drafts(settings),
          setGlobal: SetSessionGlobal(repo),
          continueOnHub: ContinueOnHub(repo),
          outbox: Outbox(settings),
        );
    final bloc = open()..add(const SessionOpened());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.draft, 'half-written');
    bloc.add(const DraftChanged('half-written, now longer'));
    await bloc.close();
    expect(settings.drafts['s1'], 'half-written, now longer', reason: 'closing writes the pending draft');

    final again = open()..add(const SessionOpened());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    again.add(const MessageSubmitted('half-written, now longer'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(settings.drafts.containsKey('s1'), isFalse);
    await again.close();
  });

  test('settings from another device apply here without being shared back', () async {
    final hub = FakeHubRepository(snapshotWith([]));
    final settings = FakeSettingsRepository();
    final cubit = SettingsCubit(
      load: LoadConnection(settings),
      save: SaveConnection(settings, hub),
      pair: PairThisDevice(SaveConnection(settings, hub), hub, name: 'x', platform: 'android'),
      theme: ThemeSettings(settings),
      share: SharePreferences(hub),
      viaTailnet: ConnectOverTailnet(settings, hub),
    );
    await cubit.applyShared(const Appearance(palette: 'forest'));
    expect(cubit.state.appearance.palette, 'forest');
    expect(settings.appearance.palette, 'forest');
    expect(hub.sharedPreferences, isEmpty);
    await cubit.setPalette('rose');
    expect(hub.sharedPreferences.single.palette, 'rose');
    await cubit.close();
  });

  group('SessionBloc outbox', () {
    late FakeHubRepository repo;
    late FakeSettingsRepository settings;
    setUp(() {
      repo = FakeHubRepository(snapshotWith([session('s1')]));
      settings = FakeSettingsRepository();
    });
    SessionBloc open() => SessionBloc(
          sessionId: 's1',
          watchHub: WatchHub(repo),
          watchTimeline: WatchTimeline(repo),
          sendMessage: SendMessage(repo),
          interrupt: InterruptSession(repo),
          endSession: EndSession(repo),
          drafts: Drafts(settings),
          setGlobal: SetSessionGlobal(repo),
          continueOnHub: ContinueOnHub(repo),
          outbox: Outbox(settings),
        );

    test('a failed send stays in the outbox, saved, and Retry sends it with the same client id', () async {
      var fail = true;
      repo.onSend = (_, _) => fail ? const Err(NodeOfflineFailure()) : const Ok('s1');
      final b = open()..add(const SessionOpened());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      b.add(const MessageSubmitted('deploy it'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(b.state.outbox.single.state, OutboxState.failed);
      expect(b.state.failure, isA<NodeOfflineFailure>());
      expect(settings.outboxes['s1']!.single.text, 'deploy it', reason: 'kept on the device');
      expect(b.state.sentId, 1, reason: 'the composer still clears: the text is safe in the outbox');

      fail = false;
      b.add(OutboxRetried(b.state.outbox.single.id));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(b.state.outbox.single.state, OutboxState.sent);
      expect(repo.clientIds, hasLength(2));
      expect(repo.clientIds.toSet(), hasLength(1), reason: 'a retry is the same message to the hub');
      await b.close();
    });

    test('the outbox survives a restart and empties when the timeline shows the message', () async {
      final b = open()..add(const SessionOpened());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      b.add(const MessageSubmitted('one more thing'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final id = b.state.outbox.single.id;
      await b.close();

      repo.timelines['s1'] ??= StreamController<TimelineSnapshot>.broadcast();
      final again = open()..add(const SessionOpened());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(again.state.outbox.single.id, id, reason: 'read back from the device');
      repo.emitTimeline('s1', [TimelineItem(itemId: 'u1', user: rpb.UserText(text: 'one more thing', clientId: id))]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(again.state.outbox, isEmpty);
      expect(settings.outboxes['s1'], isEmpty);
      await again.close();
    });

    test('a message that shows in the timeline before its send returns leaves the outbox', () async {
      repo.timelines['s1'] ??= StreamController<TimelineSnapshot>.broadcast();
      repo.onSend = (_, _) {
        // The hub's echo beats its answer to the send.
        repo.emitTimeline('s1', [TimelineItem(itemId: 'u1', user: rpb.UserText(text: 'quick one', clientId: repo.clientIds.last))]);
        return const Ok('s1');
      };
      final b = open()..add(const SessionOpened());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      b.add(const MessageSubmitted('quick one'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(b.state.outbox, isEmpty, reason: 'shown once, by the timeline');
      await b.close();
    });

    test('discarding drops a message without sending it', () async {
      repo.onSend = (_, _) => const Err(NodeOfflineFailure());
      final b = open()..add(const SessionOpened());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      b.add(const MessageSubmitted('never mind'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      b.add(OutboxDiscarded(b.state.outbox.single.id));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(b.state.outbox, isEmpty);
      expect(repo.sent, hasLength(1));
      await b.close();
    });

  });

  group('SessionBloc interrupt', () {
    SessionBloc bloc(FakeHubRepository repo) => SessionBloc(
          sessionId: 's1',
          watchHub: WatchHub(repo),
          watchTimeline: WatchTimeline(repo),
          sendMessage: SendMessage(repo),
          interrupt: InterruptSession(repo),
          endSession: EndSession(repo),
          drafts: Drafts(FakeSettingsRepository()),
          setGlobal: SetSessionGlobal(repo),
          continueOnHub: ContinueOnHub(repo),
          outbox: Outbox(FakeSettingsRepository()),
          interruptTimeout: const Duration(milliseconds: 40),
        );

    test('interrupting shows until the turn stops', () async {
      final repo = FakeHubRepository(snapshotWith([session('s1', state: SessionState.running)]));
      final b = bloc(repo)..add(const SessionOpened());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      b.add(const InterruptRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(b.state.interrupting, isTrue);
      expect(repo.interrupted.single, 's1');
      repo.emitHub(snapshotWith([session('s1', state: SessionState.ready)]));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(b.state.interrupting, isFalse);
      expect(b.state.interruptSlow, isFalse, reason: 'it stopped in time');
      await b.close();
    });

    test('a turn that keeps going after the interrupt offers the other ways out', () async {
      final repo = FakeHubRepository(snapshotWith([session('s1', state: SessionState.running)]));
      final b = bloc(repo)..add(const SessionOpened());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      b.add(const InterruptRequested());
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(b.state.interruptSlow, isTrue);
      expect(b.state.interrupting, isTrue);
      await b.close();
    });
  });

  group('TerminalCubit', () {
    test('reads the screen, and reads it again after pressing keys', () async {
      final repo = FakeHubRepository(snapshotWith([session('s1')]))..screenText = '❯ 1. Yes';
      final cubit = TerminalCubit(sessionId: 's1', terminal: TerminalControl(repo));
      await cubit.refresh();
      expect(cubit.state.screen!.text, '❯ 1. Yes');
      repo.screenText = 'done';
      await cubit.press(['Enter']);
      expect(repo.keysSent.single.$2, ['Enter']);
      expect(cubit.state.screen!.text, 'done');
      expect(cubit.state.sending, isFalse);
      await cubit.press(const []);
      expect(cubit.state.failure, isA<ValidationFailure>(), reason: 'nothing to press');
      await cubit.close();
    });
  });

  group('HubCubit', () {
    test('tracks approvals being answered and reports failures', () async {
      final repo = FakeHubRepository(snapshotWith([session('s1')], approvals: [
        const Approval(id: 'ap', session: 's1', node: 'minipc', kind: ApprovalKind.tool, toolName: 'Bash'),
      ]));
      final cubit = HubCubit(
        setMode: SetPermissionMode(repo),
        presence: ReportPresence(repo),
          watchHub: WatchHub(repo), decideApproval: DecideApproval(repo), setArchived: SetSessionArchived(repo), retry: RetryConnection(repo));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.hub.approvals, contains('ap'));

      await cubit.decide('ap', allow: true);
      expect(repo.decided.single, ('ap', true));
      expect(cubit.state.deciding, isEmpty);

      repo.decideResult = const Err(NotFoundFailure('approval already resolved'));
      await cubit.decide('ap', allow: false);
      expect(cubit.state.failure, isA<NotFoundFailure>());
      await cubit.close();
    });
  });

  group('NewSessionCubit', () {
    test('defaults to the preferred online node and its latest folder', () {
      final hub = snapshotWith([session('s1', cwd: '/srv/old'), session('s2', node: 'laptop', cwd: r'C:\code\app')]);
      final cubit = NewSessionCubit(hub: hub, createSession: CreateSession(FakeHubRepository(hub)), drafts: Drafts(FakeSettingsRepository()), loadWorkspaces: LoadWorkspaces(FakeHubRepository(hub)), setRoot: SetWorkspaceRoot(FakeHubRepository(hub)), preferredNode: 'laptop');
      expect(cubit.state.node, 'laptop');
      expect(cubit.state.cwd, r'C:\code\app');
      cubit.selectNode('minipc');
      expect(cubit.state.cwd, '/srv/old');
    });

    test('a new project is created in a workspace root, and a suggested root is remembered', () async {
      final hub = snapshotWith([session('s2', node: 'laptop', cwd: r'C:\code\app')]);
      final repo = FakeHubRepository(hub)..roots = [];
      final cubit = NewSessionCubit(
        hub: hub,
        createSession: CreateSession(repo),
        drafts: Drafts(FakeSettingsRepository()),
        loadWorkspaces: LoadWorkspaces(repo),
        setRoot: SetWorkspaceRoot(repo),
        preferredNode: 'laptop',
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.suggestedRoots, [r'C:\code']);
      cubit
        ..setNewProject(true)
        ..setProjectName('new-app');
      expect(cubit.newProjectPath, r'C:\code\new-app');
      await cubit.submit('scaffold it');
      final req = repo.created.single;
      expect((req.cwd, req.createCwd), (r'C:\code\new-app', true));
      expect(repo.roots, [const WorkspaceRoot(node: 'laptop', path: r'C:\code')]);
    });

    test('validation failures stay in the form', () async {
      final hub = snapshotWith([]);
      final repo = FakeHubRepository(hub);
      final cubit = NewSessionCubit(hub: hub, createSession: CreateSession(repo), drafts: Drafts(FakeSettingsRepository()), loadWorkspaces: LoadWorkspaces(repo), setRoot: SetWorkspaceRoot(repo));
      await cubit.submit('   ');
      expect(cubit.state.failure, isA<ValidationFailure>());
      expect(cubit.state.createdId, isNull);
      await cubit.submit('do the thing');
      expect(cubit.state.createdId, 'new-session');
      expect(repo.created.single.prompt, 'do the thing');
    });
  });
}
