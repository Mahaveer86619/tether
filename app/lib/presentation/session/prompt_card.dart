import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import 'terminal_sheet.dart';

/// A dialog read off Claude Code's screen (a survey, a menu, a picker): its
/// options as buttons, Esc to dismiss it, and the terminal for anything else.
class PromptCard extends StatelessWidget {
  const PromptCard({super.key, required this.approval, this.sessionTitle});

  final Approval approval;
  final String? sessionTitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = approval;
    final busy = context.select<HubCubit, bool>((cubit) => cubit.state.deciding.contains(a.id));
    final hub = context.read<HubCubit>();
    return Container(
      key: Key('prompt-card-${a.id}'),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.warning.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt_rounded, size: 18, color: c.warning),
              const SizedBox(width: 8),
              const Expanded(child: Text('Claude Code is asking', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              Text(a.node, style: TextStyle(fontSize: 12, color: c.faint)),
            ],
          ),
          if (sessionTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(sessionTitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
            ),
          const SizedBox(height: 8),
          Text(a.description, style: const TextStyle(fontSize: 13.5)),
          const SizedBox(height: 8),
          for (final (i, option) in a.options.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                key: Key('prompt-option-${i + 1}'),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  side: BorderSide(color: i == a.selected ? c.accent : c.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: busy ? null : () => hub.decide(a.id, allow: true, option: i + 1),
                child: Text(option, style: TextStyle(fontSize: 13, color: c.text)),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                key: const Key('prompt-terminal'),
                onPressed: () => showTerminalSheet(context, a.session),
                icon: const Icon(Icons.terminal_rounded, size: 16),
                label: const Text('Screen & keys'),
              ),
              const Spacer(),
              OutlinedButton(key: const Key('prompt-dismiss'), onPressed: busy ? null : () => hub.decide(a.id, allow: false), child: const Text('Esc')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown when a session waits on something but no card says what: a
/// dialog Tether couldn't read. The terminal is always the way out.
class StuckBanner extends StatelessWidget {
  const StuckBanner({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      key: const Key('stuck-banner'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.help_outline_rounded, size: 18, color: c.warning),
          const SizedBox(width: 8),
          const Expanded(child: Text('Claude Code is waiting on something on its screen.', style: TextStyle(fontSize: 13))),
          TextButton(key: const Key('stuck-open-terminal'), onPressed: () => showTerminalSheet(context, sessionId), child: const Text('Show screen')),
        ],
      ),
    );
  }
}
