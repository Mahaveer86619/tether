// End-to-end against a real hub with real agents. Skipped unless
// TETHER_HUB and TETHER_TOKEN are set; LIVE_LINUX_CWD and LIVE_WINDOWS_CWD
// must be existing folders on the "minipc" and "laptop" nodes.
//
//   TETHER_HUB=ws://<hub>:7420/ws TETHER_TOKEN=... flutter test test/live
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tether/core/error/failures.dart';
import 'package:tether/core/result.dart';
import 'package:tether/data/datasources/hub_cache.dart';
import 'package:tether/data/datasources/hub_rest_api.dart';
import 'package:tether/data/datasources/hub_socket.dart';
import 'package:tether/data/repositories/hub_repository_impl.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/gen/tether/v1/tether.pb.dart' as pb;

final env = Platform.environment;
final hubUrl = env['TETHER_HUB'] ?? '';
final token = env['TETHER_TOKEN'] ?? '';
final linuxCwd = env['LIVE_LINUX_CWD'] ?? '/tmp/tether-app-e2e';
final windowsCwd = env['LIVE_WINDOWS_CWD'] ?? '';

/// One app instance's worth of data and domain objects.
class Client {
  Client(String name)
      : repo = HubRepositoryImpl(
          api: HubRestApi(http.Client(), clientName: name),
          socket: WebSocketHubSocket(clientName: name, platform: 'test'),
          cache: _NoCache(),
        ) {
    repo.connect(HubConnection(url: hubUrl, token: token));
  }

  final HubRepositoryImpl repo;
  late final create = CreateSession(repo);
  late final send = SendMessage(repo);
  late final decide = DecideApproval(repo);

  Future<HubSnapshot> hubWhere(bool Function(HubSnapshot) test, {Duration timeout = const Duration(seconds: 30)}) =>
      repo.watchHub().firstWhere(test).timeout(timeout);

  /// Waits for an assistant reply containing [text] in the session's timeline.
  Future<void> replyContaining(String session, String text, {Duration timeout = const Duration(seconds: 150)}) =>
      repo
          .watchTimeline(session)
          .firstWhere((t) => t.items.any((i) =>
              i.whichKind() == TimelineItem_Kind.markdown &&
              !i.markdown.streaming &&
              i.markdown.blocks.any((b) => b.paragraph.spans.any((s) => s.text.contains(text)))))
          .timeout(timeout);

  /// Approves anything the session asks for (folder trust, tools) until
  /// [until] completes.
  void autoApprove(String session, Future<void> until) {
    final sub = repo.watchHub().listen((h) {
      for (final a in h.approvalsFor(session)) {
        decide(a.id, allow: true);
      }
    });
    until.whenComplete(sub.cancel);
  }
}

T ok<T>(Result<T> r) => r.fold((f) => throw TestFailure('${f.runtimeType}: ${f.message}'), (v) => v);

void main() {
  final skip = hubUrl.isEmpty || token.isEmpty ? 'set TETHER_HUB and TETHER_TOKEN to run' : null;
  late Client a, b;

  setUpAll(() async {
    if (skip != null) return;
    a = Client('live-test-A');
    b = Client('live-test-B');
    await Future.wait([a.hubWhere((h) => h.connected), b.hubWhere((h) => h.connected)]);
  });

  tearDownAll(() async {
    if (skip != null) return;
    await a.repo.dispose();
    await b.repo.dispose();
  });

  test('both clients see both devices', () async {
    for (final c in [a, b]) {
      final h = c.repo.current;
      expect(h.nodes['minipc']?.online, isTrue, reason: 'minipc agent online');
      expect(h.nodes['laptop']?.online, isTrue, reason: 'laptop agent online');
    }
  }, skip: skip);

  late String tmuxSession;

  test('A starts a tmux session on minipc; B watches it live', () async {
    tmuxSession = ok(await a.create(NewSessionRequest(node: 'minipc', cwd: linuxCwd, model: 'haiku', prompt: 'Reply with exactly: pong-one')));
    final seenByB = b.replyContaining(tmuxSession, 'pong-one');
    a.autoApprove(tmuxSession, seenByB);
    await seenByB;
    final s = await b.hubWhere((h) => h.sessions[tmuxSession]?.state == SessionState.ready);
    expect(s.sessions[tmuxSession]!.host, SessionHost.tmux);
    expect(s.sessions[tmuxSession]!.attachCommand, contains('tmux attach'));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 4)));

  test('B continues the session; A sees the reply', () async {
    ok(await b.send(tmuxSession, 'Reply with exactly: pong-two'));
    final seenByA = a.replyContaining(tmuxSession, 'pong-two');
    b.autoApprove(tmuxSession, seenByA);
    await seenByA;
  }, skip: skip, timeout: const Timeout(Duration(minutes: 4)));

  test('A forks it into a new session', () async {
    final fork = ok(await a.send(tmuxSession, 'Reply with exactly: pong-three', fork: true));
    expect(fork, isNot(tmuxSession));
    final seen = a.replyContaining(fork, 'pong-three');
    a.autoApprove(fork, seen);
    await seen;
    expect(a.repo.current.sessions[fork]?.node, 'minipc');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 4)));

  test('B interrupts and then ends the tmux session', () async {
    ok(await b.send(tmuxSession, 'Write the numbers 1 to 300 as words, one per line. No tools.'));
    await b.hubWhere((h) => h.sessions[tmuxSession]?.state == SessionState.running);
    ok(await b.repo.interrupt(tmuxSession));
    await b.hubWhere((h) => h.sessions[tmuxSession]?.state == SessionState.ready, timeout: const Duration(seconds: 60));
    ok(await EndSession(b.repo)(tmuxSession));
    final h = await a.hubWhere((h) => h.sessions[tmuxSession]?.host == SessionHost.none, timeout: const Duration(seconds: 30));
    expect(h.sessions[tmuxSession]!.state, SessionState.idle);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

  test('A starts a headless session on the laptop', () async {
    final id = ok(await a.create(NewSessionRequest(node: 'laptop', cwd: windowsCwd, model: 'haiku', prompt: 'Reply with exactly: pong-four')));
    final seenByB = b.replyContaining(id, 'pong-four');
    a.autoApprove(id, seenByB);
    await seenByB;
    expect((await a.hubWhere((h) => h.sessions[id]?.host == SessionHost.headless)).sessions[id]!.node, 'laptop');
  }, skip: skip == null && windowsCwd.isEmpty ? 'set LIVE_WINDOWS_CWD' : skip, timeout: const Timeout(Duration(minutes: 4)));

  test("typing into a terminal you're using is refused, forking is offered", () async {
    // Never sends to a terminal the agent can type into: those are your
    // real sessions, and the message would really be typed there.
    final open = a.repo.current.sessions.values
        .where((s) => s.host == SessionHost.terminal && s.state != SessionState.idle && !s.terminalInput)
        .firstOrNull;
    if (open == null) {
      markTestSkipped('no terminal session that refuses input is open right now');
      return;
    }
    final r = await a.send(open.id, 'hello from the app');
    expect(r.failureOrNull, isA<TerminalActiveFailure>());
  }, skip: skip);

  test('hub errors map to typed failures', () async {
    expect((await a.repo.sendMessage('no-such-session', 'x')).failureOrNull, isA<NotFoundFailure>());
    final bad = HubRestApi(http.Client(), clientName: 'bad');
    final badRepo = HubRepositoryImpl(api: bad, socket: WebSocketHubSocket(clientName: 'bad', platform: 'test'), cache: _NoCache());
    badRepo.connect(HubConnection(url: hubUrl, token: 'wrong-token'));
    expect((await badRepo.interrupt('x')).failureOrNull, isA<UnauthorizedFailure>());
    final h = await badRepo.watchHub().firstWhere((h) => h.status == ConnectionStatus.unauthorized).timeout(const Duration(seconds: 15));
    expect(h.lastError, isNotNull);
    await badRepo.dispose();
  }, skip: skip);
}

/// The live tests check the hub, not the device cache.
class _NoCache implements HubCache {
  @override
  Future<pb.TimelinePage?> readTimeline(String session) async => null;
  @override
  Future<void> writeTimeline(pb.TimelinePage page) async {}
  @override
  Future<pb.Welcome?> readState() async => null;
  @override
  Future<void> writeState(pb.Welcome state) async {}
  @override
  Future<void> clear() async {}
}
