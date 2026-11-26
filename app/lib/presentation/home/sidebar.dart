import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../chats/chats_cubit.dart';
import '../chats/chats_page.dart';
import '../hub/hub_cubit.dart';
import '../nav/nav_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';

/// The places that aren't a chat, as icons under the New chat button.
const _tools = <({Destination d, IconData icon, String label})>[
  (d: Destination.devices, icon: Icons.devices_outlined, label: 'Devices'),
  (d: Destination.activity, icon: Icons.history_rounded, label: 'History'),
  (d: Destination.files, icon: Icons.folder_open_outlined, label: 'Files'),
  (d: Destination.routines, icon: Icons.auto_awesome_outlined, label: 'Routines'),
  (d: Destination.rules, icon: Icons.rule_rounded, label: 'Rules'),
  (d: Destination.insights, icon: Icons.query_stats_rounded, label: 'Insights'),
  (d: Destination.usage, icon: Icons.insights_outlined, label: 'Usage'),
];

/// How many one-off chats the sidebar lists before sending you to the full list.
const _oneOffsShown = 5;

/// What the side panel holds, on a phone's drawer and a wide window's
/// sidebar alike: a new chat, the places, then projects (their chats and the
/// sessions each chat spawned), folders not yet in a project, and last and
/// quietest the one-off chats. See docs/architecture/app.md#sidebar.
class SidebarBody extends StatefulWidget {
  const SidebarBody({super.key, this.onCollapse, this.onNavigate});

  /// A button to fold the sidebar away, where it can be.
  final VoidCallback? onCollapse;

  /// Called after the sidebar sent you somewhere, so a drawer can close.
  final VoidCallback? onNavigate;

  @override
  State<SidebarBody> createState() => _SidebarBodyState();
}

class _SidebarBodyState extends State<SidebarBody> {
  bool _projectsOpen = true;
  bool? _unfiledOpen;
  bool _oneOffsOpen = true;

  /// Projects, folders and chats the user opened or closed; the rest open
  /// when they hold what is on screen.
  final _open = <String, bool>{};

  void _go(VoidCallback f) {
    f();
    widget.onNavigate?.call();
  }

  bool _isOpen(String key, bool fallback) => _open[key] ?? fallback;

  void _toggle(String key, bool open) => setState(() => _open[key] = !open);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final s = context.watch<NavCubit>().state;
    final hub = context.select<HubCubit, HubSnapshot>((h) => h.state.hub);
    final selected = s.selectedChat.isNotEmpty ? s.selectedChat : s.selectedSession;
    final tree = hub.chatsSupported ? hub.sidebarTree() : const SidebarTree();
    final unfiledOpen = _unfiledOpen ?? tree.projects.isEmpty;
    final onSettings = s.destination == Destination.settings && s.top == null;
    return Container(
      color: c.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
              child: Row(
                children: [
                  Icon(Icons.hub_rounded, size: 20, color: c.accent),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Tether', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                  if (widget.onCollapse != null) IconButton(key: const Key('collapse-sidebar'), tooltip: 'Hide the sidebar', icon: const Icon(Icons.keyboard_double_arrow_left_rounded, size: 20), onPressed: widget.onCollapse),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: FilledButton.icon(
                key: const Key('new-chat'),
                onPressed: () => _go(() => nav.select(Destination.home)),
                icon: const Icon(Icons.edit_square, size: 17),
                label: const Text('New chat'),
                style: FilledButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final t in _tools)
                    Expanded(
                      child: IconButton(
                        key: Key('nav-${t.d.name}'),
                        tooltip: t.label,
                        icon: Icon(t.icon, size: 20),
                        constraints: const BoxConstraints(minHeight: 40),
                        padding: EdgeInsets.zero,
                        color: s.top == null && s.destination == t.d || t.d == Destination.devices && s.top is NodeEntry ? c.accent : c.muted,
                        onPressed: () => _go(() => nav.select(t.d)),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 8, color: c.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                children: [
                  if (tree.projects.isNotEmpty) ...[
                    _Header(id: 'projects', label: 'Projects', open: _projectsOpen, count: tree.projects.length, onTap: () => setState(() => _projectsOpen = !_projectsOpen)),
                    if (_projectsOpen)
                      for (final p in tree.projects) ..._namedProject(context, hub, p, selected),
                  ],
                  if (tree.unfiled.isNotEmpty) ...[
                    _Header(id: 'unfiled', label: 'Unfiled folders', open: unfiledOpen, count: tree.unfiled.length, onTap: () => setState(() => _unfiledOpen = !unfiledOpen)),
                    if (unfiledOpen)
                      for (final p in tree.unfiled) ..._folder(context, hub, p, tree.unfiled, selected),
                  ],
                  _Header(id: 'one-offs', label: 'One-offs', open: _oneOffsOpen, count: tree.oneOffs.length, onTap: () => setState(() => _oneOffsOpen = !_oneOffsOpen)),
                  if (_oneOffsOpen) ...[
                    if (tree.oneOffs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                        child: Text('Quick questions with no project show up here.', style: TextStyle(color: c.faint, fontSize: 12)),
                      ),
                    for (final chat in tree.oneOffs.take(_oneOffsShown))
                      ChatRow(keyPrefix: 'oneoff', quiet: true, chat: chat, selected: chat.id == selected, onTap: () => _go(() => nav.openChat(chat.id, replace: true))),
                    if (tree.oneOffs.length > _oneOffsShown)
                      SidebarRow(
                        key: const Key('all-chats'),
                        quiet: true,
                        title: 'All chats',
                        selected: false,
                        trailing: Padding(padding: const EdgeInsets.only(right: 4), child: Text('${tree.oneOffs.length}', style: TextStyle(fontSize: 11.5, color: c.faint))),
                        onTap: () => _go(() => nav.select(Destination.chats)),
                      ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  const Expanded(child: HubConnectionLine()),
                  IconButton(
                    key: const Key('nav-settings'),
                    tooltip: 'Settings',
                    icon: Icon(onSettings ? Icons.settings_rounded : Icons.settings_outlined, size: 20),
                    color: onSettings ? c.accent : null,
                    onPressed: () => _go(() => nav.select(Destination.settings)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _namedProject(BuildContext context, HubSnapshot hub, ProjectGroup p, String selected) {
    final key = 'project:${p.info.id}';
    final holds = p.chats.any((x) => x.chat.id == selected || x.spawned.any((s) => s.id == selected)) || p.sessions.any((x) => x.id == selected);
    final open = _isOpen(key, holds);
    return [
      _GroupRow(
        key: Key('named-project-${p.info.id}'),
        icon: open ? Icons.folder_special : Icons.folder_special_outlined,
        title: p.info.name,
        tooltip: [for (final f in p.info.folders) '${f.node} · ${f.cwd}'].join('\n'),
        count: p.count,
        trailing: _Markers(id: p.info.id, needsYou: p.needsYou, running: p.running),
        onTap: () => _toggle(key, open),
      ),
      if (open) ...[
        if (p.chats.isEmpty && p.sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(46, 2, 8, 6),
            child: Text('No chats yet. Start one with New chat.', style: TextStyle(color: context.colors.faint, fontSize: 12)),
          ),
        for (final pc in p.chats) ..._projectChat(context, hub, pc, selected),
        for (final session in p.sessions) _sessionRow(context, session, selected),
      ],
    ];
  }

  List<Widget> _projectChat(BuildContext context, HubSnapshot hub, ProjectChat pc, String selected) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final key = 'chat:${pc.chat.id}';
    final open = _isOpen(key, pc.chat.id == selected || pc.spawned.any((s) => s.id == selected || s.isBusy || hub.needsYou(s)));
    return [
      ChatRow(
        keyPrefix: 'project-chat',
        chat: pc.chat,
        indent: 18,
        selected: pc.chat.id == selected,
        onTap: () => _go(() => nav.openChat(pc.chat.id, replace: true)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Markers(id: pc.chat.id, needsYou: pc.needsYou, running: pc.running),
            if (pc.spawned.isNotEmpty)
              InkWell(
                key: Key('chat-tasks-${pc.chat.id}'),
                borderRadius: context.round(6),
                onTap: () => _toggle(key, open),
                child: Tooltip(
                  message: open ? 'Hide its sessions' : 'Show the sessions it started',
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${pc.spawned.length}', style: TextStyle(fontSize: 11.5, color: c.faint)),
                        Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: c.faint),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      if (open)
        for (final s in pc.spawned)
          _SpawnedRow(session: s, needsYou: hub.needsYou(s), selected: s.id == selected, onTap: () => _go(() => nav.openSession(s.id, replace: true))),
    ];
  }

  List<Widget> _folder(BuildContext context, HubSnapshot hub, ChatProject p, List<ChatProject> all, String selected) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final open = _isOpen(p.key, p.chats.any((x) => x.id == selected) || p.sessions.any((x) => x.id == selected));
    return [
      _GroupRow(
        key: Key('project-${p.key}'),
        icon: open ? Icons.folder_open_outlined : Icons.folder_outlined,
        title: p.labelAmong(all),
        tooltip: '${p.node} · ${p.cwd}',
        count: p.count,
        trailing: hub.projectsSupported
            ? IconButton(
                key: Key('file-${p.key}'),
                tooltip: 'Add to projects',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                color: c.faint,
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: () async {
                  final name = await context.read<ChatsCubit>().fileFolder(p.node, p.cwd);
                  if (name != null && context.mounted) showToast(context, 'Added to projects as $name', icon: Icons.folder_special_outlined);
                },
              )
            : null,
        onTap: () => _toggle(p.key, open),
      ),
      if (open)
        for (final chat in p.chats) ChatRow(keyPrefix: 'project-chat', chat: chat, indent: 18, selected: chat.id == selected, onTap: () => _go(() => nav.openChat(chat.id, replace: true))),
      if (open)
        for (final session in p.sessions) _sessionRow(context, session, selected),
    ];
  }

  Widget _sessionRow(BuildContext context, Session session, String selected) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    return InkWell(
      key: Key('project-session-${session.id}'),
      borderRadius: context.round(8),
      onTap: () => _go(() => nav.openSession(session.id, replace: true)),
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 18 + 10),
        decoration: BoxDecoration(color: session.id == selected ? c.accent.withValues(alpha: 0.12) : null, borderRadius: context.round(8)),
        child: Row(
          children: [
            Icon(Icons.terminal_rounded, size: 14, color: session.isLive ? c.accent : c.faint),
            const SizedBox(width: 8),
            Expanded(child: Text(session.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

/// A project or folder: a row that opens to what is in it.
class _GroupRow extends StatelessWidget {
  const _GroupRow({super.key, required this.icon, required this.title, required this.tooltip, required this.count, required this.onTap, this.trailing});

  final IconData icon;
  final String title, tooltip;
  final int count;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      borderRadius: context.round(8),
      child: InkWell(
        borderRadius: context.round(8),
        onTap: onTap,
        child: SizedBox(
          height: 38,
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: c.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: tooltip,
                  waitDuration: const Duration(milliseconds: 600),
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ),
              ?trailing,
              const SizedBox(width: 4),
              Text('$count', style: TextStyle(fontSize: 12, color: c.faint)),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dots rolled up from a chat's sessions: the warning colour when one waits
/// on you, the accent while one is working.
class _Markers extends StatelessWidget {
  const _Markers({required this.id, required this.needsYou, required this.running});

  final String id;
  final bool needsYou, running;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget dot(String kind, Color color, String tip) => Tooltip(
          key: Key('$kind-$id'),
          message: tip,
          child: Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (needsYou) dot('needs-you', c.warning, 'Needs you'),
        if (running) dot('running', c.accent, 'Working'),
      ],
    );
  }
}

/// A session a project chat started: the device it runs on, its state and
/// what it is on or how it ended.
class _SpawnedRow extends StatelessWidget {
  const _SpawnedRow({required this.session, required this.needsYou, required this.selected, required this.onTap});

  final Session session;
  final bool needsYou, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    final status = needsYou
        ? 'needs you'
        : switch (s.state) {
            SessionState.running => 'running',
            SessionState.awaitingApproval => 'needs you',
            SessionState.error => 'failed',
            SessionState.ready || SessionState.terminalActive => 'open',
            SessionState.idle => 'done',
          };
    final detail = s.state == SessionState.error && s.error.isNotEmpty ? s.error : (s.currentTodo?.label ?? s.displayTitle);
    return InkWell(
      key: Key('spawned-${s.id}'),
      borderRadius: context.round(8),
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 44, right: 10),
        decoration: BoxDecoration(color: selected ? c.accent.withValues(alpha: 0.12) : null, borderRadius: context.round(8)),
        child: Row(
          children: [
            StateDot(state: s.state, size: 6),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: s.node, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: c.text.withValues(alpha: 0.88))),
                  TextSpan(text: '  $status', style: TextStyle(fontSize: 12, color: needsYou ? c.warning : (s.isBusy ? c.accent : c.muted))),
                  TextSpan(text: '  $detail', style: TextStyle(fontSize: 12, color: c.faint)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.id, required this.label, required this.open, required this.count, required this.onTap});

  final String id, label;
  final bool open;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      key: Key('section-$id'),
      borderRadius: context.round(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 8, 6),
        child: Row(
          children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: c.faint)),
            const SizedBox(width: 6),
            Text('$count', style: TextStyle(fontSize: 11, color: c.faint)),
            const Spacer(),
            Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: c.faint),
          ],
        ),
      ),
    );
  }
}
