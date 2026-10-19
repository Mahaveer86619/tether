import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

/// The desktop sidebar's body: sessions grouped by project (folder) or by
/// device, with sessions marked done tucked away at the end.
class SessionNavigator extends StatefulWidget {
  const SessionNavigator({
    super.key,
    required this.selectedSession,
    required this.selectedNode,
    required this.onSession,
    required this.onNode,
  });

  final String? selectedSession;
  final String? selectedNode;
  final ValueChanged<String> onSession;
  final ValueChanged<String> onNode;

  @override
  State<SessionNavigator> createState() => _SessionNavigatorState();
}

class _SessionNavigatorState extends State<SessionNavigator> {
  final _collapsed = <String>{};

  /// Projects the user opened or closed; the rest start closed, unless they
  /// hold the open session or a search is on.
  final _projectOpen = <String, bool>{};
  final _expanded = <String>{};
  String _query = '';
  bool _byProject = true;
  bool _showDone = false;

  static const _shown = 8;

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final c = context.colors;
    final nodes = hub.sortedNodes;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search sessions',
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.faint),
              prefixIconConstraints: const BoxConstraints(minWidth: 36),
              fillColor: c.canvas,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12.5),
              selectedBackgroundColor: c.raised,
              side: BorderSide(color: c.border),
            ),
            segments: const [
              ButtonSegment(value: true, label: Text('Projects'), icon: Icon(Icons.folder_outlined, size: 16)),
              ButtonSegment(value: false, label: Text('Devices'), icon: Icon(Icons.devices_outlined, size: 16)),
            ],
            selected: {_byProject},
            onSelectionChanged: (v) => setState(() => _byProject = v.first),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            children: _byProject ? _projects(hub) : [
              for (final n in nodes) ...[
                _NodeRow(
                  node: n,
                  selected: widget.selectedNode == n.name && widget.selectedSession == null,
                  collapsed: _collapsed.contains(n.name),
                  onToggle: () => setState(() => _collapsed.contains(n.name) ? _collapsed.remove(n.name) : _collapsed.add(n.name)),
                  onTap: () => widget.onNode(n.name),
                ),
                if (!_collapsed.contains(n.name)) ..._sessions(hub.sessionsOf(n.name), n.name),
              ],
              if (nodes.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No devices yet. Start tether-agent on a machine.', style: TextStyle(color: c.muted, fontSize: 13)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _matches(Session s) =>
      _query.isEmpty || s.title.toLowerCase().contains(_query) || s.cwd.toLowerCase().contains(_query) || s.id.startsWith(_query);

  List<Widget> _projects(HubSnapshot hub) {
    final c = context.colors;
    final done = hub.sessions.values.where((s) => s.archived && !s.isLive && _matches(s)).toList()..sort(compareSessions);
    return [
      for (final p in hub.projects())
        if (p.sessions.any(_matches)) ...() {
          final open = _projectOpen[p.key] ?? (_query.isNotEmpty || p.sessions.any((s) => s.id == widget.selectedSession));
          return [
            _ProjectRow(project: p, collapsed: !open, onToggle: () => setState(() => _projectOpen[p.key] = !open)),
            if (open) ..._sessions(p.sessions, p.key, shown: 4),
          ];
        }(),
      if (done.isNotEmpty) ...[
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _showDone = !_showDone),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                Icon(_showDone ? Icons.expand_more_rounded : Icons.chevron_right_rounded, size: 18, color: c.faint),
                const SizedBox(width: 4),
                Icon(Icons.done_all_rounded, size: 16, color: c.faint),
                const SizedBox(width: 8),
                Expanded(child: Text('Done', style: TextStyle(fontSize: 13, color: c.muted, fontWeight: FontWeight.w600))),
                Text('${done.length}', style: TextStyle(fontSize: 12, color: c.faint)),
              ],
            ),
          ),
        ),
        if (_showDone)
          for (final s in done) SessionTile(session: s, selected: s.id == widget.selectedSession, onTap: () => widget.onSession(s.id)),
      ],
    ];
  }

  List<Widget> _sessions(List<Session> sessions, String node, {int shown = _shown}) {
    final list = sessions.where(_matches).toList();
    final all = _expanded.contains(node) || _query.isNotEmpty;
    final live = list.where((s) => s.isLive).length;
    final limit = all ? list.length : (live > shown ? live : shown);
    return [
      for (final s in list.take(limit)) SessionTile(session: s, selected: s.id == widget.selectedSession, onTap: () => widget.onSession(s.id)),
      if (_query.isEmpty && list.length > shown)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => all ? _expanded.remove(node) : _expanded.add(node)),
            child: Text(all ? 'Show less' : 'Show all ${list.length}', style: const TextStyle(fontSize: 12)),
          ),
        ),
    ];
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.collapsed, required this.onToggle});

  final Project project;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = project;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 2, 6),
          child: Row(
            children: [
              Icon(collapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded, size: 18, color: c.faint),
              const SizedBox(width: 4),
              Icon(Icons.folder_outlined, size: 16, color: c.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: p.cwd.isEmpty ? 'Home folder on ${p.node}' : '${p.cwd} on ${p.node}',
                  waitDuration: const Duration(milliseconds: 600),
                  child: Text(p.cwd.isEmpty ? 'Home folder' : baseName(p.cwd), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              if (p.liveCount > 0) ...[Pill('${p.liveCount} live', color: c.accent), const SizedBox(width: 6)],
              Text(p.node, style: TextStyle(fontSize: 11.5, color: c.faint)),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.node, required this.selected, required this.collapsed, required this.onToggle, required this.onTap});

  final Node node;
  final bool selected, collapsed;
  final VoidCallback onToggle, onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Material(
        color: selected ? c.raised : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 2, 6),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onToggle,
                  child: Icon(collapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded, size: 18, color: c.faint),
                ),
                const SizedBox(width: 4),
                Icon(osIcon(node.os), size: 16, color: c.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                if (node.runningSessions > 0) ...[Pill('${node.runningSessions} live', color: c.accent), const SizedBox(width: 6)],
                OnlineDot(online: node.online),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.session, required this.selected, required this.onTap, this.dense = true});

  final Session session;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    final sub = [if (s.cwd.isNotEmpty) baseName(s.cwd), ago(s.updated)].where((x) => x.isNotEmpty).join(' · ');
    return Material(
      color: selected ? c.raised : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(dense ? 28 : 12, dense ? 7 : 10, 8, dense ? 7 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: s.isFork ? Icon(Icons.call_split_rounded, size: 11, color: stateColor(context, s.state)) : StateDot(state: s.state, size: 7),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: dense ? 13 : 14.5, color: c.text, fontWeight: selected ? FontWeight.w600 : null)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (s.isLive)
                          Flexible(
                            child: Text('${stateLabel(s.state)} · ', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5, color: stateColor(context, s.state))),
                          ),
                        Flexible(child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.faint))),
                      ],
                    ),
                  ],
                ),
              ),
              if (hostLabel(s.host).isNotEmpty) Padding(padding: const EdgeInsets.only(left: 6, top: 2), child: Pill(hostLabel(s.host))),
            ],
          ),
        ),
      ),
    );
  }
}
