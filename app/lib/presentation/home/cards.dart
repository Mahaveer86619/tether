import 'package:flutter/material.dart';

import '../../core/version.dart';
import '../../domain/entities/entities.dart';
import '../theme/theme.dart';
import '../ui/tokens.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

class CardShell extends StatelessWidget {
  const CardShell({super.key, required this.child, required this.onTap, this.accent});

  final Widget child;
  final VoidCallback onTap;

  /// A thin stripe down the left edge, in the session's state colour.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = Padding(padding: const EdgeInsets.all(14), child: child);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: context.round(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: accent == null
            ? body
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Container(width: 2, color: accent), Expanded(child: body)],
                ),
              ),
      ),
    );
  }
}

/// One or two columns, depending on the width.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth > 640 ? 2 : 1;
        final w = (box.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

/// How a session reads at a glance: its colour, what it's doing, and what
/// you'd do about it.
class SessionLook {
  const SessionLook(this.color, this.label, this.action);

  final Color color;
  final String label, action;

  factory SessionLook.of(BuildContext context, Session s, {required bool online}) {
    final c = context.colors;
    if (!online && s.state != SessionState.idle) return SessionLook(c.faint, 'Device offline', 'Open');
    return switch (s.state) {
      SessionState.running => SessionLook(c.accent, 'Working · ${ago(s.updated)}', 'Watch'),
      SessionState.awaitingApproval => SessionLook(c.warning, 'Needs approval', 'Approve'),
      SessionState.ready => SessionLook(c.warning, 'Waiting for you', 'Respond'),
      SessionState.terminalActive => SessionLook(c.info, 'Open in a terminal', 'Watch'),
      SessionState.error => SessionLook(c.danger, 'Failed', 'Open'),
      SessionState.idle => SessionLook(c.success.withValues(alpha: 0.7), s.archived ? 'Done' : 'Finished ${ago(s.updated)}', 'Continue'),
    };
  }
}

/// The latest thing worth knowing about a session.
String lastUpdate(Session s) {
  if (s.state == SessionState.error && s.error.isNotEmpty) return s.error;
  if (s.currentTodo case final t?) return '${t.label} (${s.todosDone}/${s.todos.length})';
  if (s.lastPrompt.isNotEmpty) return 'You: ${s.lastPrompt.replaceAll(RegExp(r'\s+'), ' ')}';
  return '';
}

class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.session, required this.online, required this.onTap});

  final Session session;
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    final look = SessionLook.of(context, s, online: online);
    final update = lastUpdate(s);
    return CardShell(
      onTap: onTap,
      accent: look.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StateDot(state: online ? s.state : SessionState.idle, size: 7),
              const SizedBox(width: 8),
              Expanded(
                child: Text(look.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: look.color, fontWeight: FontWeight.w600)),
              ),
              if (s.scratch) ...[Icon(Icons.hub_outlined, size: 14, color: c.faint), const SizedBox(width: 6)],
              if (s.global && !s.scratch) ...[Icon(Icons.cloud_done_outlined, size: 14, color: c.faint), const SizedBox(width: 6)],
              if (s.isFork) ...[Icon(Icons.call_split_rounded, size: 14, color: c.faint), const SizedBox(width: 6)],
              Pill(s.node),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (update.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(update, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: s.state == SessionState.error ? c.danger : c.muted)),
          ],
          if (s.isBusy && s.todos.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: context.round(4),
              child: LinearProgressIndicator(value: s.todosDone / s.todos.length, minHeight: 3, backgroundColor: c.raised, color: look.color),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text([if (s.cwd.isNotEmpty) baseName(s.cwd) else if (s.scratch) 'scratch', ago(s.updated)].join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.faint)),
              ),
              Text(look.action, style: TextStyle(fontSize: 12, color: look.color, fontWeight: FontWeight.w600)),
              Icon(Icons.chevron_right_rounded, size: 16, color: look.color),
            ],
          ),
        ],
      ),
    );
  }
}

/// A working session: what it is doing now, how far along, and where.
class RunCard extends StatelessWidget {
  const RunCard({super.key, required this.session, required this.online, required this.onTap});

  final Session session;
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    final steps = s.todos.length;
    final where = [s.node, if (s.cwd.isNotEmpty) baseName(s.cwd) else if (s.scratch) 'scratch'].join(' · ');
    return CardShell(
      onTap: onTap,
      accent: c.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StateDot(state: online ? s.state : SessionState.idle, size: 8),
              const SizedBox(width: Gap.sm),
              Expanded(child: Text(s.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Type.title(context))),
              const SizedBox(width: Gap.sm),
              Text(ago(s.updated), style: Type.meta(context, color: c.faint)),
            ],
          ),
          if (steps > 0) ...[
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Text('STEP ${(s.todosDone + 1).clamp(1, steps)} OF $steps', style: Type.label(context)),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(s.currentTodo?.label ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: Type.meta(context, color: c.accent)),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            StepBar(done: s.todosDone, total: steps),
          ] else if (lastUpdate(s).isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(lastUpdate(s), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.muted)),
          ],
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(child: Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: Type.meta(context, color: c.faint))),
              Text('Open', style: TextStyle(fontSize: 12.5, color: c.accent, fontWeight: FontWeight.w600)),
              Icon(Icons.arrow_forward_rounded, size: 14, color: c.accent),
            ],
          ),
        ],
      ),
    );
  }
}

/// Progress as a row of segments, one per step (at most 12, each standing
/// for several steps when there are more).
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.done, required this.total});

  final int done, total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = total.clamp(1, 12);
    final filled = (done * n / total).floor();
    return Row(
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: i < filled ? c.accent : (i == filled ? c.accent.withValues(alpha: 0.45) : c.raised),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.node,
    required this.sessions,
    required this.onTap,
    this.isHub = false,
    this.isSelf = false,
    this.hubVersion = '',
  });

  final Node node;

  /// The hub's version; an older agent is flagged for an update.
  final String hubVersion;
  final int sessions;
  final VoidCallback onTap;
  final bool isHub;

  /// The machine this app is running on.
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CardShell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.raised, borderRadius: context.round(10)),
            child: Icon(osIcon(node.os), color: node.online ? c.muted : c.faint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(node.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        OnlineDot(online: node.online),
                      ],
                    ),
                    if (isHub) Pill('hub', color: c.accent),
                    if (isSelf) const Pill('this device'),
                    if (node.needsAttention) Pill('needs attention', key: Key('attention-${node.name}'), color: c.danger),
                    if (isOlderVersion(node.agentVersion, hubVersion)) Pill('update', key: Key('update-${node.name}'), color: c.warning),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    node.online ? 'Online' : 'Offline${node.lastSeen != null ? ' · ${ago(node.lastSeen)}' : ''}',
                    if (node.agentVersion.isNotEmpty) 'agent ${node.agentVersion}',
                    if (node.claudeVersion.isNotEmpty) 'Claude Code ${node.claudeVersion}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
                if (node.capabilities.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: [for (final k in node.capabilities) Pill(k)]),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${node.runningSessions}', style: TextStyle(fontWeight: FontWeight.w600, color: node.runningSessions > 0 ? c.accent : c.faint)),
              Text('live · $sessions total', style: TextStyle(fontSize: 11, color: c.faint)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A centred, width-capped scrolling column, as every home page uses.
class PageColumn extends StatelessWidget {
  const PageColumn({super.key, required this.children, this.bottom = 40});

  final List<Widget> children;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 16.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(side, 8, side, bottom),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
  }
}
