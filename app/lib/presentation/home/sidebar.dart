import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../chats/chats_page.dart';
import '../hub/hub_cubit.dart';
import '../nav/nav_cubit.dart';
import '../theme/theme.dart';

/// The places that aren't a chat, as icons under the New chat button.
const _tools = <({Destination d, IconData icon, String label})>[
  (d: Destination.devices, icon: Icons.devices_outlined, label: 'Devices'),
  (d: Destination.activity, icon: Icons.history_rounded, label: 'History'),
  (d: Destination.files, icon: Icons.folder_open_outlined, label: 'Files'),
  (d: Destination.routines, icon: Icons.auto_awesome_outlined, label: 'Routines'),
  (d: Destination.usage, icon: Icons.insights_outlined, label: 'Usage'),
];

/// How many chats the sidebar lists before sending you to the full list.
const _recentShown = 25;

/// What the side panel holds, on a phone's drawer and a wide window's
/// sidebar alike: a new chat, the places, the projects chats continue in, and
/// every chat. One-off chats are only in the last.
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
  bool _chatsOpen = true;

  /// Projects the user opened or closed; the rest open when they hold the chat on screen.
  final _open = <String, bool>{};

  void _go(VoidCallback f) {
    f();
    widget.onNavigate?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final s = context.watch<NavCubit>().state;
    final hub = context.select<HubCubit, HubSnapshot>((h) => h.state.hub);
    final selected = s.selectedChat.isNotEmpty ? s.selectedChat : s.selectedSession;
    final projects = hub.chatsSupported ? hub.chatProjects() : const <ChatProject>[];
    final recent = hub.chatsSupported ? hub.recentChats : const <Chat>[];
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
                    IconButton(
                      key: Key('nav-${t.d.name}'),
                      tooltip: t.label,
                      icon: Icon(t.icon, size: 20),
                      color: s.top == null && s.destination == t.d || t.d == Destination.devices && s.top is NodeEntry ? c.accent : c.muted,
                      onPressed: () => _go(() => nav.select(t.d)),
                    ),
                ],
              ),
            ),
            Divider(height: 8, color: c.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                children: [
                  if (projects.isNotEmpty) ...[
                    _Header(label: 'Projects', open: _projectsOpen, count: projects.length, onTap: () => setState(() => _projectsOpen = !_projectsOpen)),
                    if (_projectsOpen)
                      for (final p in projects) ..._project(context, p, projects, selected),
                  ],
                  _Header(label: 'Chats', open: _chatsOpen, count: recent.length, onTap: () => setState(() => _chatsOpen = !_chatsOpen)),
                  if (_chatsOpen) ...[
                    if (recent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                        child: Text('Chats you start show up here.', style: TextStyle(color: c.faint, fontSize: 12.5)),
                      ),
                    for (final chat in recent.take(_recentShown))
                      ChatRow(chat: chat, selected: chat.id == selected, onTap: () => _go(() => nav.openChat(chat.id, replace: true))),
                    if (recent.length > _recentShown)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(key: const Key('all-chats'), onPressed: () => _go(() => nav.select(Destination.chats)), child: Text('All ${recent.length} chats')),
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

  List<Widget> _project(BuildContext context, ChatProject p, List<ChatProject> all, String selected) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final open = _open[p.key] ?? p.chats.any((x) => x.id == selected);
    return [
      Material(
        color: Colors.transparent,
        borderRadius: context.round(8),
        child: InkWell(
          key: Key('project-${p.key}'),
          borderRadius: context.round(8),
          onTap: () => setState(() => _open[p.key] = !open),
          child: SizedBox(
            height: 38,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(open ? Icons.folder_open_outlined : Icons.folder_outlined, size: 18, color: c.accent),
                const SizedBox(width: 10),
                Expanded(child: Text(p.labelAmong(all), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                Text('${p.chats.length}', style: TextStyle(fontSize: 12, color: c.faint)),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
      if (open)
        for (final chat in p.chats) ChatRow(keyPrefix: 'project-chat', chat: chat, indent: 18, selected: chat.id == selected, onTap: () => _go(() => nav.openChat(chat.id, replace: true))),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.label, required this.open, required this.count, required this.onTap});

  final String label;
  final bool open;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      key: Key('section-${label.toLowerCase()}'),
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
