import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../session/session_page.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'cards.dart';

/// Sessions that are waiting on you: Claude finished a turn, or failed.
List<Session> needingYou(HubSnapshot hub) {
  final cutoff = DateTime.now().subtract(const Duration(days: 1));
  return hub.sessions.values
      .where((s) =>
          !s.archived &&
          (s.state == SessionState.ready ||
              s.state == SessionState.error && (s.updated ?? DateTime(0)).isAfter(cutoff)) &&
          hub.approvalsFor(s.id).isEmpty)
      .toList()
    ..sort((a, b) => (b.updated ?? DateTime(0)).compareTo(a.updated ?? DateTime(0)));
}

/// Approvals plus sessions waiting on you, for nav badges.
int attentionCount(HubSnapshot hub) => hub.approvals.length + needingYou(hub).length;

/// Monitor: what's connected, what needs you, what's running, and where
/// you left off.
class MonitorPage extends StatelessWidget {
  const MonitorPage({super.key, required this.onSession, required this.onDevices, required this.onAllSessions});

  final ValueChanged<String> onSession;
  final VoidCallback onDevices, onAllSessions;

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final c = context.colors;

    if (!hub.connected && hub.sessions.isEmpty) {
      final connecting = hub.status == ConnectionStatus.connecting;
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: connecting ? 'Connecting to the hub…' : 'Not connected',
        body: hub.lastError ?? hub.endpoint,
        action: connecting ? null : OutlinedButton(onPressed: context.read<HubCubit>().retry, child: const Text('Retry now')),
      );
    }

    final approvals = hub.sortedApprovals;
    final waiting = needingYou(hub);
    final running = hub.liveSessions.where((s) => s.state == SessionState.running || s.state == SessionState.terminalActive).toList();
    final shown = {...waiting.map((s) => s.id), ...running.map((s) => s.id)};
    final projects = hub.projects().where((p) => !p.sessions.every((s) => shown.contains(s.id))).take(4).toList();
    bool online(Session s) => hub.nodes[s.node]?.online ?? false;
    return PageColumn(
      children: [
        _DevicesStrip(hub: hub, onTap: onDevices),
        if (approvals.isNotEmpty || waiting.isNotEmpty) ...[
          SectionLabel('Needs you', trailing: Pill('${approvals.length + waiting.length}', color: c.warning)),
          for (final a in approvals)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ApprovalCard(approval: a, sessionTitle: hub.sessions[a.session]?.displayTitle),
            ),
          if (waiting.isNotEmpty)
            CardGrid(children: [for (final s in waiting) SessionCard(session: s, online: online(s), onTap: () => onSession(s.id))]),
        ],
        if (running.isNotEmpty) ...[
          SectionLabel('Running now', trailing: Text('${running.length}', style: TextStyle(color: c.faint, fontSize: 12))),
          CardGrid(children: [for (final s in running) SessionCard(session: s, online: online(s), onTap: () => onSession(s.id))]),
        ],
        SectionLabel(
          'Pick up where you left off',
          trailing: TextButton(
            onPressed: onAllSessions,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('View all'),
          ),
        ),
        if (projects.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sessions you start, or open on your devices, show up here by project.', style: TextStyle(color: c.muted, fontSize: 13)),
          )
        else
          CardGrid(children: [for (final p in projects) _ProjectCard(project: p, onSession: onSession)]),
      ],
    );
  }
}

class _DevicesStrip extends StatelessWidget {
  const _DevicesStrip({required this.hub, required this.onTap});

  final HubSnapshot hub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // This machine isn't counted: these are the devices it can reach.
    final nodes = hub.otherNodes;
    final up = nodes.where((n) => n.online).length;
    final down = nodes.length - up;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('devices-strip'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                OnlineDot(online: up > 0),
                const SizedBox(width: 10),
                Text('$up online', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (down > 0) Text('  ·  $down offline', style: TextStyle(fontSize: 13, color: c.muted)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    [for (final n in nodes) n.name].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, color: c.faint),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A folder you worked in recently: tap to continue its latest session.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onSession});

  final Project project;
  final ValueChanged<String> onSession;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = project;
    final latest = p.latest;
    final update = lastUpdate(latest);
    return CardShell(
      onTap: () => onSession(latest.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(latest.scratch ? Icons.hub_outlined : Icons.folder_outlined, size: 17, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(p.cwd.isEmpty ? 'Home folder' : baseName(p.cwd), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              if (p.liveCount > 0) ...[Pill('${p.liveCount} live', color: c.accent), const SizedBox(width: 6)],
              Pill(p.node),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              StateDot(state: latest.state, size: 7),
              const SizedBox(width: 8),
              Expanded(
                child: Text(latest.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.text)),
              ),
            ],
          ),
          if (update.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(update, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${p.sessions.length} ${p.sessions.length == 1 ? 'session' : 'sessions'} · ${ago(p.updated)}',
                  style: TextStyle(fontSize: 12, color: c.faint),
                ),
              ),
              Text('Continue', style: TextStyle(fontSize: 12, color: c.accent, fontWeight: FontWeight.w600)),
              Icon(Icons.chevron_right_rounded, size: 16, color: c.accent),
            ],
          ),
        ],
      ),
    );
  }
}
