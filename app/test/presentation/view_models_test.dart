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

import '../helpers/fakes.dart';

SessionBloc sessionBloc(FakeHubRepository repo, String id) => SessionBloc(
      sessionId: id,
      watchHub: WatchHub(repo),
      watchTimeline: WatchTimeline(repo),
      sendMessage: SendMessage(repo),
      interrupt: InterruptSession(repo),
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
      'hub failures surface as failures, not crashes',
      build: () {
        repo.onSend = (_, __) => const Err(NodeOfflineFailure());
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

  group('HubCubit', () {
    test('tracks approvals being answered and reports failures', () async {
      final repo = FakeHubRepository(snapshotWith([session('s1')], approvals: [
        const Approval(id: 'ap', session: 's1', node: 'minipc', kind: ApprovalKind.tool, toolName: 'Bash'),
      ]));
      final cubit = HubCubit(watchHub: WatchHub(repo), decideApproval: DecideApproval(repo), retry: RetryConnection(repo));
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
      final cubit = NewSessionCubit(hub: hub, createSession: CreateSession(FakeHubRepository(hub)), preferredNode: 'laptop');
      expect(cubit.state.node, 'laptop');
      expect(cubit.state.cwd, r'C:\code\app');
      cubit.selectNode('minipc');
      expect(cubit.state.cwd, '/srv/old');
    });

    test('validation failures stay in the form', () async {
      final hub = snapshotWith([]);
      final repo = FakeHubRepository(hub);
      final cubit = NewSessionCubit(hub: hub, createSession: CreateSession(repo));
      await cubit.submit('   ');
      expect(cubit.state.failure, isA<ValidationFailure>());
      expect(cubit.state.createdId, isNull);
      await cubit.submit('do the thing');
      expect(cubit.state.createdId, 'new-session');
      expect(repo.created.single.prompt, 'do the thing');
    });
  });
}
