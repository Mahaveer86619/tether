import 'dart:async';

import 'package:fixnum/fixnum.dart';

import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../../gen/tether/v1/render.pb.dart' as rpb;
import '../../gen/tether/v1/tether.pb.dart' as pb;
import '../datasources/hub_cache.dart';
import '../datasources/hub_endpoint.dart';
import '../datasources/hub_rest_api.dart';
import '../datasources/hub_socket.dart';
import '../mappers/hub_mappers.dart';
import 'failure_mapper.dart';

/// Combines the REST API (commands, history), the WebSocket (live pushes)
/// and the on-device cache into one consistent view of the hub.
class HubRepositoryImpl implements HubRepository {
  HubRepositoryImpl({
    required this._api,
    required this._socket,
    required this._cache,
    this.keepTimeline = const Duration(seconds: 30),
    this.keepBackground = const Duration(minutes: 2),
  }) {
    _socketSub = _socket.events.listen(_onSocket);
  }

  final HubRestApi _api;
  final HubSocket _socket;
  final HubCache _cache;
  final Duration keepTimeline;

  /// How long a session that stopped working stays subscribed in the
  /// background.
  final Duration keepBackground;
  late final StreamSubscription<SocketEvent> _socketSub;

  final _hub = StreamController<HubSnapshot>.broadcast();
  final _timelines = <String, _Timeline>{};
  final _background = <String, StreamSubscription<TimelineSnapshot>>{};
  final _backgroundDrop = <String, Timer>{};
  HubSnapshot _snap = const HubSnapshot();

  // Wire copies of the state, kept for the on-device cache.
  final _wireNodes = <String, pb.NodeStatus>{};
  final _wireSessions = <String, pb.SessionInfo>{};
  Timer? _saveState;

  @override
  HubSnapshot get current => _snap;

  @override
  void connect(HubConnection connection) {
    final endpoint = HubEndpoint(connection.url, connection.token, fingerprint: connection.fingerprint);
    _api.endpoint = endpoint;
    _emit(_snap.copyWith(status: ConnectionStatus.connecting, endpoint: connection.url, lastError: () => null));
    if (_snap.sessions.isEmpty) _restoreState();
    _socket.connect(endpoint);
  }

  @override
  Future<void> disconnect() async {
    _saveState?.cancel();
    _socket.disconnect();
    _api.endpoint = null;
    _wireNodes.clear();
    _wireSessions.clear();
    _emit(const HubSnapshot());
    await _cache.clear().catchError((Object _) {});
  }

  /// Shows the last known devices and sessions until the hub answers.
  Future<void> _restoreState() async {
    final cached = await _cache.readState();
    if (cached == null || _snap.connected || _snap.sessions.isNotEmpty) return;
    for (final n in cached.nodes) {
      _wireNodes[n.node] = n..online = false;
    }
    for (final s in cached.sessions) {
      _wireSessions[s.id] = s;
    }
    _emit(_snap.copyWith(
      nodes: {for (final n in _wireNodes.values) n.node: nodeFromPb(n)},
      sessions: {for (final s in _wireSessions.values) s.id: sessionFromPb(s)},
      deviceId: cached.deviceId,
      clientIp: cached.clientIp,
    ));
  }

  void _scheduleStateSave() {
    _saveState?.cancel();
    _saveState = Timer(const Duration(seconds: 2), () {
      _cache
          .writeState(pb.Welcome(nodes: _wireNodes.values, sessions: _wireSessions.values, deviceId: _snap.deviceId, clientIp: _snap.clientIp))
          .catchError((Object _) {});
    });
  }

  @override
  void retryNow() => _socket.retryNow();

  @override
  void setActive({required bool active}) => _socket.setPresence(active: active);

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
        _wireNodes
          ..clear()
          ..addEntries(w.nodes.map((n) => MapEntry(n.node, n)));
        _wireSessions
          ..clear()
          ..addEntries(w.sessions.map((s) => MapEntry(s.id, s)));
        _emit(_snap.copyWith(
          status: ConnectionStatus.connected,
          hubVersion: w.hubVersion,
          hubNode: w.hubNode,
          deviceId: w.deviceId,
          clientIp: w.clientIp,
          nodes: {for (final n in w.nodes) n.node: nodeFromPb(n)},
          sessions: {for (final s in w.sessions) s.id: sessionFromPb(s)},
          approvals: {for (final a in w.pendingApprovals) a.approvalId: approvalFromPb(a)},
          lastError: () => null,
          preferences: () => w.hasPreferences() ? appearanceFromPb(w.preferences) : null,
        ));
        _scheduleStateSave();
        _loadArtifacts();
        for (final t in _timelines.values) {
          if (t.refs > 0) t.started ? _subscribe(t) : _start(t);
        }
        _syncBackground();
      case pb.Frame_Body.artifactAdded:
        final a = artifactFromPb(f.artifactAdded);
        _emit(_snap.copyWith(artifacts: {..._snap.artifacts, a.id: a}));
      case pb.Frame_Body.preferences:
        _emit(_snap.copyWith(preferences: () => appearanceFromPb(f.preferences)));
      case pb.Frame_Body.nodeStatus:
        _wireNodes[f.nodeStatus.node] = f.nodeStatus;
        _emit(_snap.copyWith(nodes: {..._snap.nodes, f.nodeStatus.node: nodeFromPb(f.nodeStatus)}));
        _scheduleStateSave();
      case pb.Frame_Body.sessionInfo:
        _wireSessions[f.sessionInfo.id] = f.sessionInfo;
        _emit(_snap.copyWith(sessions: {..._snap.sessions, f.sessionInfo.id: sessionFromPb(f.sessionInfo)}));
        _scheduleStateSave();
        _syncBackground();
      case pb.Frame_Body.sessionRemoved:
        final id = f.sessionRemoved.session;
        _wireSessions.remove(id);
        _emit(_snap.copyWith(sessions: {..._snap.sessions}..remove(id)));
        _cache.removeTimeline(id);
        _scheduleStateSave();
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

  /// Keeps sessions that are working subscribed even when no screen shows
  /// them, so their chat is current the moment you open one.
  void _syncBackground() {
    for (final s in _snap.sessions.values) {
      if (!s.isBusy) continue;
      _backgroundDrop.remove(s.id)?.cancel();
      _background[s.id] ??= watchTimeline(s.id).listen((_) {});
    }
    for (final id in _background.keys.toList()) {
      final s = _snap.sessions[id];
      if (s != null && s.isBusy) continue;
      _backgroundDrop[id] ??= Timer(keepBackground, () {
        _backgroundDrop.remove(id);
        _background.remove(id)?.cancel();
      });
    }
  }

  /// Sessions currently followed in the background.
  Set<String> get backgroundSessions => _background.keys.toSet();

  // ---- timelines ----

  @override
  Stream<TimelineSnapshot> watchTimeline(String sessionId) async* {
    final t = _timelines.putIfAbsent(sessionId, () => _Timeline(sessionId, _cache));
    t.refs++;
    t.drop?.cancel();
    if (!t.started && _snap.connected) {
      _start(t);
    } else if (!t.cacheLoaded) {
      _loadCache(t);
    }
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

  Future<void> _loadCache(_Timeline t) async {
    t.cacheLoaded = true;
    final cached = await _cache.readTimeline(t.session);
    if (cached != null && t.isEmpty) t.apply(cached.items, cached.seq, persist: false);
  }

  /// Shows cached history at once, fetches only what changed since over
  /// REST, then subscribes for live changes from that point on.
  Future<void> _start(_Timeline t) async {
    t.started = true;
    if (!t.cacheLoaded) await _loadCache(t);
    var page = await guard(() => _api.fetchTimeline(t.session, after: t.seq));
    if (page case Ok(:final value) when value.seq < t.seq) {
      // The hub's history is shorter than our cache: it was reset.
      t.reset();
      page = await guard(() => _api.fetchTimeline(t.session));
    }
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
        createCwd: r.createCwd,
        scratch: r.scratch,
        attachments: r.attachments,
      )));

  @override
  Future<Result<String>> sendMessage(String sessionId, String text, {bool fork = false, List<String> attachments = const [], String clientId = ''}) =>
      _command(() => _api.sendMessage(sessionId, text, fork: fork, attachments: attachments, clientId: clientId));

  @override
  Future<Result<void>> setGlobal(String sessionId, {required bool global}) => _command(() => _api.setGlobal(sessionId, global: global));

  @override
  Future<Result<String>> continueOnHub(String sessionId, String text) => _command(() => _api.continueOnHub(sessionId, text));

  @override
  Future<Result<List<int>>> artifactBytes(String id) => _command(() => _api.artifactBytes(id));

  @override
  Future<Result<String>> artifactLink(String id) => _command(() => _api.artifactLink(id));

  @override
  Future<Result<List<Codebase>>> codebases() => _command(() async => [for (final c in (await _api.codebases()).codebases) codebaseFromPb(c)]);

  @override
  Future<Result<void>> snapshotCodebase(String id) => _command(() => _api.snapshotCodebase(id));

  @override
  Future<Result<List<HostedPage>>> pages({String session = ''}) => _command(() async => [for (final p in await _api.pages(session: session)) pageFromPb(p)]);

  @override
  Future<Result<void>> deleteArtifact(String id) => _command(() async {
        await _api.deleteArtifact(id);
        _emit(_snap.copyWith(artifacts: {..._snap.artifacts}..remove(id)));
      });

  /// Loads recent artifacts after (re)connecting; new ones arrive as frames.
  Future<void> _loadArtifacts() async {
    try {
      final list = await _api.artifacts();
      _emit(_snap.copyWith(artifacts: {for (final a in list.artifacts) a.id: artifactFromPb(a)}));
    } on Exception {
      // Not worth a toast: tool cards just show no thumbnails.
    }
  }

  @override
  Future<Result<void>> interrupt(String sessionId) => _command(() => _api.interrupt(sessionId));

  @override
  Future<Result<void>> endSession(String sessionId) => _command(() => _api.stop(sessionId));

  @override
  Future<Result<void>> savePreferences(Appearance appearance) => _command(() => _api.savePreferences(appearanceToPb(appearance)));

  @override
  Future<Result<List<WorkspaceRoot>>> workspaces() =>
      _command(() async => [for (final r in (await _api.workspaces()).roots) WorkspaceRoot(node: r.node, path: r.path)]);

  @override
  Future<Result<List<WorkspaceRoot>>> setWorkspaceRoot(WorkspaceRoot root, {required bool remove}) => _command(() async => [
        for (final r in (await _api.setWorkspaceRoot(pb.WorkspaceRoot(node: root.node, path: root.path), remove: remove)).roots)
          WorkspaceRoot(node: r.node, path: r.path),
      ]);

  @override
  Future<Result<UsageSummary>> usage() => _command(() async => usageFromPb(await _api.usage()));

  @override
  Future<Result<List<ConnectedClient>>> clients() => _command(() async => [for (final c in (await _api.clients()).clients) clientFromPb(c)]);

  @override
  Future<Result<List<TailnetDevice>>> tailnet() => _command(() async {
        final t = await _api.tailnet();
        if (t.error.isNotEmpty && t.devices.isEmpty) throw ApiException(statusCode: 500, code: 'tailscale', message: t.error);
        return [for (final d in t.devices) tailnetDeviceFromPb(d)];
      });

  @override
  Future<Result<PairingInvite>> createPairingInvite() => _command(() async {
        final code = await _api.createPairingCode();
        return PairingInvite(
          code: code.code,
          expires: DateTime.fromMillisecondsSinceEpoch(code.expiresMs.toInt()),
          hubUrl: _api.endpoint!.ws.toString(),
          fingerprint: code.certFingerprint.isNotEmpty ? code.certFingerprint : _api.endpoint!.fingerprint,
        );
      });

  @override
  Future<Result<List<PairedDevice>>> listDevices() =>
      _command(() async => [for (final d in (await _api.devices()).devices) deviceFromPb(d)]);

  @override
  Future<Result<void>> revokeDevice(String id) => _command(() => _api.revokeDevice(id));

  @override
  Future<Result<String>> pair({
    required String url,
    required String code,
    required String fingerprint,
    required String name,
    required String platform,
  }) =>
      guard(() async => (await _api.pair(url, fingerprint, pb.PairRequest(code: code, kind: 'client', name: name, platform: platform))).token);

  @override
  Future<Result<void>> setArchived(String sessionId, {required bool archived}) =>
      _command(() => _api.archive(sessionId, archived: archived));

  @override
  Future<Result<void>> setMode(String sessionId, PermissionMode mode, {Duration? revertAfter}) =>
      _command(() => _api.setMode(sessionId, mode.wire, revertAfter: revertAfter));

  @override
  Future<Result<ScreenSnapshot>> screen(String sessionId) => _command(() async => screenFromPb(await _api.screen(sessionId)));

  @override
  Future<Result<void>> sendKeys(String sessionId, List<String> keys, {String text = ''}) => _command(() => _api.sendKeys(sessionId, keys, text: text));

  @override
  Future<Result<void>> decideApproval(String approvalId, {required bool allow, String message = '', Map<String, String> answers = const {}, int option = 0}) async {
    final r = await _command(() => _api.decide(approvalId, allow: allow, message: message, answers: answers, option: option));
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
    _saveState?.cancel();
    for (final t in _backgroundDrop.values) {
      t.cancel();
    }
    for (final s in _background.values) {
      await s.cancel();
    }
    await _socketSub.cancel();
    await _socket.close();
    for (final t in _timelines.values) {
      t.close();
    }
    await _hub.close();
  }
}

class _Timeline {
  _Timeline(this.session, this._cache);

  final String session;
  final HubCache _cache;
  final Map<String, rpb.TimelineItem> _items = {};
  final _controller = StreamController<TimelineSnapshot>.broadcast();
  Int64 seq = Int64.ZERO;
  bool loading = true, started = false, subscribed = false, cacheLoaded = false;
  int refs = 0, _version = 0;
  Timer? drop, _flush, _persist;
  TimelineSnapshot? _cached;

  Stream<TimelineSnapshot> get changes => _controller.stream;
  bool get isEmpty => _items.isEmpty;

  TimelineSnapshot get snapshot => _cached ??= TimelineSnapshot(
        sessionId: session,
        items: _items.values.toList()..sort((a, b) => a.ord.compareTo(b.ord)),
        loading: loading,
        version: _version,
      );

  void apply(List<rpb.TimelineItem> items, Int64 frameSeq, {bool endOfReplay = false, bool persist = true}) {
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
    if (persist && items.isNotEmpty) {
      _persist?.cancel();
      _persist = Timer(const Duration(seconds: 1), _save);
    }
  }

  void reset() {
    _items.clear();
    seq = Int64.ZERO;
    _version++;
    _cached = null;
  }

  void _save() =>
      _cache.writeTimeline(pb.TimelinePage(session: session, items: _items.values, seq: seq)).catchError((Object _) {});

  void close() {
    drop?.cancel();
    _flush?.cancel();
    if (_persist?.isActive ?? false) {
      _persist!.cancel();
      _save();
    }
    _controller.close();
  }
}
