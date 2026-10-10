import 'package:fixnum/fixnum.dart';

import '../../domain/entities/entities.dart';
import '../../gen/tether/v1/render.pbenum.dart' as rpbe;
import '../../gen/tether/v1/tether.pb.dart' as pb;
import '../../gen/tether/v1/tether.pbenum.dart' as pbe;

DateTime? _time(Int64 ms) => ms == Int64.ZERO ? null : DateTime.fromMillisecondsSinceEpoch(ms.toInt());

Node nodeFromPb(pb.NodeStatus n) => Node(
      name: n.node,
      online: n.online,
      os: n.os,
      hostname: n.hostname,
      claudeVersion: n.claudeVersion,
      agentVersion: n.agentVersion,
      lastSeen: _time(n.lastSeenMs),
      runningSessions: n.runningSessions,
    );

SessionState _state(pbe.SessionState s) => switch (s) {
      pbe.SessionState.SESSION_STATE_RUNNING => SessionState.running,
      pbe.SessionState.SESSION_STATE_AWAITING_APPROVAL => SessionState.awaitingApproval,
      pbe.SessionState.SESSION_STATE_READY => SessionState.ready,
      pbe.SessionState.SESSION_STATE_TERMINAL_ACTIVE => SessionState.terminalActive,
      pbe.SessionState.SESSION_STATE_ERROR => SessionState.error,
      _ => SessionState.idle,
    };

SessionHost _host(pbe.SessionHost h) => switch (h) {
      pbe.SessionHost.SESSION_HOST_HEADLESS => SessionHost.headless,
      pbe.SessionHost.SESSION_HOST_TMUX => SessionHost.tmux,
      pbe.SessionHost.SESSION_HOST_TERMINAL => SessionHost.terminal,
      _ => SessionHost.none,
    };

TodoItem todoFromPb(Todo t) => TodoItem(
      content: t.content,
      activeForm: t.activeForm,
      status: switch (t.status) {
        rpbe.Todo_Status.STATUS_COMPLETED => TodoStatus.completed,
        rpbe.Todo_Status.STATUS_IN_PROGRESS => TodoStatus.inProgress,
        _ => TodoStatus.pending,
      },
    );

Session sessionFromPb(pb.SessionInfo s) => Session(
      id: s.id,
      node: s.node,
      title: s.title,
      cwd: s.cwd,
      gitBranch: s.gitBranch,
      created: _time(s.createdMs),
      updated: _time(s.updatedMs),
      messageCount: s.messageCount,
      state: _state(s.state),
      host: _host(s.host),
      attachCommand: s.attachCommand,
      lastPrompt: s.lastPrompt,
      claudeVersion: s.claudeVersion,
      model: s.model,
      todos: [for (final t in s.todos) todoFromPb(t)],
      lastCostUsd: s.lastCostUsd,
      error: s.error,
    );

Approval approvalFromPb(pb.ApprovalRequest a) => Approval(
      id: a.approvalId,
      session: a.session,
      node: a.node,
      kind: a.kind == pbe.ApprovalRequest_Kind.KIND_FOLDER_TRUST ? ApprovalKind.folderTrust : ApprovalKind.tool,
      toolName: a.toolName,
      inputJson: a.inputJson,
      description: a.description,
      created: _time(a.createdMs),
      preview: a.hasPreview() ? a.preview : null,
    );
