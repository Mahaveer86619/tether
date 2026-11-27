import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../ui/collapsible.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'team_cubit.dart';

/// Settings > Team: who is on the hub; an admin invites and removes people.
class TeamSection extends StatelessWidget {
  const TeamSection({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<TeamCubit>()..load(),
        child: const _TeamBody(),
      );
}

class _TeamBody extends StatelessWidget {
  const _TeamBody();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<TeamCubit>();
    final me = context.select<HubCubit, TeamUser?>((h) => h.state.hub.me);
    final admin = me?.isAdmin ?? false;
    return BlocConsumer<TeamCubit, TeamState>(
      listenWhen: (a, b) => a.failureId != b.failureId || a.invite != b.invite && b.invite != null,
      listener: (context, s) async {
        if (s.invite != null) {
          await showDialog<void>(context: context, builder: (_) => TeamInviteDialog(invite: s.invite!));
          await cubit.closeInvite();
        } else if (s.failure != null) {
          showFailure(context, s.failure!);
        }
      },
      builder: (context, s) => CollapsibleSection(
        title: 'Team',
        count: s.users.length,
        summary: 'The people on this hub',
        actions: [
          if (admin)
            FilledButton.icon(
              key: const Key('invite-teammate'),
              onPressed: cubit.invite,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Invite'),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Each person has their own login and devices, and sees only their own chats and sessions, and what is shared with them.',
                style: TextStyle(color: c.muted, fontSize: 13)),
            const SizedBox(height: 8),
            for (final u in s.users)
              ListTile(
                key: Key('user-${u.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(radius: 14, child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase())),
                title: Row(children: [
                  Flexible(child: Text(u.name, overflow: TextOverflow.ellipsis)),
                  if (u.isAdmin) ...[const SizedBox(width: 8), const Pill('admin')],
                  if (u.id == me?.id) ...[const SizedBox(width: 8), const Pill('you')],
                ]),
                trailing: admin && !u.isAdmin
                    ? IconButton(
                        key: Key('remove-${u.id}'),
                        tooltip: 'Remove',
                        icon: Icon(Icons.person_remove_outlined, color: c.danger),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              title: Text('Remove ${u.name}?'),
                              content: const Text('Their devices are signed out at once and the devices you shared with them are no longer theirs to use.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                                FilledButton(key: const Key('confirm-remove'), onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
                              ],
                            ),
                          );
                          if (ok ?? false) await cubit.remove(u.id);
                        },
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// The code a teammate types on their app's setup screen, with their name.
class TeamInviteDialog extends StatelessWidget {
  const TeamInviteDialog({super.key, required this.invite});

  final PairingInvite invite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Invite a teammate'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('On their device, they install Tether, join your tailnet and, on the setup screen, enter:', style: TextStyle(color: c.muted, fontSize: 13)),
            const SizedBox(height: 12),
            Text('Hub', style: TextStyle(color: c.faint, fontSize: 12)),
            SelectableText(invite.hubUrl, key: const Key('invite-hub'), style: monoStyle(context, size: 13)),
            const SizedBox(height: 8),
            Text('Invite code', style: TextStyle(color: c.faint, fontSize: 12)),
            SelectableText(invite.code, key: const Key('invite-code'), style: monoStyle(context, size: 20)),
            const SizedBox(height: 8),
            Text('and their name. It works once, until ${dayLabel(invite.expires)} ${clockTime(invite.expires)}.', style: TextStyle(color: c.muted, fontSize: 13)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: invite.code)), child: const Text('Copy code')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}
