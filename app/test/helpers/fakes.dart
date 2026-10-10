import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:tether/core/result.dart';
import 'package:tether/data/datasources/hub_endpoint.dart';
import 'package:tether/data/datasources/hub_socket.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;

/// A hub repository driven by the test.
class FakeHubRepository implements HubRepository {
  FakeHubRepository([HubSnapshot? initial]) : _snap = initial ?? const HubSnapshot();

  HubSnapshot _snap;
  final _hub = StreamController<HubSnapshot>.broadcast();
  final timelines = <String, StreamController<TimelineSnapshot>>{};
  final sent = <(String, String, bool)>[];
  final created = <NewSessionRequest>[];
  final decided = <(String, bool)>[];
  final interrupted = <String>[];

  Result<String> Function(String session, bool fork)? onSend;
  Result<String>? createResult;
  Result<void>? decideResult;

  void emitHub(HubSnapshot s) {
    _snap = s;
    _hub.add(s);
  }

  void emitTimeline(String id, List<rpb.TimelineItem> items, {bool loading = false, int version = 1}) =>
      timelines[id]!.add(TimelineSnapshot(sessionId: id, items: items, loading: loading, version: version));

  @override
  HubSnapshot get current => _snap;

  @override
  void connect(HubConnection connection) {}

  @override
  void retryNow() {}

  @override
  Stream<HubSnapshot> watchHub() async* {
    yield _snap;
    yield* _hub.stream;
  }

  @override
  Stream<TimelineSnapshot> watchTimeline(String sessionId) async* {
    final c = timelines.putIfAbsent(sessionId, StreamController<TimelineSnapshot>.broadcast);
    yield TimelineSnapshot(sessionId: sessionId);
    yield* c.stream;
  }

  @override
  Future<Result<String>> createSession(NewSessionRequest request) async {
    created.add(request);
    return createResult ?? const Ok('new-session');
  }

  @override
  Future<Result<String>> sendMessage(String sessionId, String text, {bool fork = false}) async {
    sent.add((sessionId, text, fork));
    return onSend?.call(sessionId, fork) ?? Ok(fork ? 'fork-of-$sessionId' : sessionId);
  }

  @override
  Future<Result<void>> interrupt(String sessionId) async {
    interrupted.add(sessionId);
    return const Ok(null);
  }

  @override
  Future<Result<void>> decideApproval(String approvalId, {required bool allow, String message = ''}) async {
    decided.add((approvalId, allow));
    return decideResult ?? const Ok(null);
  }

  @override
  Future<void> dispose() async => _hub.close();
}

class FakeSettingsRepository implements SettingsRepository {
  HubConnection saved = const HubConnection(url: '', token: '');
  ThemeMode theme = ThemeMode.system;

  @override
  Future<Result<HubConnection>> loadConnection() async => Ok(saved);

  @override
  Future<Result<void>> saveConnection(HubConnection connection) async {
    saved = connection;
    return const Ok(null);
  }

  @override
  Future<ThemeMode> loadThemeMode() async => theme;

  @override
  Future<Result<void>> saveThemeMode(ThemeMode mode) async {
    theme = mode;
    return const Ok(null);
  }
}

/// A socket whose events the test pushes by hand.
class FakeHubSocket implements HubSocket {
  final _events = StreamController<SocketEvent>.broadcast(sync: true);
  final subscribed = <(String, Int64)>[];
  final unsubscribed = <String>[];
  HubEndpoint? endpoint;

  void push(SocketEvent e) => _events.add(e);

  @override
  Stream<SocketEvent> get events => _events.stream;

  @override
  void connect(HubEndpoint endpoint) => this.endpoint = endpoint;

  @override
  void retryNow() {}

  @override
  void subscribe(String session, Int64 afterSeq) => subscribed.add((session, afterSeq));

  @override
  void unsubscribe(String session) => unsubscribed.add(session);

  @override
  Future<void> close() => _events.close();
}

const laptop = Node(name: 'laptop', online: true, os: 'windows');
const minipc = Node(name: 'minipc', online: true, os: 'linux');

Session session(String id,
        {String node = 'minipc', SessionState state = SessionState.ready, SessionHost host = SessionHost.tmux, String cwd = '/srv/app'}) =>
    Session(id: id, node: node, title: 'Session $id', state: state, host: host, cwd: cwd, updated: DateTime(2026, 10, 11));

HubSnapshot snapshotWith(List<Session> sessions, {List<Approval> approvals = const [], List<Node> nodes = const [laptop, minipc]}) =>
    HubSnapshot(
      status: ConnectionStatus.connected,
      nodes: {for (final n in nodes) n.name: n},
      sessions: {for (final s in sessions) s.id: s},
      approvals: {for (final a in approvals) a.id: a},
    );
