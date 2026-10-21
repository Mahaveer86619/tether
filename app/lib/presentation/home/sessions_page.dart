import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import 'cards.dart';
import 'monitor_page.dart';

enum SessionFilter { all, running, needsYou, finished, failed, hub, archived }

extension on SessionFilter {
  String get label => switch (this) {
        SessionFilter.all => 'All',
        SessionFilter.running => 'Running',
        SessionFilter.needsYou => 'Needs you',
        SessionFilter.finished => 'Finished',
        SessionFilter.failed => 'Failed',
        SessionFilter.hub => 'On the hub',
        SessionFilter.archived => 'Done',
      };

  bool matches(Session s, HubSnapshot hub, Set<String> waiting) => switch (this) {
        SessionFilter.all => !s.archived || s.isLive,
        SessionFilter.running => s.state == SessionState.running || s.state == SessionState.terminalActive,
        SessionFilter.needsYou => waiting.contains(s.id) || hub.approvalsFor(s.id).isNotEmpty,
        SessionFilter.finished => s.state == SessionState.idle && !s.archived,
        SessionFilter.failed => s.state == SessionState.error,
        SessionFilter.hub => s.scratch || s.global,
        SessionFilter.archived => s.archived,
      };
}

/// Every session, filtered by state and searched by title, prompt or folder.
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key, required this.onSession});

  final ValueChanged<String> onSession;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  SessionFilter _filter = SessionFilter.all;
  String _query = '';

  static const _pageSize = 60;
  int _shown = _pageSize;

  bool _found(Session s) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [s.title, s.lastPrompt, s.cwd, s.node, s.id].any((f) => f.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final c = context.colors;
    final waiting = {for (final s in needingYou(hub)) s.id};
    final all = hub.sessions.values.toList()..sort((a, b) => (b.updated ?? DateTime(0)).compareTo(a.updated ?? DateTime(0)));
    final counts = {for (final f in SessionFilter.values) f: all.where((s) => f.matches(s, hub, waiting)).length};
    final list = all.where((s) => _filter.matches(s, hub, waiting) && _found(s)).toList();
    return PageColumn(
      bottom: 96,
      children: [
        const SizedBox(height: 8),
        TextField(
          key: const Key('session-search'),
          onChanged: (v) => setState(() {
            _query = v.trim();
            _shown = _pageSize;
          }),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, size: 20),
            hintText: 'Search sessions',
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in SessionFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(counts[f]! > 0 && f != SessionFilter.all ? '${f.label} ${counts[f]}' : f.label),
                    selected: _filter == f,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() {
                      _filter = f;
                      _shown = _pageSize;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(_query.isEmpty ? 'Nothing here right now.' : 'No sessions match "$_query".',
                textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
          )
        else ...[
          CardGrid(children: [
            for (final s in list.take(_shown))
              SessionCard(session: s, online: hub.nodes[s.node]?.online ?? false, onTap: () => widget.onSession(s.id)),
          ]),
          if (list.length > _shown)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: TextButton(
                  onPressed: () => setState(() => _shown += _pageSize),
                  child: Text('Show more (${list.length - _shown} left)'),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
