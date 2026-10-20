import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../artifacts/artifact_widgets.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'cards.dart';

class _Event {
  const _Event(this.time, this.icon, this.color, this.title, this.detail, this.onTap);

  final DateTime time;
  final IconData icon;
  final Color color;
  final String title, detail;
  final VoidCallback onTap;
}

/// What happened lately, newest first: sessions started, forked, finished
/// or failed, and files saved to the hub.
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key, required this.onSession});

  final ValueChanged<String> onSession;

  static const _limit = 150;

  List<_Event> _events(BuildContext context, HubSnapshot hub) {
    final c = context.colors;
    final out = <_Event>[];
    for (final s in hub.sessions.values) {
      final where = [s.node, if (s.cwd.isNotEmpty) baseName(s.cwd) else if (s.scratch) 'scratch'].join(' · ');
      void open() => onSession(s.id);
      if (s.created case final t?) {
        final (verb, icon) = switch (s.lineage) {
          'fork' => ('Forked', Icons.call_split_rounded),
          'continue' => ('Continued on the hub', Icons.cloud_sync_outlined),
          _ => (s.scratch ? 'Started on the hub' : 'Started', Icons.play_arrow_rounded),
        };
        out.add(_Event(t, icon, c.info, '$verb: ${s.displayTitle}', where, open));
      }
      final end = s.updated;
      if (end == null || s.isLive || end == s.created) continue;
      if (s.state == SessionState.error) {
        out.add(_Event(end, Icons.error_outline_rounded, c.danger, 'Failed: ${s.displayTitle}', s.error.isEmpty ? where : s.error, open));
      } else {
        out.add(_Event(end, Icons.check_circle_outline_rounded, c.success, 'Finished: ${s.displayTitle}', where, open));
      }
    }
    for (final a in hub.artifacts.values) {
      final from = hub.sessions[a.session]?.displayTitle;
      out.add(_Event(
        a.created ?? DateTime(0),
        artifactIcon(a),
        c.accent,
        'Saved ${a.name}',
        [fileSize(a.size), if (from != null) from else if (a.node.isNotEmpty) a.node].join(' · '),
        () => openArtifact(context, a),
      ));
    }
    out.sort((a, b) => b.time.compareTo(a.time));
    return out.take(_limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final events = _events(context, hub);
    if (events.isEmpty) return const EmptyState(icon: Icons.history_rounded, title: 'Nothing yet', body: 'Sessions and files show up here as they happen.');
    final rows = <Widget>[];
    String? day;
    for (final e in events) {
      final d = dayLabel(e.time);
      if (d != day) {
        rows.add(SectionLabel(d));
        day = d;
      }
      rows.add(_EventRow(event: e));
    }
    return PageColumn(children: rows);
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final _Event event;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = event;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: e.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: e.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(e.icon, size: 16, color: e.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                  if (e.detail.isNotEmpty)
                    Text(e.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.faint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(clockTime(e.time), style: TextStyle(fontSize: 11.5, color: c.faint)),
          ],
        ),
      ),
    );
  }
}
