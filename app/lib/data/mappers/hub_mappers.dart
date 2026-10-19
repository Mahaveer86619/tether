import 'package:flutter/material.dart' show ThemeMode;
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
      ip: n.ip,
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
      terminalInput: s.terminalInput,
      archived: s.archived,
      parent: s.parent,
      forkPoint: s.forkPoint,
      lineage: s.lineage,
      scratch: s.scratch,
      global: s.global,
    );

Appearance appearanceFromPb(pb.Preferences p) => Appearance(
      mode: ThemeMode.values.asNameMap()[p.themeMode] ?? ThemeMode.system,
      palette: p.palette.isEmpty ? 'claude' : p.palette,
      accent: p.hasAccent() ? p.accent : null,
    );

pb.Preferences appearanceToPb(Appearance a) =>
    pb.Preferences(themeMode: a.mode.name, palette: a.palette, accent: a.accent);

TailnetDevice tailnetDeviceFromPb(pb.TailnetDevice d) => TailnetDevice(
      name: d.name,
      hostname: d.hostname,
      os: d.os,
      online: d.online,
      ips: d.ips,
      isHub: d.self,
      node: d.node,
      clients: d.clients,
      lastSeen: _time(d.lastSeenMs),
    );

Artifact artifactFromPb(pb.Artifact a) => Artifact(
      id: a.id,
      name: a.name,
      mime: a.mime,
      size: a.size.toInt(),
      session: a.session,
      node: a.node,
      origin: a.origin,
      path: a.path,
      ref: a.toolUseId,
      created: _time(a.createdMs),
      sha256: a.sha256,
      note: a.note,
    );

UsageTotals _totals(pb.UsageTotals t) => UsageTotals(
      input: t.input.toInt(),
      output: t.output.toInt(),
      cacheWrite: t.cacheWrite.toInt(),
      cacheRead: t.cacheRead.toInt(),
      messages: t.messages.toInt(),
    );

UsageSummary usageFromPb(pb.UsageSummary s) => UsageSummary(
      nodes: [
        for (final n in s.nodes)
          NodeUsage(
            node: n.node,
            window: _totals(n.window),
            today: _totals(n.today),
            week: _totals(n.week),
            plan: n.hasPlan()
                ? PlanUsage(
                    limits: [for (final l in n.plan.limits) PlanLimit(label: l.label, percent: l.percent, resets: l.resets)],
                    raw: n.plan.raw,
                    checked: _time(n.plan.checkedMs),
                    error: n.plan.error,
                  )
                : null,
          ),
      ],
      sessions: [for (final u in s.sessions) SessionUsage(session: u.session, total: _totals(u.total), last: _time(u.lastMs))],
    );

PairedDevice deviceFromPb(pb.Device d) => PairedDevice(
      id: d.id,
      kind: d.kind,
      name: d.name,
      platform: d.platform,
      created: _time(d.createdMs),
      lastSeen: _time(d.lastSeenMs),
    );

Codebase codebaseFromPb(pb.Codebase c) => Codebase(
      id: c.id,
      node: c.node,
      path: c.path,
      name: c.name,
      gitRemote: c.gitRemote,
      gitBranch: c.gitBranch,
      lastSnapshot: _time(c.snapshotMs),
      files: c.files,
      bytes: c.bytes.toInt(),
      env: [for (final e in c.env) EnvFileInfo(path: e.path, keys: [for (final k in e.keys) k.name])],
      error: c.error,
    );

HostedPage pageFromPb(pb.Page p) =>
    HostedPage(session: p.session, name: p.name, files: p.files, size: p.size.toInt(), updated: _time(p.updatedMs), url: p.url);

Approval approvalFromPb(pb.ApprovalRequest a) => Approval(
      id: a.approvalId,
      session: a.session,
      node: a.node,
      kind: switch (a.kind) {
        pbe.ApprovalRequest_Kind.KIND_FOLDER_TRUST => ApprovalKind.folderTrust,
        pbe.ApprovalRequest_Kind.KIND_QUESTION => ApprovalKind.question,
        pbe.ApprovalRequest_Kind.KIND_PROMPT => ApprovalKind.prompt,
        _ => ApprovalKind.tool,
      },
      options: a.options,
      selected: a.kind == pbe.ApprovalRequest_Kind.KIND_PROMPT ? a.selected : -1,
      screen: a.screen,
      toolName: a.toolName,
      inputJson: a.inputJson,
      description: a.description,
      created: _time(a.createdMs),
      preview: a.hasPreview() ? a.preview : null,
    );

ScreenSnapshot screenFromPb(pb.ScreenSnapshot s) => ScreenSnapshot(session: s.session, text: s.text, captured: _time(s.capturedMs), error: s.error);
