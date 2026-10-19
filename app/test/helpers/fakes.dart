import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:tether/core/error/failures.dart';
import 'package:tether/core/result.dart';
import 'package:tether/data/datasources/hub_cache.dart';
import 'package:tether/data/datasources/hub_endpoint.dart';
import 'package:tether/data/datasources/hub_socket.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/gen/tether/v1/tether.pb.dart' as pb;

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
  final archivedCalls = <(String, bool)>[];
  final globalCalls = <(String, bool)>[];
  final attachmentsSent = <List<String>>[];
  final paired = <(String, String, String)>[];
  final sharedPreferences = <Appearance>[];
  var devices = <PairedDevice>[const PairedDevice(id: 'd1', kind: 'client', name: 'Pixel', platform: 'android')];
  final ended = <String>[];
  final answered = <Map<String, String>>[];
  var disconnected = false;

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
  Future<void> disconnect() async {
    disconnected = true;
    emitHub(const HubSnapshot());
  }

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
  Future<Result<String>> sendMessage(String sessionId, String text, {bool fork = false, List<String> attachments = const []}) async {
    sent.add((sessionId, text, fork));
    attachmentsSent.add(attachments);
    return onSend?.call(sessionId, fork) ?? Ok(fork ? 'fork-of-$sessionId' : sessionId);
  }

  @override
  Future<Result<void>> interrupt(String sessionId) async {
    interrupted.add(sessionId);
    return const Ok(null);
  }

  @override
  Future<Result<void>> endSession(String sessionId) async {
    ended.add(sessionId);
    return const Ok(null);
  }

  @override
  Future<Result<void>> savePreferences(Appearance appearance) async {
    sharedPreferences.add(appearance);
    return const Ok(null);
  }

  UsageSummary usageSummary = const UsageSummary(
    nodes: [
      NodeUsage(
        node: 'minipc',
        window: UsageTotals(input: 1000, output: 500, messages: 3),
        plan: PlanUsage(limits: [PlanLimit(label: 'session', percent: 9, resets: 'Oct 12, 3:20am'), PlanLimit(label: 'week (all models)', percent: 10)]),
      ),
      NodeUsage(
        node: 'laptop',
        plan: PlanUsage(limits: [PlanLimit(label: 'session', percent: 9, resets: 'Oct 12, 3:19am'), PlanLimit(label: 'week (all models)', percent: 10)]),
      ),
    ],
    sessions: [SessionUsage(session: 's1', total: UsageTotals(input: 1000, output: 500, messages: 3))],
  );

  var roots = <WorkspaceRoot>[const WorkspaceRoot(node: 'minipc', path: '/srv')];

  @override
  Future<Result<List<WorkspaceRoot>>> workspaces() async => Ok(roots);

  @override
  Future<Result<List<WorkspaceRoot>>> setWorkspaceRoot(WorkspaceRoot root, {required bool remove}) async {
    roots = [...roots.where((r) => r != root), if (!remove) root];
    return Ok(roots);
  }

  @override
  Future<Result<UsageSummary>> usage() async => Ok(usageSummary);

  @override
  Future<Result<List<TailnetDevice>>> tailnet() async => const Ok([
        TailnetDevice(name: 'minipc', os: 'linux', online: true, isHub: true, node: 'minipc'),
        TailnetDevice(name: 'mobile', os: 'android', online: true, clients: ['Pixel']),
        TailnetDevice(name: 'old-laptop', os: 'windows'),
      ]);

  @override
  Future<Result<PairingInvite>> createPairingInvite() async =>
      Ok(PairingInvite(code: 'ABCDE-FGHJK', expires: DateTime(2030), hubUrl: 'ws://100.64.0.1:7420/ws'));

  @override
  Future<Result<List<PairedDevice>>> listDevices() async => Ok(devices);

  var hostedPages = <HostedPage>[];
  var codebaseList = <Codebase>[];
  final snapshotted = <String>[];

  @override
  Future<Result<List<Codebase>>> codebases() async => Ok(codebaseList);

  @override
  Future<Result<void>> snapshotCodebase(String id) async {
    snapshotted.add(id);
    return const Ok(null);
  }

  @override
  Future<Result<List<HostedPage>>> pages({String session = ''}) async =>
      Ok([for (final p in hostedPages) if (session.isEmpty || p.session == session) p]);

  @override
  Future<Result<void>> revokeDevice(String id) async {
    devices = devices.where((d) => d.id != id).toList();
    return const Ok(null);
  }

  @override
  Future<Result<String>> pair({
    required String url,
    required String code,
    required String fingerprint,
    required String name,
    required String platform,
  }) async {
    paired.add((url, code, fingerprint));
    return code == 'ABCDE-FGHJK' ? const Ok('device-token') : const Err(UnauthorizedFailure());
  }

  @override
  Future<Result<void>> setGlobal(String sessionId, {required bool global}) async {
    globalCalls.add((sessionId, global));
    return const Ok(null);
  }

  @override
  Future<Result<String>> continueOnHub(String sessionId, String text) async {
    sent.add((sessionId, text, true));
    return Ok('continued-$sessionId');
  }

  @override
  Future<Result<List<int>>> artifactBytes(String id) async => const Ok([]);

  @override
  Future<Result<String>> artifactLink(String id) async => Ok('http://hub/link/$id');

  @override
  Future<Result<void>> deleteArtifact(String id) async => const Ok(null);

  @override
  Future<Result<void>> setArchived(String sessionId, {required bool archived}) async {
    archivedCalls.add((sessionId, archived));
    return const Ok(null);
  }

  @override
  Future<Result<void>> decideApproval(String approvalId, {required bool allow, String message = '', Map<String, String> answers = const {}}) async {
    decided.add((approvalId, allow));
    answered.add(answers);
    return decideResult ?? const Ok(null);
  }

  @override
  Future<void> dispose() async => _hub.close();
}

class FakeSettingsRepository implements SettingsRepository {
  HubConnection saved = const HubConnection(url: '', token: '');
  Appearance appearance = const Appearance();

  @override
  Future<Result<HubConnection>> loadConnection() async => Ok(saved);

  @override
  Future<Result<void>> saveConnection(HubConnection connection) async {
    saved = connection;
    return const Ok(null);
  }

  @override
  Future<Result<void>> clearConnection() async {
    saved = const HubConnection(url: '', token: '');
    return const Ok(null);
  }

  final drafts = <String, String>{};

  @override
  Future<String> loadDraft(String key) async => drafts[key] ?? '';

  @override
  Future<void> saveDraft(String key, String text) async => text.trim().isEmpty ? drafts.remove(key) : drafts[key] = text;

  @override
  Future<Appearance> loadAppearance() async => appearance;

  @override
  Future<Result<void>> saveAppearance(Appearance a) async {
    appearance = a;
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
  void disconnect() => endpoint = null;

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

/// Transfers that finish at once; the test reads what was asked for.
class FakeTransferRepository implements TransferRepository {
  final _changes = StreamController<Map<String, Transfer>>.broadcast();
  Map<String, Transfer> _now = const {};
  final uploads = <(LocalFile, String, String, bool)>[];
  final downloads = <Artifact>[];

  void emit(Transfer t) {
    _now = {..._now, t.id: t};
    _changes.add(_now);
  }

  @override
  Map<String, Transfer> get current => _now;

  @override
  Stream<Map<String, Transfer>> watch() async* {
    yield _now;
    yield* _changes.stream;
  }

  @override
  Future<Result<void>> download(Artifact artifact) async {
    downloads.add(artifact);
    emit(Transfer(id: artifact.id, kind: TransferKind.download, name: artifact.name, total: artifact.size, state: TransferState.running));
    return const Ok(null);
  }

  @override
  Future<Result<void>> pause(String id) async {
    if (_now[id] case final t?) emit(t.copyWith(state: TransferState.paused));
    return const Ok(null);
  }

  @override
  Future<Result<void>> resume(String id) async {
    if (_now[id] case final t?) emit(t.copyWith(state: TransferState.running));
    return const Ok(null);
  }

  @override
  Future<Result<void>> cancel(String id) async {
    if (_now[id] case final t?) emit(t.copyWith(state: TransferState.canceled));
    return const Ok(null);
  }

  @override
  void dismiss(String id) {
    _now = {..._now}..remove(id);
    _changes.add(_now);
  }

  @override
  Future<Result<Artifact>> upload(LocalFile file, {String session = '', String note = '', bool deliver = false}) async {
    uploads.add((file, session, note, deliver));
    return Ok(Artifact(id: 'art-${uploads.length}', name: file.name, size: file.size, session: session, note: note));
  }
}

/// An on-device cache that lives in memory.
class MemoryHubCache implements HubCache {
  final timelines = <String, pb.TimelinePage>{};
  pb.Welcome? state;

  @override
  Future<pb.TimelinePage?> readTimeline(String session) async => timelines[session]?.deepCopy();

  @override
  Future<void> writeTimeline(pb.TimelinePage page) async => timelines[page.session] = page.deepCopy();

  @override
  Future<void> removeTimeline(String session) async => timelines.remove(session);

  @override
  Future<pb.Welcome?> readState() async => state?.deepCopy();

  @override
  Future<void> writeState(pb.Welcome s) async => state = s.deepCopy();

  @override
  Future<void> clear() async {
    timelines.clear();
    state = null;
  }
}

extension SessionCopy on Session {
  Session copyWithId(String id) => Session(id: id, node: node, title: 'Session $id', state: state, host: host, cwd: cwd, updated: updated);
}
