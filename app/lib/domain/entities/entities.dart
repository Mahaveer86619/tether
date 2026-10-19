import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'package:flutter/material.dart' show ThemeMode;

import '../../gen/tether/v1/render.pb.dart' as render;

// The timeline's render types (items, Markdown blocks, tool cards) are the
// wire contract's own vocabulary and are used as domain value objects as-is;
// mapping that tree by hand would only duplicate the generated code.
export '../../gen/tether/v1/render.pb.dart'
    show TimelineItem, TimelineItem_Kind, Block, Block_Kind, Span, ToolCard, ToolCard_Detail, ToolOutput, Todo, Markdown;

enum ConnectionStatus { notConfigured, connecting, connected, offline, unauthorized }

class Node extends Equatable {
  const Node({
    required this.name,
    required this.online,
    this.os = '',
    this.hostname = '',
    this.claudeVersion = '',
    this.agentVersion = '',
    this.lastSeen,
    this.runningSessions = 0,
    this.ip = '',
  });

  final String name;
  final bool online;
  final String os, hostname, claudeVersion, agentVersion;
  final DateTime? lastSeen;
  final int runningSessions;

  /// The address its agent connects from, as the hub saw it.
  final String ip;

  @override
  List<Object?> get props => [name, online, os, hostname, claudeVersion, agentVersion, lastSeen, runningSessions, ip];
}

enum SessionState { idle, running, awaitingApproval, ready, terminalActive, error }

/// Where a session's live process runs; see docs/hosting.md.
enum SessionHost { none, headless, tmux, terminal }

enum TodoStatus { pending, inProgress, completed }

class TodoItem extends Equatable {
  const TodoItem({required this.content, required this.status, this.activeForm = ''});

  final String content;
  final TodoStatus status;
  final String activeForm;

  String get label => status == TodoStatus.inProgress && activeForm.isNotEmpty ? activeForm : content;

  @override
  List<Object?> get props => [content, status, activeForm];
}

class Session extends Equatable {
  const Session({
    required this.id,
    required this.node,
    this.title = '',
    this.cwd = '',
    this.gitBranch = '',
    this.created,
    this.updated,
    this.messageCount = 0,
    this.state = SessionState.idle,
    this.host = SessionHost.none,
    this.attachCommand = '',
    this.lastPrompt = '',
    this.claudeVersion = '',
    this.model = '',
    this.todos = const [],
    this.lastCostUsd = 0,
    this.error = '',
    this.terminalInput = false,
    this.archived = false,
    this.parent = '',
    this.forkPoint = '',
    this.lineage = '',
    this.scratch = false,
    this.global = false,
  });

  final String id, node, title, cwd, gitBranch;
  final DateTime? created, updated;
  final int messageCount;
  final SessionState state;
  final SessionHost host;
  final String attachCommand, lastPrompt, claudeVersion, model;
  final List<TodoItem> todos;
  final double lastCostUsd;
  final String error;

  /// Open in your own terminal, but the agent can type into it (Windows).
  final bool terminalInput;

  /// The user marked it done; it stays out of "pick up" lists until it works again.
  final bool archived;

  /// The session this one split off from, the parent's last item at that
  /// moment, and how ("fork"; later "branch"). Empty for an original.
  final String parent, forkPoint, lineage;

  bool get isFork => parent.isNotEmpty;

  /// A hub session, in its own scratch folder on the hub's machine.
  final bool scratch;

  /// The hub keeps a copy of the transcript so it can be continued there.
  final bool global;

  String get displayTitle => title.isNotEmpty ? title : 'Untitled session';

  /// A Claude Code process is attached to it right now.
  bool get isLive => switch (state) {
        SessionState.running || SessionState.awaitingApproval || SessionState.ready || SessionState.terminalActive => true,
        _ => false,
      };

  /// Claude is in the middle of a turn.
  bool get isBusy => state == SessionState.running || state == SessionState.awaitingApproval;

  /// Messages from the app can reach it (it's not someone's open terminal).
  bool get acceptsInput =>
      !(state == SessionState.terminalActive ||
          host == SessionHost.terminal && state != SessionState.idle && !terminalInput);

  /// The agent hosts the live process, so it can be ended from the app.
  bool get canEnd => isLive && (host == SessionHost.tmux || host == SessionHost.headless);

  /// Claude can be interrupted wherever it runs, Windows terminals included.
  bool get canInterrupt => isBusy && (host != SessionHost.terminal || terminalInput);

  int get todosDone => todos.where((t) => t.status == TodoStatus.completed).length;
  TodoItem? get currentTodo => todos.where((t) => t.status == TodoStatus.inProgress).firstOrNull;

  @override
  List<Object?> get props => [
        id, node, title, cwd, gitBranch, created, updated, messageCount, state, host, attachCommand, //
        lastPrompt, claudeVersion, model, todos, lastCostUsd, error, terminalInput, archived, parent, forkPoint, lineage, scratch, global,
      ];
}

enum ApprovalKind { tool, folderTrust, question }

/// One of the questions Claude asks with AskUserQuestion.
class Question extends Equatable {
  const Question({required this.question, this.header = '', this.options = const [], this.multiSelect = false});

  final String question, header;
  final List<QuestionOption> options;
  final bool multiSelect;

  @override
  List<Object?> get props => [question, header, options, multiSelect];
}

class QuestionOption extends Equatable {
  const QuestionOption({required this.label, this.description = ''});

  final String label, description;

  @override
  List<Object?> get props => [label, description];
}

class Approval extends Equatable {
  const Approval({
    required this.id,
    required this.session,
    required this.node,
    required this.kind,
    this.toolName = '',
    this.inputJson = '',
    this.description = '',
    this.created,
    this.preview,
  });

  final String id, session, node;
  final ApprovalKind kind;
  final String toolName, inputJson, description;
  final DateTime? created;

  /// The tool call rendered as a card, for tool approvals.
  final render.ToolCard? preview;

  /// What Claude asks, for a question.
  List<Question> get questions {
    if (kind != ApprovalKind.question) return const [];
    try {
      final qs = (jsonDecode(inputJson) as Map<String, dynamic>)['questions'] as List<dynamic>? ?? const [];
      return [
        for (final q in qs.cast<Map<String, dynamic>>())
          Question(
            question: q['question'] as String? ?? '',
            header: q['header'] as String? ?? '',
            multiSelect: q['multiSelect'] as bool? ?? false,
            options: [
              for (final o in (q['options'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
                QuestionOption(label: o['label'] as String? ?? '', description: o['description'] as String? ?? ''),
            ],
          ),
      ];
    } on Object {
      return const [];
    }
  }

  @override
  List<Object?> get props => [id, session, node, kind, toolName, inputJson, description, created];
}

/// Everything the dashboard shows, as of now.
class HubSnapshot extends Equatable {
  const HubSnapshot({
    this.status = ConnectionStatus.notConfigured,
    this.nodes = const {},
    this.sessions = const {},
    this.approvals = const {},
    this.hubVersion = '',
    this.endpoint = '',
    this.lastError,
    this.preferences,
    this.hubNode = '',
    this.deviceId = '',
    this.clientIp = '',
    this.artifacts = const {},
  });

  final ConnectionStatus status;
  final Map<String, Node> nodes;
  final Map<String, Session> sessions;
  final Map<String, Approval> approvals;
  final String hubVersion, endpoint;
  final String? lastError;

  /// App settings shared by every client; null until one has saved them.
  final Appearance? preferences;

  /// The node on the hub's own machine, where hub sessions run.
  final String hubNode;

  /// This app's paired device id; empty when it connects with the admin
  /// token or through a trusted tailnet.
  final String deviceId;

  /// The address this app connects to the hub from.
  final String clientIp;

  /// The node running on this app's own machine, if any (never on a phone).
  String get selfNode => clientIp.isEmpty ? '' : nodes.values.where((n) => n.ip == clientIp).firstOrNull?.name ?? '';

  /// Other machines' nodes: the ones a remote session would run on.
  List<Node> get otherNodes => [for (final n in sortedNodes) if (n.name != selfNode) n];

  /// Recent files in the hub's artifact store, by id.
  final Map<String, Artifact> artifacts;

  /// Files linked to a tool call or message.
  List<Artifact> artifactsFor(String ref) => [for (final a in artifacts.values) if (a.ref == ref && a.ref.isNotEmpty) a];

  List<Artifact> get sortedArtifacts =>
      artifacts.values.toList()..sort((a, b) => (b.created ?? DateTime(0)).compareTo(a.created ?? DateTime(0)));

  bool get connected => status == ConnectionStatus.connected;

  List<Node> get sortedNodes =>
      nodes.values.toList()..sort((a, b) => a.online == b.online ? a.name.compareTo(b.name) : (a.online ? -1 : 1));

  List<Session> sessionsOf(String node) => sessions.values.where((s) => s.node == node).toList()..sort(compareSessions);

  /// Sessions that split off from [id], newest first.
  List<Session> childrenOf(String id) =>
      sessions.values.where((s) => s.parent == id).toList()..sort((a, b) => (b.created ?? DateTime(0)).compareTo(a.created ?? DateTime(0)));

  List<Session> get liveSessions => sessions.values.where((s) => s.isLive).toList()..sort(compareSessions);

  List<Approval> get sortedApprovals => approvals.values.toList()..sort(_byCreated);

  List<Approval> approvalsFor(String session) => approvals.values.where((a) => a.session == session).toList()..sort(_byCreated);

  /// Sessions grouped by the folder they ran in, most recently active first.
  /// Sessions marked done are left out unless [includeArchived].
  List<Project> projects({bool includeArchived = false}) {
    final byKey = <String, List<Session>>{};
    for (final s in sessions.values) {
      if (s.archived && !includeArchived && !s.isLive) continue;
      byKey.putIfAbsent(Project(node: s.node, cwd: s.cwd, sessions: const []).key, () => []).add(s);
    }
    final out = [
      for (final list in byKey.values) Project(node: list.first.node, cwd: list.first.cwd, sessions: list..sort(compareSessions)),
    ];
    return out..sort((a, b) => (b.updated ?? DateTime(0)).compareTo(a.updated ?? DateTime(0)));
  }

  /// Parent folders of the projects used on a node: likely workspace roots.
  List<String> suggestedRoots(String node) {
    final seen = <String>{};
    for (final f in recentFolders(node)) {
      final i = f.lastIndexOf(RegExp(r'[\\/]'));
      if (i > 0) seen.add(f.substring(0, i));
    }
    return seen.take(5).toList();
  }

  /// Folders used recently on a node, newest first.
  List<String> recentFolders(String node) {
    final seen = <String>{};
    final list = sessions.values.where((s) => s.node == node && s.cwd.isNotEmpty).toList()
      ..sort((a, b) => (b.updated ?? DateTime(0)).compareTo(a.updated ?? DateTime(0)));
    return [for (final s in list) if (seen.add(s.cwd)) s.cwd];
  }

  HubSnapshot copyWith({
    ConnectionStatus? status,
    Map<String, Node>? nodes,
    Map<String, Session>? sessions,
    Map<String, Approval>? approvals,
    String? hubVersion,
    String? endpoint,
    String? Function()? lastError,
    Appearance? Function()? preferences,
    String? hubNode,
    String? deviceId,
    String? clientIp,
    Map<String, Artifact>? artifacts,
  }) =>
      HubSnapshot(
        status: status ?? this.status,
        nodes: nodes ?? this.nodes,
        sessions: sessions ?? this.sessions,
        approvals: approvals ?? this.approvals,
        hubVersion: hubVersion ?? this.hubVersion,
        endpoint: endpoint ?? this.endpoint,
        lastError: lastError != null ? lastError() : this.lastError,
        preferences: preferences != null ? preferences() : this.preferences,
        hubNode: hubNode ?? this.hubNode,
        deviceId: deviceId ?? this.deviceId,
        clientIp: clientIp ?? this.clientIp,
        artifacts: artifacts ?? this.artifacts,
      );

  @override
  List<Object?> get props => [status, nodes, sessions, approvals, hubVersion, endpoint, lastError, preferences, hubNode, deviceId, clientIp, artifacts];

  static int _byCreated(Approval a, Approval b) => (a.created ?? DateTime(0)).compareTo(b.created ?? DateTime(0));
}

/// Live sessions first, then most recently updated.
/// A folder on a node and the sessions that ran there.
class Project extends Equatable {
  const Project({required this.node, required this.cwd, required this.sessions});

  final String node, cwd;

  /// Live first, then newest.
  final List<Session> sessions;

  Session get latest => sessions.reduce((a, b) => (b.updated ?? DateTime(0)).isAfter(a.updated ?? DateTime(0)) ? b : a);
  DateTime? get updated => latest.updated;
  int get liveCount => sessions.where((s) => s.isLive).length;
  String get key => '$node|$cwd';

  @override
  List<Object?> get props => [node, cwd, sessions];
}

int compareSessions(Session a, Session b) {
  if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
  return (b.updated ?? DateTime(0)).compareTo(a.updated ?? DateTime(0));
}

/// A session's timeline as of now.
class TimelineSnapshot extends Equatable {
  const TimelineSnapshot({required this.sessionId, this.items = const [], this.loading = true, this.version = 0});

  final String sessionId;

  /// Ordered for display.
  final List<render.TimelineItem> items;
  final bool loading;

  /// Bumped on every change, so equal-looking lists still rebuild.
  final int version;

  @override
  List<Object?> get props => [sessionId, loading, version];
}

class HubConnection extends Equatable {
  const HubConnection({required this.url, required this.token, this.fingerprint = '', this.viaTailnet = false});

  final String url, token;

  /// SHA-256 of the hub's self-signed certificate, learnt when pairing.
  final String fingerprint;

  /// No token: the hub trusts this machine because it's the owner's on the
  /// tailnet.
  final bool viaTailnet;

  bool get isComplete => url.isNotEmpty && (token.isNotEmpty || viaTailnet);

  @override
  List<Object?> get props => [url, token, fingerprint, viaTailnet];
}

/// How the app looks: light or dark, which theme, and an optional accent.
class Appearance extends Equatable {
  const Appearance({this.mode = ThemeMode.system, this.palette = 'claude', this.accent});

  final ThemeMode mode;
  final String palette;

  /// ARGB; null keeps the theme's own accent.
  final int? accent;

  Appearance copyWith({ThemeMode? mode, String? palette, int? Function()? accent}) =>
      Appearance(mode: mode ?? this.mode, palette: palette ?? this.palette, accent: accent == null ? this.accent : accent());

  @override
  List<Object?> get props => [mode, palette, accent];
}

/// A one-time pairing code, and the link a QR code carries to another device.
class PairingInvite extends Equatable {
  const PairingInvite({required this.code, required this.expires, required this.hubUrl, this.fingerprint = ''});

  final String code, hubUrl, fingerprint;
  final DateTime expires;

  String get link => Uri(scheme: 'tether', host: 'pair', queryParameters: {
        'hub': hubUrl,
        'code': code,
        if (fingerprint.isNotEmpty) 'fp': fingerprint,
      }).toString();

  @override
  List<Object?> get props => [code, expires, hubUrl, fingerprint];
}

/// Tokens used, as Claude Code reports them per message.
class UsageTotals extends Equatable {
  const UsageTotals({this.input = 0, this.output = 0, this.cacheWrite = 0, this.cacheRead = 0, this.messages = 0});

  final int input, output, cacheWrite, cacheRead, messages;

  /// What counts toward a budget: cache reads are cheap and left out.
  int get counted => input + output + cacheWrite;

  @override
  List<Object?> get props => [input, output, cacheWrite, cacheRead, messages];
}

class NodeUsage extends Equatable {
  const NodeUsage({required this.node, this.window = const UsageTotals(), this.today = const UsageTotals(), this.week = const UsageTotals(), this.plan});

  final String node;

  /// The last 5 hours, since midnight, and the last 7 days.
  final UsageTotals window, today, week;

  /// The plan's limits as this machine's Claude login reports them.
  final PlanUsage? plan;

  @override
  List<Object?> get props => [node, window, today, week, plan];
}

/// One plan limit from Claude Code's /usage, e.g. "session" at 9%.
class PlanLimit extends Equatable {
  const PlanLimit({required this.label, required this.percent, this.resets = ''});

  final String label, resets;
  final int percent;

  @override
  List<Object?> get props => [label, percent, resets];
}

class PlanUsage extends Equatable {
  const PlanUsage({this.limits = const [], this.raw = '', this.checked, this.error = ''});

  final List<PlanLimit> limits;

  /// The command's output, shown when the limits couldn't be read from it.
  final String raw;
  final DateTime? checked;
  final String error;

  /// Machines on the same Claude account report the same limits, resetting
  /// at the same time give or take the minute each machine rounds to.
  bool sameAccountAs(PlanUsage other) {
    if (limits.isEmpty || limits.length != other.limits.length) return false;
    for (var i = 0; i < limits.length; i++) {
      final a = limits[i], b = other.limits[i];
      if (a.label != b.label) return false;
      final ta = _resetMinutes(a.resets), tb = _resetMinutes(b.resets);
      if (ta == null || tb == null ? a.resets != b.resets : (ta - tb).abs() > 5) return false;
    }
    return true;
  }

  // "Oct 12, 3:19am (Asia/Kolkata)" as minutes, enough to compare two resets.
  static int? _resetMinutes(String resets) {
    final m = RegExp(r'(\w{3}) (\d+), (\d+):(\d+)\s*(am|pm)', caseSensitive: false).firstMatch(resets);
    if (m == null) return null;
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final month = months.indexOf(m.group(1)!.toLowerCase());
    final hour = int.parse(m.group(3)!) % 12 + (m.group(5)!.toLowerCase() == 'pm' ? 12 : 0);
    return ((month * 31 + int.parse(m.group(2)!)) * 24 + hour) * 60 + int.parse(m.group(4)!);
  }

  @override
  List<Object?> get props => [limits, raw, checked, error];
}

class SessionUsage extends Equatable {
  const SessionUsage({required this.session, required this.total, this.last});

  final String session;
  final UsageTotals total;
  final DateTime? last;

  @override
  List<Object?> get props => [session, total, last];
}

class UsageSummary extends Equatable {
  const UsageSummary({this.nodes = const [], this.sessions = const []});

  final List<NodeUsage> nodes;

  /// This week's sessions, most tokens first.
  final List<SessionUsage> sessions;

  @override
  List<Object?> get props => [nodes, sessions];
}

/// A machine on the hub's tailnet and what of Tether runs on it.
class TailnetDevice extends Equatable {
  const TailnetDevice({
    required this.name,
    this.hostname = '',
    this.os = '',
    this.online = false,
    this.ips = const [],
    this.isHub = false,
    this.node = '',
    this.clients = const [],
    this.lastSeen,
  });

  final String name, hostname, os;
  final bool online;
  final List<String> ips;

  /// The hub's own machine.
  final bool isHub;

  /// The Tether node connected from it, if any.
  final String node;

  /// Apps connected from it.
  final List<String> clients;
  final DateTime? lastSeen;

  bool get runsTether => node.isNotEmpty || clients.isNotEmpty;

  @override
  List<Object?> get props => [name, hostname, os, online, ips, isHub, node, clients, lastSeen];
}

/// An app or agent paired with its own token.
class PairedDevice extends Equatable {
  const PairedDevice({required this.id, required this.kind, required this.name, this.platform = '', this.created, this.lastSeen});

  final String id, kind, name, platform;
  final DateTime? created, lastSeen;

  bool get isNode => kind == 'node';

  @override
  List<Object?> get props => [id, kind, name, platform, created, lastSeen];
}

class NewSessionRequest extends Equatable {
  const NewSessionRequest({
    required this.node,
    required this.prompt,
    this.cwd = '',
    this.model = '',
    this.permissionMode = '',
    this.createCwd = false,
    this.scratch = false,
    this.attachments = const [],
  });

  final String node, prompt, cwd, model, permissionMode;

  /// Create [cwd] first: a new project folder in a workspace root.
  final bool createCwd;

  /// A hub session: on the hub's machine, in a scratch folder.
  final bool scratch;

  /// Artifact ids to hand to the session.
  final List<String> attachments;

  @override
  List<Object?> get props => [node, prompt, cwd, model, permissionMode, createCwd, scratch, attachments];
}

/// A file in the hub's central artifact store.
/// A folder on a device the hub keeps copies of; see docs/plan.md#codebases-on-the-hub.
class Codebase extends Equatable {
  const Codebase({
    required this.id,
    required this.node,
    required this.path,
    required this.name,
    this.gitRemote = '',
    this.gitBranch = '',
    this.lastSnapshot,
    this.files = 0,
    this.bytes = 0,
    this.env = const [],
    this.error = '',
  });

  final String id, node, path, name, gitRemote, gitBranch;

  /// When the hub last took a copy; null if it never has.
  final DateTime? lastSnapshot;
  final int files, bytes;

  /// .env files in the hub's vault: names only, never values.
  final List<EnvFileInfo> env;

  /// Why the last snapshot failed, if it did.
  final String error;

  @override
  List<Object?> get props => [id, node, path, name, gitRemote, gitBranch, lastSnapshot, files, bytes, env, error];
}

class EnvFileInfo extends Equatable {
  const EnvFileInfo({required this.path, this.keys = const []});

  /// Where it goes in the codebase, e.g. "server/.env".
  final String path;
  final List<String> keys;

  @override
  List<Object?> get props => [path, keys];
}

/// A small site a session made, hosted by the hub; see docs/plan.md#generated-pages.
class HostedPage extends Equatable {
  const HostedPage({required this.session, required this.name, this.files = 0, this.size = 0, this.updated, this.url = ''});

  final String session, name;
  final int files, size;
  final DateTime? updated;

  /// A link to it that works in any browser until it expires.
  final String url;

  @override
  List<Object?> get props => [session, name, files, size, updated, url];
}

class Artifact extends Equatable {
  const Artifact({
    required this.id,
    required this.name,
    this.mime = '',
    this.size = 0,
    this.session = '',
    this.node = '',
    this.origin = '',
    this.path = '',
    this.ref = '',
    this.created,
    this.sha256 = '',
    this.note = '',
  });

  final String id, name, mime, session, node, origin, path, sha256, note;

  /// The tool call or message it belongs to.
  final String ref;
  final int size;
  final DateTime? created;

  bool get isImage => mime.startsWith('image/') && mime != 'image/svg+xml';
  bool get isText => mime.startsWith('text/') || mime.contains('json') || name.endsWith('.md');
  bool get isMedia => mime.startsWith('audio/') || mime.startsWith('video/');
  bool get isData =>
      mime == 'text/csv' || mime.contains('spreadsheet') || mime.contains('excel') || mime.contains('json') || name.endsWith('.parquet');

  /// Small enough to show inside the app; anything bigger is downloaded.
  bool get previewable => size <= 20 * 1024 * 1024;

  @override
  List<Object?> get props => [id, name, mime, size, session, node, origin, path, ref, created, sha256, note];
}

enum TransferKind { download, upload }

enum TransferState { queued, preparing, running, paused, verifying, done, failed, canceled }

/// A file on its way to or from the hub. Downloads are keyed by artifact
/// id, uploads by a local id until the hub gives them one.
class Transfer extends Equatable {
  const Transfer({
    required this.id,
    required this.kind,
    required this.name,
    this.state = TransferState.queued,
    this.bytes = 0,
    this.total = 0,
    this.speed = 0,
    this.session = '',
    this.error = '',
    this.savedTo = '',
    this.artifact,
  });

  final String id, name, session, error;
  final TransferKind kind;
  final TransferState state;
  final int bytes, total;

  /// Bytes per second, or 0 if unknown.
  final double speed;

  /// Where a finished download was saved.
  final String savedTo;

  /// What a finished upload became.
  final Artifact? artifact;

  double? get progress => total > 0 ? (bytes / total).clamp(0, 1).toDouble() : null;
  bool get active => state == TransferState.queued || state == TransferState.preparing || state == TransferState.running || state == TransferState.verifying;
  bool get finished => state == TransferState.done || state == TransferState.failed || state == TransferState.canceled;

  Transfer copyWith({TransferState? state, int? bytes, int? total, double? speed, String? error, String? savedTo, Artifact? artifact}) => Transfer(
        id: id,
        kind: kind,
        name: name,
        session: session,
        state: state ?? this.state,
        bytes: bytes ?? this.bytes,
        total: total ?? this.total,
        speed: speed ?? this.speed,
        error: error ?? this.error,
        savedTo: savedTo ?? this.savedTo,
        artifact: artifact ?? this.artifact,
      );

  @override
  List<Object?> get props => [id, kind, name, session, state, bytes, total, speed, error, savedTo, artifact];
}

/// A file picked on this device, read from disk rather than memory.
class LocalFile extends Equatable {
  const LocalFile({required this.path, required this.name, required this.size});

  final String path, name;
  final int size;

  @override
  List<Object?> get props => [path, name, size];
}

/// A folder on a machine that new projects are created in.
class WorkspaceRoot extends Equatable {
  const WorkspaceRoot({required this.node, required this.path});

  final String node, path;

  @override
  List<Object?> get props => [node, path];
}
