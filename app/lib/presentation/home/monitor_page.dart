import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../session/session_page.dart';
import '../widgets/common.dart';
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

/// What's connected, what needs you and what's running: the live part of
/// the home screen.
class LiveSections extends StatelessWidget {
  const LiveSections({super.key, required this.onSession, required this.onDevices});

  final ValueChanged<String> onSession;
  final VoidCallback onDevices;

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
    bool online(Session s) => hub.nodes[s.node]?.online ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
