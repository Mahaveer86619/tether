import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../theme/theme.dart';
import '../ui/collapsible.dart';
import '../ui/tokens.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'notifications_cubit.dart';

/// Settings: being told when Claude finishes or needs you, with the app closed.
class NotificationsSection extends StatelessWidget {
  const NotificationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MultiBlocListener(
      listeners: [
        BlocListener<NotificationsCubit, NotificationsState>(
          listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
          listener: (context, s) => showFailure(context, s.failure!),
        ),
        BlocListener<NotificationsCubit, NotificationsState>(
          listenWhen: (a, b) => a.noticeId != b.noticeId && b.notice.isNotEmpty,
          listener: (context, s) => showToast(context, s.notice),
        ),
      ],
      child: BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, s) {
        final cubit = context.read<NotificationsCubit>();
        final on = s.settings.enabled;
        return CollapsibleSection(
          title: 'Notifications',
          summary: on ? 'On' : 'Off',
          initiallyOpen: on,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!s.available)
                Text(
                  'Notifications come to your phone. On this computer Tether shows what happens while it is open; install Tether on your phone to be told when you are away.',
                  style: TextStyle(color: c.muted, fontSize: 13),
                )
              else ...[
                Text(
                  'Leave a chat after sending a prompt and get a notification when Claude is done or needs you. It reaches you over Tailscale when it is on, and through the hub\'s tunnel when it is not.',
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
                const SizedBox(height: Gap.sm),
                SwitchListTile(
                  key: const Key('notify-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tell me when Claude finishes or needs me'),
                  value: on,
                  onChanged: s.busy ? null : cubit.setEnabled,
                ),
                if (on && !s.permitted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: Text('Android has not allowed Tether to show notifications. Allow them in the system settings for Tether.', style: TextStyle(color: c.warning, fontSize: 13)),
                  ),
                if (on) ...[
                  for (final (kind, label, hint) in const [
                    (NotifyKind.finished, 'Finished', 'Claude has answered'),
                    (NotifyKind.approval, 'Needs you', 'an approval or a question is waiting'),
                    (NotifyKind.failed, 'Failed', 'a session stopped with an error'),
                  ])
                    CheckboxListTile(
                      key: Key('notify-${kind.name}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(label),
                      subtitle: Text(hint, style: TextStyle(fontSize: 12, color: c.faint)),
                      value: s.settings.kinds.contains(kind),
                      onChanged: s.busy ? null : (v) => cubit.setKind(kind, v ?? false),
                    ),
                  const SizedBox(height: Gap.sm),
                  _Reach(state: s),
                  const SizedBox(height: Gap.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('notify-test'),
                      onPressed: cubit.sendTest,
                      icon: const Icon(Icons.notifications_active_outlined, size: 18),
                      label: const Text('Send a test'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
      ),
    );
  }
}

/// How notifications get here: the last time the listener heard from the hub,
/// and whether there is a tunnel for when Tailscale is off.
class _Reach extends StatelessWidget {
  const _Reach({required this.state});

  final NotificationsState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final st = state.status;
    Widget line(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: Gap.sm),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: c.muted))),
          ]),
        );
    return Column(
      key: const Key('notify-reach'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (st.error.isNotEmpty)
          line(Icons.error_outline_rounded, c.warning, st.error)
        else if (st.lastOk != null)
          line(Icons.check_circle_outline_rounded, c.success, 'Listening. Last heard from the hub ${ago(st.lastOk)} ago.')
        else
          line(Icons.hourglass_empty_rounded, c.faint, 'Starting to listen…'),
        if (state.tunnel.isEmpty)
          line(Icons.cloud_off_rounded, c.faint, 'The hub has no notification tunnel, so you are told only while Tailscale is on. Start the hub with -notify-tunnel to be reached anywhere.')
        else
          line(Icons.public_rounded, c.accent, 'Reaches you without Tailscale through the hub\'s tunnel. The tunnel carries only titles, not what Claude said.'),
      ],
    );
  }
}
