import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../nav/nav_cubit.dart';
import '../theme/theme.dart';
import '../widgets/format.dart';

/// The sessions the chat's lead handed work to, with how each is getting
/// on. Tap one to see its conversation.
class ChatTasks extends StatefulWidget {
  const ChatTasks({super.key, required this.chat});

  final Chat chat;

  @override
  State<ChatTasks> createState() => _ChatTasksState();
}

class _ChatTasksState extends State<ChatTasks> {
  bool? _open;

  @override
  Widget build(BuildContext context) {
    final sessions = context.select<HubCubit, Map<String, Session>>((h) => h.state.hub.sessions);
    final tasks = [
      for (final l in widget.chat.links)
        if (l.role == 'started' && l.session != widget.chat.activeSession && sessions.containsKey(l.session)) sessions[l.session]!,
    ];
    if (tasks.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final working = tasks.where((s) => s.isBusy).length;
    final failed = tasks.where((s) => s.state == SessionState.error).length;
    final done = tasks.length - working - failed;
    final open = _open ?? working > 0;
    final summary = [
      if (working > 0) '$working working',
      if (done > 0) '$done done',
      if (failed > 0) '$failed failed',
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('chat-tasks'),
            onTap: () => setState(() => _open = !open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              child: Row(
                children: [
                  Icon(Icons.account_tree_outlined, size: 15, color: working > 0 ? c.accent : c.muted),
                  const SizedBox(width: 8),
                  Text('Tasks', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.muted))),
                  Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: c.faint),
                ],
              ),
            ),
          ),
          if (open)
            for (final s in tasks) _TaskRow(session: s),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    final nav = context.read<NavCubit>();
    final failed = s.state == SessionState.error;
    final (IconData icon, Color color, String status) = switch (s) {
      _ when s.isBusy => (Icons.autorenew_rounded, c.accent, s.currentTodo?.label ?? stateLabel(s.state)),
      _ when failed => (Icons.error_outline_rounded, c.danger, s.error.isEmpty ? 'Failed' : s.error),
      _ => (Icons.check_circle_rounded, c.success, 'Done'),
    };
    final steps = s.todos.length;
    return InkWell(
      key: Key('task-${s.id}'),
      onTap: () => nav.push(SessionEntry(s.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 16, color: color)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(
                    '${s.node} · ${s.scratch ? 'scratch' : s.cwd.isEmpty ? 'home folder' : baseName(s.cwd)} · $status',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: failed ? c.danger : c.muted),
                  ),
                  if (s.isBusy && steps > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: s.todosDone / steps, minHeight: 4, color: c.accent, backgroundColor: c.border),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(ago(s.updated), style: TextStyle(fontSize: 11.5, color: c.faint)),
          ],
        ),
      ),
    );
  }
}
