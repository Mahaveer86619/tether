import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/version.dart';
import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../settings/devices_cubit.dart';
import '../settings/pairing_widgets.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'cards.dart';

/// Everything that makes up Tether, in the order it's set up: the hub, the
/// machines running its agent, and the apps, each with its version against
/// the hub's; then the rest of the tailnet.
class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key, required this.onNode});

  final ValueChanged<String> onNode;

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final c = context.colors;
    final self = hub.nodes[hub.selfNode];
    final others = hub.otherNodes;
    Widget card(Node n) => DeviceCard(
          node: n,
          sessions: hub.sessionsOf(n.name).length,
          isHub: n.name == hub.hubNode,
          isSelf: n == self,
          hubVersion: hub.hubVersion,
          onTap: () => onNode(n.name),
        );
    return BlocProvider(
      create: (_) => sl<DevicesCubit>()..load(),
      child: PageColumn(
        children: [
          const SectionLabel('1 · Hub'),
          _HubCard(hub: hub, onNode: onNode),
          SectionLabel('2 · Devices running the agent',
              trailing: Text('${hub.nodes.values.where((n) => n.online).length}/${hub.nodes.length} online', style: TextStyle(color: c.faint, fontSize: 12))),
          if (self != null) CardGrid(children: [card(self)]),
          if (others.isEmpty)
            Text(self != null ? 'No other devices run Tether yet. See docs/running.md to add one.' : 'No agents have connected yet. See docs/running.md to install one.',
                style: TextStyle(color: c.muted, fontSize: 13))
          else
            CardGrid(children: [for (final n in others) card(n)]),
          const SectionLabel('3 · Apps'),
          BlocBuilder<DevicesCubit, DevicesState>(
            builder: (context, s) {
              final clients = s.clients;
              if (clients == null) {
                return Text(s.loading ? 'Loading…' : 'This hub is too old to list its apps; update it first.', style: TextStyle(color: c.faint, fontSize: 13));
              }
              return Column(children: [for (final a in clients) _AppRow(app: a, hubVersion: hub.hubVersion, isSelf: a.deviceId.isNotEmpty && a.deviceId == hub.deviceId)]);
            },
          ),
          const _SetupGuide(),
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

class _HubCard extends StatelessWidget {
  const _HubCard({required this.hub, required this.onNode});

  final HubSnapshot hub;
  final ValueChanged<String> onNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CardShell(
      key: const Key('hub-card'),
      // Opens the machine it runs on, when an agent runs there too.
      onTap: () => hub.hubNode.isEmpty ? null : onNode(hub.hubNode),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.hub_outlined, color: c.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(hub.hubVersion.isEmpty ? 'Hub' : 'Hub ${hub.hubVersion}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  OnlineDot(online: hub.connected),
                  if (isOlderVersion(hub.hubVersion, appVersion)) ...[
                    const SizedBox(width: 8),
                    Pill('older than this app', key: const Key('update-hub'), color: c.warning),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(
                  [
                    if (hub.hubNode.isNotEmpty) 'runs on ${hub.hubNode}' else 'its machine runs no agent',
                    hub.connected ? 'connected' : 'not connected',
                    'everything connects here',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.hubVersion, required this.isSelf});

  final ConnectedClient app;
  final String hubVersion;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final old = isOlderVersion(app.appVersion, hubVersion);
    return ListTile(
      key: Key('app-${app.name}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(osIcon(app.platform), color: c.muted),
      title: Row(children: [
        Flexible(child: Text(app.name, overflow: TextOverflow.ellipsis)),
        if (isSelf) ...[const SizedBox(width: 8), const Pill('this app')],
        if (old) ...[const SizedBox(width: 8), Pill('update', color: c.warning)],
      ]),
      subtitle: Text(
        [
          app.appVersion.isEmpty ? 'version unknown (before 0.15)' : 'app ${app.appVersion}',
          if (app.connected != null) 'connected ${ago(app.connected)}',
        ].join(' · '),
        style: TextStyle(fontSize: 12, color: c.faint),
      ),
    );
  }
}

/// How Tether is put together, for adding a device.
class _SetupGuide extends StatelessWidget {
  const _SetupGuide();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget step(String n, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 11, backgroundColor: c.raised, child: Text(n, style: TextStyle(fontSize: 12, color: c.muted))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(body, style: TextStyle(fontSize: 12.5, color: c.muted)),
              ]),
            ),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ExpansionTile(
        key: const Key('setup-guide'),
        tilePadding: EdgeInsets.zero,
        title: const Text('Adding a device', style: TextStyle(fontSize: 14)),
        subtitle: Text('Hub first, then the agent on each machine, then the apps', style: TextStyle(fontSize: 12, color: c.faint)),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          step('1', 'The hub', 'Runs on an always-on machine on your tailnet (tether-hub, systemd). Update it first: agents and apps are made to work with a hub at least as new.'),
          step('2', 'The agent on each machine', 'tether-agent next to Claude Code on every machine whose sessions you want here. Pair it with a code from "Add a device", or tetherctl pair.'),
          step('3', 'The apps', 'Android and Windows. Pair by scanning the QR code from "Add a device" on a paired app, or connect over Tailscale.'),
          Text('Step by step, with commands: docs/running.md.', style: TextStyle(fontSize: 12, color: c.faint)),
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
