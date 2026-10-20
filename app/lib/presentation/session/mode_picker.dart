import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/format.dart';

IconData modeIcon(PermissionMode m) => switch (m) {
      PermissionMode.normal => Icons.shield_outlined,
      PermissionMode.acceptEdits => Icons.edit_note_rounded,
      PermissionMode.plan => Icons.map_outlined,
      PermissionMode.auto => Icons.bolt_rounded,
    };

Color modeColor(BuildContext context, PermissionMode m) {
  final c = context.colors;
  return switch (m) {
    PermissionMode.normal => c.muted,
    PermissionMode.acceptEdits => c.warning,
    PermissionMode.plan => c.info,
    PermissionMode.auto => c.danger,
  };
}

/// The session's permission mode at a glance, with when it goes back if it
/// was set for a while; tap to switch.
class ModeChip extends StatelessWidget {
  const ModeChip({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final mode = PermissionMode.of(session.permissionMode);
    if (mode == null) return const SizedBox.shrink();
    final color = modeColor(context, mode);
    final revert = session.modeRevert;
    return Tooltip(
      message: 'Permission mode: ${mode.label}. Tap to change.',
      child: InkWell(
        key: const Key('mode-chip'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => showModePicker(context, session),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            border: Border.all(color: color.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(modeIcon(mode), size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                revert == null ? mode.label : '${mode.label} · ${untilLabel(revert)}',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "12m left", "1h 5m left", "now".
String untilLabel(DateTime at, {DateTime? now}) {
  final left = at.difference(now ?? DateTime.now());
  if (left.inMinutes < 1) return 'now';
  if (left.inHours < 1) return '${left.inMinutes}m left';
  return '${left.inHours}h ${left.inMinutes % 60}m left';
}

/// Picks a mode, for good or for a while.
Future<void> showModePicker(BuildContext context, Session session) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(value: context.read<HubCubit>(), child: _ModePicker(session: session)),
    );

class _ModePicker extends StatefulWidget {
  const _ModePicker({required this.session});

  final Session session;

  @override
  State<_ModePicker> createState() => _ModePickerState();
}

class _ModePickerState extends State<_ModePicker> {
  Duration? _for;

  static const _durations = <(Duration?, String)>[
    (null, 'Until I change it'),
    (Duration(minutes: 15), '15 min'),
    (Duration(hours: 1), '1 hour'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = PermissionMode.of(widget.session.permissionMode);
    final revert = widget.session.modeRevert;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Permission mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            if (revert != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Goes back to ${PermissionMode.of(widget.session.modeRevertTo)?.label ?? 'Ask first'} at ${clockTime(revert)}.',
                  style: TextStyle(fontSize: 12.5, color: c.muted),
                ),
              ),
            const SizedBox(height: 8),
            for (final m in PermissionMode.values)
              ListTile(
                key: Key('mode-${m.wire}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(modeIcon(m), color: modeColor(context, m)),
                title: Text(m.label),
                subtitle: Text(m.blurb, style: TextStyle(fontSize: 12.5, color: c.muted)),
                trailing: m == current ? Icon(Icons.check_rounded, color: c.accent) : null,
                onTap: () {
                  context.read<HubCubit>().setMode(widget.session.id, m, revertAfter: m == PermissionMode.normal ? null : _for);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 6),
            Text('For', style: TextStyle(fontSize: 12.5, color: c.muted)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final (d, label) in _durations)
                  ChoiceChip(
                    key: Key('mode-for-${d?.inMinutes ?? 0}'),
                    label: Text(label),
                    selected: _for == d,
                    onSelected: (_) => setState(() => _for = d),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
