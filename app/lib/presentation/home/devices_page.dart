import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../settings/devices_cubit.dart';
import '../settings/pairing_widgets.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import 'cards.dart';

/// The machines running Tether, and the rest of the tailnet.
class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key, required this.onNode});

  final ValueChanged<String> onNode;

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final c = context.colors;
    final self = hub.nodes[hub.selfNode];
    final others = hub.otherNodes;
    Widget card(Node n) =>
        DeviceCard(node: n, sessions: hub.sessionsOf(n.name).length, isHub: n.name == hub.hubNode, isSelf: n == self, onTap: () => onNode(n.name));
    return BlocProvider(
      create: (_) => sl<DevicesCubit>()..load(),
      child: PageColumn(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              [
                if (hub.hubVersion.isNotEmpty) 'Hub ${hub.hubVersion}',
                if (hub.hubNode.isNotEmpty) 'runs on ${hub.hubNode}',
                hub.connected ? 'connected' : 'not connected',
              ].join(' · '),
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
          ),
          if (self != null) ...[
            const SectionLabel('This device'),
            CardGrid(children: [card(self)]),
          ],
          SectionLabel(self != null ? 'Other devices' : 'Running Tether',
              trailing: Text('${others.where((n) => n.online).length}/${others.length} online', style: TextStyle(color: c.faint, fontSize: 12))),
          if (others.isEmpty)
            Text(self != null ? 'No other devices run Tether yet. See docs/running.md to add one.' : 'No agents have connected yet. See docs/running.md to install one.',
                style: TextStyle(color: c.muted, fontSize: 13))
          else
            CardGrid(children: [for (final n in others) card(n)]),
          const SectionLabel('On your tailnet'),
          BlocBuilder<DevicesCubit, DevicesState>(
            builder: (context, s) {
              if (s.tailnetError != null) return Text(s.tailnetError!, style: TextStyle(color: c.faint, fontSize: 13));
              if (s.tailnet.isEmpty) {
                return s.loading ? const LinearProgressIndicator(minHeight: 2) : Text('Nothing listed.', style: TextStyle(color: c.faint, fontSize: 13));
              }
              return Column(children: [for (final d in s.tailnet) TailnetRow(device: d, isSelf: d.ips.contains(hub.clientIp))]);
            },
          ),
        ],
      ),
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
    final online = status?.online ?? false;
    return PageColumn(
      bottom: 96,
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
        if (live.isEmpty)
          Text('No live sessions on this device.', style: TextStyle(color: c.muted, fontSize: 13))
        else
          CardGrid(children: [for (final s in live) SessionCard(session: s, online: online, onTap: () => onSession(s.id))]),
        SectionLabel('History', trailing: Text('${rest.length}', style: TextStyle(color: c.faint, fontSize: 12))),
        CardGrid(children: [for (final s in rest.take(60)) SessionCard(session: s, online: online, onTap: () => onSession(s.id))]),
      ],
    );
  }
}
