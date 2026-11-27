import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../settings/team_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';

/// Who owns each device and who it is shared with; the owner shares or
/// stops sharing their own. A grant's change comes back with the node's
/// status, so the list follows the hub.
class DeviceSharingSection extends StatelessWidget {
  const DeviceSharingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final c = context.colors;
    final me = hub.me;
    if (me == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (_) => sl<TeamCubit>(),
      child: BlocListener<TeamCubit, TeamState>(
        listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
        listener: (context, s) => showFailure(context, s.failure!),
        child: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel('Owners and sharing'),
              for (final n in hub.sortedNodes)
                _NodeSharing(node: n, hub: hub, mine: n.owner.isEmpty || n.owner == me.id),
              if (hub.nodes.isEmpty) Text('No devices yet.', style: TextStyle(color: c.faint, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodeSharing extends StatelessWidget {
  const _NodeSharing({required this.node, required this.hub, required this.mine});

  final Node node;
  final HubSnapshot hub;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<TeamCubit>();
    return Padding(
      key: Key('sharing-${node.name}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text(mine ? 'Yours' : "${hub.userName(node.owner)}'s, shared with you", style: TextStyle(color: c.muted, fontSize: 12.5)),
                if (node.grants.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final g in node.grants)
                        InputChip(
                          key: Key('grant-${node.name}-${g.user}'),
                          label: Text('${hub.userName(g.user)} · ${g.access == DeviceAccess.full ? 'full' : 'jobs only'}', style: const TextStyle(fontSize: 12)),
                          onDeleted: () => cubit.unshare(node.name, g.user),
                          deleteButtonTooltipMessage: 'Stop sharing',
                        ),
                    ]),
                  ),
              ],
            ),
          ),
          if (mine)
            TextButton.icon(
              key: Key('share-${node.name}'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => BlocProvider.value(value: cubit, child: ShareDeviceSheet(node: node.name, users: [for (final u in hub.users.values) if (u.id != hub.me?.id) u])),
              ),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share'),
            ),
        ],
      ),
    );
  }
}

/// Pick a teammate and how much of the device they may use.
class ShareDeviceSheet extends StatefulWidget {
  const ShareDeviceSheet({super.key, required this.node, required this.users});

  final String node;
  final List<TeamUser> users;

  @override
  State<ShareDeviceSheet> createState() => _ShareDeviceSheetState();
}

class _ShareDeviceSheetState extends State<ShareDeviceSheet> {
  String? _user;
  DeviceAccess _access = DeviceAccess.jobs;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share ${widget.node}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (widget.users.isEmpty)
            Text('No one else is on this hub yet. Invite a teammate in Settings > Team.', style: TextStyle(color: c.muted))
          else ...[
            DropdownButtonFormField<String>(
              key: const Key('share-user'),
              initialValue: _user,
              decoration: const InputDecoration(labelText: 'With'),
              items: [for (final u in widget.users) DropdownMenuItem(value: u.id, child: Text(u.name))],
              onChanged: (v) => setState(() => _user = v),
            ),
            const SizedBox(height: 8),
            RadioGroup<DeviceAccess>(
              groupValue: _access,
              onChanged: (v) => setState(() => _access = v ?? _access),
              child: Column(children: [
                for (final a in DeviceAccess.values)
                  RadioListTile<DeviceAccess>(
                    key: Key('access-${a.wire}'),
                    value: a,
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.label),
                    subtitle: Text(a.blurb, style: TextStyle(fontSize: 12.5, color: c.muted)),
                  ),
              ]),
            ),
            if (_access == DeviceAccess.full)
              Container(
                key: const Key('share-warning'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.12), borderRadius: context.round(8)),
                child: Text(
                  'Their sessions run under your Claude Code login and spend your plan. You see everything they run here and can stop it, and you can stop sharing at any time.',
                  style: TextStyle(fontSize: 12.5, color: c.text),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('share-confirm'),
                onPressed: _user == null || _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final ok = await context.read<TeamCubit>().share(widget.node, _user!, _access);
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.pop(context);
                        } else {
                          setState(() => _busy = false);
                        }
                      },
                child: const Text('Share'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
