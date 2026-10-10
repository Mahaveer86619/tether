import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../session/session_page.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'session_navigator.dart';

/// The dashboard: what needs you, what's running, and every device.
class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.onSession, required this.onNode, this.showDeviceSessions = false});

  final ValueChanged<String> onSession;
  final ValueChanged<String> onNode;

  /// On phones the overview doubles as the device list, so show sessions too.
  final bool showDeviceSessions;

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
    final active = hub.liveSessions;
    final nodes = hub.sortedNodes;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (approvals.isNotEmpty) ...[
                  SectionLabel('Needs you', trailing: Pill('${approvals.length}', color: c.warning)),
                  for (final a in approvals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ApprovalCard(approval: a, sessionTitle: hub.sessions[a.session]?.displayTitle),
                    ),
                ],
                SectionLabel('Active now', trailing: Text('${active.length}', style: TextStyle(color: c.faint, fontSize: 12))),
                if (active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nothing running. Start a session or open one from a device.', style: TextStyle(color: c.muted, fontSize: 13)),
                  )
                else
                  _Grid(children: [for (final s in active) _ActiveCard(session: s, onTap: () => onSession(s.id))]),
                const SectionLabel('Devices'),
                _Grid(children: [for (final n in nodes) _DeviceCard(node: n, sessions: hub.sessionsOf(n.name).length, onTap: () => onNode(n.name))]),
                if (showDeviceSessions)
                  for (final n in nodes) ...[
                    SectionLabel('${n.name} · recent'),
                    for (final s in hub.sessionsOf(n.name).take(6))
                      SessionTile(session: s, selected: false, dense: false, onTap: () => onSession(s.id)),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth > 640 ? 2 : 1;
        final w = (box.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    return CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StateDot(state: s.state),
              const SizedBox(width: 8),
              Text(stateLabel(s.state), style: TextStyle(fontSize: 12, color: stateColor(context, s.state))),
              const Spacer(),
              if (hostLabel(s.host).isNotEmpty) Pill(hostLabel(s.host)),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text([s.node, if (s.cwd.isNotEmpty) baseName(s.cwd), ago(s.updated)].join(' · '), style: TextStyle(fontSize: 12, color: c.muted)),
          if (s.todos.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: s.todosDone / s.todos.length, minHeight: 4, backgroundColor: c.raised, color: c.accent),
            ),
            const SizedBox(height: 6),
            Text(s.currentTodo?.label ?? '${s.todosDone} of ${s.todos.length} done',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.node, required this.sessions, required this.onTap});

  final Node node;
  final int sessions;
  final VoidCallback onTap;

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
            decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(10)),
            child: Icon(osIcon(node.os), color: c.muted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(node.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    OnlineDot(online: node.online),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    node.online ? 'Online' : 'Offline${node.lastSeen != null ? ' · ${ago(node.lastSeen)}' : ''}',
                    if (node.claudeVersion.isNotEmpty) 'Claude Code ${node.claudeVersion}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
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

class CardShell extends StatelessWidget {
  const CardShell({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(14), child: child)),
    );
  }
}

/// One device and all of its sessions.
class DevicePage extends StatelessWidget {
  const DevicePage({super.key, required this.node, required this.onSession});

  final String node;
  final ValueChanged<String> onSession;

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final c = context.colors;
    final status = hub.nodes[node];
    final sessions = hub.sessionsOf(node);
    final live = sessions.where((s) => s.isLive).toList();
    final rest = sessions.where((s) => !s.isLive).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      [
                        status.online ? 'Online' : 'Offline',
                        status.os,
                        if (status.hostname.isNotEmpty) status.hostname,
                        if (status.claudeVersion.isNotEmpty) 'Claude Code ${status.claudeVersion}',
                        if (status.agentVersion.isNotEmpty) 'agent ${status.agentVersion}',
                      ].join(' · '),
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ),
                SectionLabel('Live', trailing: Text('${live.length}', style: TextStyle(color: c.faint, fontSize: 12))),
                if (live.isEmpty) Text('No live sessions on this device.', style: TextStyle(color: c.muted, fontSize: 13)),
                for (final s in live) SessionTile(session: s, selected: false, dense: false, onTap: () => onSession(s.id)),
                SectionLabel('History', trailing: Text('${rest.length}', style: TextStyle(color: c.faint, fontSize: 12))),
                for (final s in rest) SessionTile(session: s, selected: false, dense: false, onTap: () => onSession(s.id)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
