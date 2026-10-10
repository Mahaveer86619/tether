import 'dart:async';

import 'package:fixnum/fixnum.dart';

import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../../gen/tether/v1/render.pb.dart' as rpb;
import '../../gen/tether/v1/tether.pb.dart' as pb;
import '../datasources/hub_endpoint.dart';
import '../datasources/hub_rest_api.dart';
import '../datasources/hub_socket.dart';
import '../mappers/hub_mappers.dart';
import 'failure_mapper.dart';

/// Combines the REST API (commands, history) with the WebSocket (live
/// pushes) into one consistent view of the hub.
class HubRepositoryImpl implements HubRepository {
  HubRepositoryImpl({required this._api, required this._socket, this.keepTimeline = const Duration(seconds: 30)}) {
    _socketSub = _socket.events.listen(_onSocket);
  }

  final HubRestApi _api;
  final HubSocket _socket;
  final Duration keepTimeline;
  late final StreamSubscription<SocketEvent> _socketSub;

  final _hub = StreamController<HubSnapshot>.broadcast();
  final _timelines = <String, _Timeline>{};
  HubSnapshot _snap = const HubSnapshot();

  @override
  HubSnapshot get current => _snap;

  @override
  void connect(HubConnection connection) {
    final endpoint = HubEndpoint(connection.url, connection.token);
    _api.endpoint = endpoint;
    _emit(_snap.copyWith(status: ConnectionStatus.connecting, endpoint: connection.url, lastError: () => null));
    _socket.connect(endpoint);
  }

  @override
  void retryNow() => _socket.retryNow();

  @override
  Stream<HubSnapshot> watchHub() async* {
    yield _snap;
    yield* _hub.stream;
  }

  void _emit(HubSnapshot s) {
    if (s == _snap) return;
    _snap = s;
    if (!_hub.isClosed) _hub.add(s);
  }

  // ---- live events ----

  void _onSocket(SocketEvent ev) {
    switch (ev) {
      case SocketConnecting():
        if (_snap.status != ConnectionStatus.connected) _emit(_snap.copyWith(status: ConnectionStatus.connecting));
      case SocketClosed(:final error, :final unauthorized):
        _emit(_snap.copyWith(
          status: unauthorized ? ConnectionStatus.unauthorized : ConnectionStatus.offline,
          nodes: {for (final n in _snap.nodes.values) n.name: _offline(n)},
          lastError: () => unauthorized ? const UnauthorizedFailure().userMessage : error,
        ));
        for (final t in _timelines.values) {
          t.subscribed = false;
        }
      case SocketFrame(:final frame):
        _onFrame(frame);
    }
  }

  void _onFrame(pb.Frame f) {
    switch (f.whichBody()) {
      case pb.Frame_Body.welcome:
        final w = f.welcome;
        _emit(_snap.copyWith(
          status: ConnectionStatus.connected,
          hubVersion: w.hubVersion,
          nodes: {for (final n in w.nodes) n.node: nodeFromPb(n)},
          sessions: {for (final s in w.sessions) s.id: sessionFromPb(s)},
          approvals: {for (final a in w.pendingApprovals) a.approvalId: approvalFromPb(a)},
          lastError: () => null,
        ));
        for (final t in _timelines.values) {
          if (t.refs > 0) t.started ? _subscribe(t) : _start(t);
        }
      case pb.Frame_Body.nodeStatus:
        _emit(_snap.copyWith(nodes: {..._snap.nodes, f.nodeStatus.node: nodeFromPb(f.nodeStatus)}));
      case pb.Frame_Body.sessionInfo:
        _emit(_snap.copyWith(sessions: {..._snap.sessions, f.sessionInfo.id: sessionFromPb(f.sessionInfo)}));
      case pb.Frame_Body.approvalRequested:
        final a = approvalFromPb(f.approvalRequested);
        _emit(_snap.copyWith(approvals: {..._snap.approvals, a.id: a}));
      case pb.Frame_Body.approvalResolved:
        _emit(_snap.copyWith(approvals: {..._snap.approvals}..remove(f.approvalResolved.approvalId)));
      case pb.Frame_Body.timeline:
        final t = _timelines[f.timeline.session];
        // An empty update answering our subscribe marks the end of the replay.
        t?.apply(f.timeline.items, f.seq, endOfReplay: f.replyTo.isNotEmpty && f.timeline.items.isEmpty);
      case pb.Frame_Body.error when f.error.code == 'unauthorized':
        _emit(_snap.copyWith(status: ConnectionStatus.unauthorized, lastError: () => const UnauthorizedFailure().userMessage));
      default:
        break;
    }
  }

  Node _offline(Node n) => Node(
        name: n.name,
        online: false,
        os: n.os,
        hostname: n.hostname,
        claudeVersion: n.claudeVersion,
        agentVersion: n.agentVersion,
        lastSeen: n.lastSeen,
      );

  // ---- timelines ----

  @override
  Stream<TimelineSnapshot> watchTimeline(String sessionId) async* {
    final t = _timelines.putIfAbsent(sessionId, () => _Timeline(sessionId));
    t.refs++;
    t.drop?.cancel();
    if (!t.started && _snap.connected) _start(t);
    try {
      yield t.snapshot;
      yield* t.changes;
    } finally {
      t.refs--;
      if (t.refs == 0) {
        // Keep it briefly so switching between sessions doesn't refetch.
        t.drop = Timer(keepTimeline, () {
          if (t.refs > 0) return;
          _timelines.remove(sessionId);
          if (t.subscribed) _socket.unsubscribe(sessionId);
          t.close();
        });
      }
    }
  }

  /// Loads stored history over REST, then subscribes for live changes from
  /// that point on.
  Future<void> _start(_Timeline t) async {
    t.started = true;
    final page = await guard(() => _api.fetchTimeline(t.session));
    switch (page) {
      case Ok(:final value):
        t.apply(value.items, value.seq);
      case Err(failure: NotFoundFailure()):
        t.apply(const [], Int64.ZERO, endOfReplay: true);
        return;
      case Err():
        // History comes through the WebSocket replay instead.
        break;
    }
    if (_snap.connected && t.refs > 0) _subscribe(t);
  }

  void _subscribe(_Timeline t) {
    t.subscribed = true;
    _socket.subscribe(t.session, t.seq);
  }

  // ---- commands ----

  @override
  Future<Result<String>> createSession(NewSessionRequest r) => _command(() => _api.createSession(pb.CreateSession(
        node: r.node,
        cwd: r.cwd,
        prompt: r.prompt,
        model: r.model,
        permissionMode: r.permissionMode,
      )));

  @override
  Future<Result<String>> sendMessage(String sessionId, String text, {bool fork = false}) =>
      _command(() => _api.sendMessage(sessionId, text, fork: fork));

  @override
  Future<Result<void>> interrupt(String sessionId) => _command(() => _api.interrupt(sessionId));

  @override
  Future<Result<void>> decideApproval(String approvalId, {required bool allow, String message = ''}) async {
    final r = await _command(() => _api.decide(approvalId, allow: allow, message: message));
    // Optimistic: the hub broadcasts the resolution, but don't wait for it.
    if (r.isOk) _emit(_snap.copyWith(approvals: {..._snap.approvals}..remove(approvalId)));
    return r;
  }

  Future<Result<T>> _command<T>(Future<T> Function() body) async {
    if (_api.endpoint == null) return const Err(NotConnectedFailure());
    return guard(body);
  }

  @override
  Future<void> dispose() async {
    await _socketSub.cancel();
    await _socket.close();
    for (final t in _timelines.values) {
      t.close();
    }
    await _hub.close();
  }
}

class _Timeline {
  _Timeline(this.session);

  final String session;
  final Map<String, rpb.TimelineItem> _items = {};
  final _controller = StreamController<TimelineSnapshot>.broadcast();
  Int64 seq = Int64.ZERO;
  bool loading = true, started = false, subscribed = false;
  int refs = 0, _version = 0;
  Timer? drop, _flush;
  TimelineSnapshot? _cached;

  Stream<TimelineSnapshot> get changes => _controller.stream;

  TimelineSnapshot get snapshot => _cached ??= TimelineSnapshot(
        sessionId: session,
        items: _items.values.toList()..sort((a, b) => a.ord.compareTo(b.ord)),
        loading: loading,
        version: _version,
      );

  void apply(List<rpb.TimelineItem> items, Int64 frameSeq, {bool endOfReplay = false}) {
    for (final it in items) {
      _items[it.itemId] = it;
    }
    if (frameSeq > seq) seq = frameSeq;
    if (endOfReplay) loading = false;
    _version++;
    _cached = null;
    // Streaming text can change many times a second; emit at most every 50ms.
    _flush ??= Timer(const Duration(milliseconds: 50), () {
      _flush = null;
      if (!_controller.isClosed) _controller.add(snapshot);
    });
  }

  void close() {
    drop?.cancel();
    _flush?.cancel();
    _controller.close();
  }
}
