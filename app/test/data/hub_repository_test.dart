import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tether/core/error/failures.dart';
import 'package:tether/data/datasources/hub_rest_api.dart';
import 'package:tether/data/datasources/hub_socket.dart';
import 'package:tether/data/repositories/hub_repository_impl.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/gen/tether/v1/tether.pb.dart' as pb;
import 'package:tether/gen/tether/v1/tether.pbenum.dart' as pbe;

import '../helpers/fakes.dart';

pb.Frame welcome() => pb.Frame(
      welcome: pb.Welcome(
        hubVersion: 'test',
        nodes: [pb.NodeStatus(node: 'minipc', online: true, os: 'linux')],
        sessions: [
          pb.SessionInfo(
            id: 's1',
            node: 'minipc',
            title: 'Fix tests',
            state: pbe.SessionState.SESSION_STATE_RUNNING,
            host: pbe.SessionHost.SESSION_HOST_TMUX,
            attachCommand: 'tmux attach -t tether:claude-s1',
          ),
        ],
      ),
    );

/// Waits until [check] passes, so timing on a busy test machine can't flake.
Future<void> eventually(void Function() check, {Duration timeout = const Duration(seconds: 3)}) async {
  final end = DateTime.now().add(timeout);
  while (true) {
    try {
      check();
      return;
    } catch (_) {
      if (DateTime.now().isAfter(end)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}

rpb.TimelineItem item(String id, int ord, String text) =>
    rpb.TimelineItem(itemId: id, ord: Int64(ord), user: rpb.UserText(text: text));

void main() {
  late FakeHubSocket socket;
  late HubRepositoryImpl repo;
  late List<http.Request> requests;
  late MemoryHubCache cache;

  setUp(() {
    socket = FakeHubSocket();
    cache = MemoryHubCache();
    requests = [];
    final api = HubRestApi(
      MockClient((req) async {
        requests.add(req);
        if (req.url.path.endsWith('/timeline')) {
          final page = pb.TimelinePage(session: 's1', seq: Int64(2), items: [item('a', 1, 'first'), item('b', 2, 'second')]);
          return http.Response(jsonEncode(page.toProto3Json()), 200);
        }
        if (req.url.path.endsWith('/messages')) {
          return http.Response('{"code":"terminal_active","message":"open"}', 409);
        }
        return http.Response('{"session":"new"}', 200);
      }),
      clientName: 'test',
    );
    repo = HubRepositoryImpl(
      api: api,
      socket: socket,
      cache: cache,
      keepTimeline: const Duration(milliseconds: 10),
      keepBackground: const Duration(milliseconds: 10),
    );
    repo.connect(const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 'tok'));
  });

  tearDown(() => repo.dispose());

  test('welcome becomes a snapshot of domain entities', () async {
    socket.push(SocketFrame(welcome()));
    final s = repo.current;
    expect(s.status, ConnectionStatus.connected);
    expect(s.sessions['s1']!.state, SessionState.running);
    expect(s.sessions['s1']!.host, SessionHost.tmux);
    expect(s.sessions['s1']!.acceptsInput, isTrue);
    expect(s.nodes['minipc']!.online, isTrue);
  });

  test('push updates replace sessions and approvals', () async {
    socket.push(SocketFrame(welcome()));
    socket.push(SocketFrame(pb.Frame(sessionInfo: pb.SessionInfo(id: 's1', node: 'minipc', state: pbe.SessionState.SESSION_STATE_READY))));
    socket.push(SocketFrame(pb.Frame(approvalRequested: pb.ApprovalRequest(approvalId: 'ap', session: 's1', toolName: 'Bash'))));
    expect(repo.current.sessions['s1']!.state, SessionState.ready);
    expect(repo.current.approvalsFor('s1').single.toolName, 'Bash');
    socket.push(SocketFrame(pb.Frame(approvalResolved: pb.ApprovalResolved(approvalId: 'ap'))));
    expect(repo.current.approvals, isEmpty);
  });

  test('a dialog read off the screen arrives as a prompt with its options', () async {
    socket.push(SocketFrame(welcome()));
    socket.push(SocketFrame(pb.Frame(
      approvalRequested: pb.ApprovalRequest(
        approvalId: 'p1',
        session: 's1',
        kind: pbe.ApprovalRequest_Kind.KIND_PROMPT,
        description: 'How is Claude doing?',
        options: ['Bad', 'Fine', 'Good'],
        selected: 1,
        screen: '1: Bad  2: Fine  3: Good',
      ),
    )));
    final a = repo.current.approvalsFor('s1').single;
    expect(a.kind, ApprovalKind.prompt);
    expect(a.options, ['Bad', 'Fine', 'Good']);
    expect(a.selected, 1);
    expect(a.screen, contains('2: Fine'));
  });

  test('losing the socket marks everything offline, unauthorized stops', () async {
    socket.push(SocketFrame(welcome()));
    socket.push(const SocketClosed(error: 'reset'));
    expect(repo.current.status, ConnectionStatus.offline);
    expect(repo.current.nodes['minipc']!.online, isFalse);
    socket.push(const SocketClosed(unauthorized: true));
    expect(repo.current.status, ConnectionStatus.unauthorized);
  });

  test('timeline loads history over REST, then subscribes after its seq and merges live updates', () async {
    socket.push(SocketFrame(welcome()));
    final snapshots = <TimelineSnapshot>[];
    final sub = repo.watchTimeline('s1').listen(snapshots.add);
    await eventually(() => expect(snapshots.last.items.map((i) => i.itemId), ['a', 'b']));
    expect(requests.where((r) => r.url.path.contains('/timeline')).single.url.path, '/api/v1/sessions/s1/timeline');
    expect(socket.subscribed.single, ('s1', Int64(2)));

    // A live update replaces "b" and adds "c"; the end-of-replay marker ends loading.
    socket.push(SocketFrame(pb.Frame(seq: Int64(4), timeline: pb.TimelineUpdate(session: 's1', items: [item('b', 2, 'edited'), item('c', 3, 'third')]))));
    socket.push(SocketFrame(pb.Frame(replyTo: 'x', seq: Int64(4), timeline: pb.TimelineUpdate(session: 's1'))));
    await eventually(() {
      expect(snapshots.last.items.map((i) => i.user.text), ['first', 'edited', 'third']);
      expect(snapshots.last.loading, isFalse);
    });

    // Reconnecting resubscribes from the last seen seq, not from zero.
    socket.push(const SocketClosed(error: 'drop'));
    socket.push(SocketFrame(welcome()));
    expect(socket.subscribed.last, ('s1', Int64(4)));

    // s1 is working, so it stays subscribed in the background after the
    // screen closes; once it goes idle it is released.
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(repo.backgroundSessions, {'s1'});
    expect(socket.unsubscribed, isEmpty);
    socket.push(SocketFrame(pb.Frame(sessionInfo: pb.SessionInfo(id: 's1', node: 'minipc', state: pbe.SessionState.SESSION_STATE_READY))));
    await eventually(() => expect(socket.unsubscribed, ['s1']));
    expect(repo.backgroundSessions, isEmpty);
  });

  test('history is cached on the device and reused, fetching only what changed', () async {
    socket.push(SocketFrame(welcome()));
    final first = repo.watchTimeline('s1').listen((_) {});
    await eventually(() => expect(cache.timelines['s1']?.items.length, 2));
    expect(cache.timelines['s1']!.seq, Int64(2));
    await first.cancel();
    await eventually(() => expect(cache.state?.sessions.single.id, 's1'));

    // A fresh repository (app restart) shows the cached chat before the
    // hub answers, then asks only for changes after the cached seq.
    final socket2 = FakeHubSocket();
    final requests2 = <http.Request>[];
    final repo2 = HubRepositoryImpl(
      api: HubRestApi(
        MockClient((req) async {
          requests2.add(req);
          return http.Response(jsonEncode(pb.TimelinePage(session: 's1', seq: Int64(2)).toProto3Json()), 200);
        }),
        clientName: 'test',
      ),
      socket: socket2,
      cache: cache,
    );
    repo2.connect(const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 'tok'));
    await eventually(() => expect(repo2.current.sessions.keys, ['s1']), timeout: const Duration(seconds: 2));
    final offline = await repo2.watchTimeline('s1').firstWhere((t) => t.items.length == 2).timeout(const Duration(seconds: 2));
    expect(offline.items.first.user.text, 'first');
    socket2.push(SocketFrame(welcome()));
    await eventually(() => expect(requests2.where((r) => r.url.path.contains('/timeline')).single.url.queryParameters['after'], '2'));
    await repo2.dispose();
  });

  test('a cache ahead of the hub (hub reset) is thrown away', () async {
    cache.timelines['s1'] = pb.TimelinePage(session: 's1', seq: Int64(50), items: [item('old', 1, 'stale')]);
    socket.push(SocketFrame(welcome()));
    final snaps = <TimelineSnapshot>[];
    final sub = repo.watchTimeline('s1').listen(snaps.add);
    await eventually(() => expect(snaps.last.items.map((i) => i.itemId), ['a', 'b']));
    await sub.cancel();
  });

  test('command errors come back as failures', () async {
    socket.push(SocketFrame(welcome()));
    final r = await repo.sendMessage('s1', 'hi');
    expect(r.failureOrNull, isA<TerminalActiveFailure>());
    expect((await repo.createSession(const NewSessionRequest(node: 'minipc', prompt: 'x'))).valueOrNull, 'new');
  });
}
