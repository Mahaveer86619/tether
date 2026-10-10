import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

/// Devices and their sessions as a tree: the desktop sidebar's body.
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
  final _expanded = <String>{};
  String _query = '';

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
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            children: [
              for (final n in nodes) ...[
                _NodeRow(
                  node: n,
                  selected: widget.selectedNode == n.name && widget.selectedSession == null,
                  collapsed: _collapsed.contains(n.name),
                  onToggle: () => setState(() => _collapsed.contains(n.name) ? _collapsed.remove(n.name) : _collapsed.add(n.name)),
                  onTap: () => widget.onNode(n.name),
                ),
                if (!_collapsed.contains(n.name)) ..._sessions(hub, n.name),
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

  List<Widget> _sessions(HubSnapshot hub, String node) {
    var list = hub.sessionsOf(node);
    if (_query.isNotEmpty) {
      list = list
          .where((s) => s.title.toLowerCase().contains(_query) || s.cwd.toLowerCase().contains(_query) || s.id.startsWith(_query))
          .toList();
    }
    final all = _expanded.contains(node) || _query.isNotEmpty;
    final live = list.where((s) => s.isLive).length;
    final limit = all ? list.length : (live > _shown ? live : _shown);
    return [
      for (final s in list.take(limit)) SessionTile(session: s, selected: s.id == widget.selectedSession, onTap: () => widget.onSession(s.id)),
      if (_query.isEmpty && list.length > _shown)
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
              Padding(padding: const EdgeInsets.only(top: 6), child: StateDot(state: s.state, size: 7)),
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
