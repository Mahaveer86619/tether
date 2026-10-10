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

  setUp(() {
    socket = FakeHubSocket();
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
    repo = HubRepositoryImpl(api: api, socket: socket, keepTimeline: const Duration(milliseconds: 10));
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
    expect(requests.single.url.path, '/api/v1/sessions/s1/timeline');
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

    await sub.cancel();
    await eventually(() => expect(socket.unsubscribed, ['s1']));
  });

  test('command errors come back as failures', () async {
    socket.push(SocketFrame(welcome()));
    final r = await repo.sendMessage('s1', 'hi');
    expect(r.failureOrNull, isA<TerminalActiveFailure>());
    expect((await repo.createSession(const NewSessionRequest(node: 'minipc', prompt: 'x'))).valueOrNull, 'new');
  });
}
