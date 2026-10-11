import 'package:equatable/equatable.dart';

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
  });

  final String name;
  final bool online;
  final String os, hostname, claudeVersion, agentVersion;
  final DateTime? lastSeen;
  final int runningSessions;

  @override
  List<Object?> get props => [name, online, os, hostname, claudeVersion, agentVersion, lastSeen, runningSessions];
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
        lastPrompt, claudeVersion, model, todos, lastCostUsd, error, terminalInput, archived,
      ];
}

enum ApprovalKind { tool, folderTrust }

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
  });

  final ConnectionStatus status;
  final Map<String, Node> nodes;
  final Map<String, Session> sessions;
  final Map<String, Approval> approvals;
  final String hubVersion, endpoint;
  final String? lastError;

  bool get connected => status == ConnectionStatus.connected;

  List<Node> get sortedNodes =>
      nodes.values.toList()..sort((a, b) => a.online == b.online ? a.name.compareTo(b.name) : (a.online ? -1 : 1));

  List<Session> sessionsOf(String node) => sessions.values.where((s) => s.node == node).toList()..sort(compareSessions);

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
  }) =>
      HubSnapshot(
        status: status ?? this.status,
        nodes: nodes ?? this.nodes,
        sessions: sessions ?? this.sessions,
        approvals: approvals ?? this.approvals,
        hubVersion: hubVersion ?? this.hubVersion,
        endpoint: endpoint ?? this.endpoint,
        lastError: lastError != null ? lastError() : this.lastError,
      );

  @override
  List<Object?> get props => [status, nodes, sessions, approvals, hubVersion, endpoint, lastError];

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
  const HubConnection({required this.url, required this.token});

  final String url, token;

  bool get isComplete => url.isNotEmpty && token.isNotEmpty;

  @override
  List<Object?> get props => [url, token];
}

class NewSessionRequest extends Equatable {
  const NewSessionRequest({required this.node, required this.prompt, this.cwd = '', this.model = '', this.permissionMode = ''});

  final String node, prompt, cwd, model, permissionMode;

  @override
  List<Object?> get props => [node, prompt, cwd, model, permissionMode];
}
