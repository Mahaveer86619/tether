import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../home/cards.dart';
import '../hub/hub_cubit.dart';
import '../nav/nav_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'chats_cubit.dart';

/// Where a chat runs, in a few words.
String targetLabel(ChatTarget t) {
  if (t.detecting) return 'Finding the right folder…';
  if (t.scratch) return 'Hub · scratch';
  if (t.node.isEmpty) return 'Anywhere';
  return '${t.node} · ${t.cwd.isEmpty ? 'home folder' : baseName(t.cwd)}';
}

IconData targetIcon(ChatTarget t) => t.detecting
    ? Icons.travel_explore_rounded
    : t.scratch
        ? Icons.hub_outlined
        : Icons.folder_outlined;

/// One entry in the history: a chat, or on a hub without chats, a session.
class _Entry {
  _Entry.chat(Chat this.chat, this.updated)
      : session = null,
        id = chat.id;
  _Entry.session(Session this.session)
      : chat = null,
        id = session.id,
        updated = session.updated;

  final Chat? chat;
  final Session? session;
  final String id;
  final DateTime? updated;
}

/// The history: start a chat, find one, pick up where you left off.
class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key, this.header});

  /// Shown above the search box: the start-a-chat box on the home screen.
  final Widget? header;

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  String _query = '';
  bool _archived = false;

  bool _found(_Entry e) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final fields = e.chat != null
        ? [e.chat!.title, e.chat!.target.node, e.chat!.target.cwd]
        : [e.session!.title, e.session!.lastPrompt, e.session!.cwd, e.session!.node];
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final entries = _historyOf(hub, archived: _archived).where(_found).toList();
    final groups = <String, List<_Entry>>{};
    for (final e in entries) {
      groups.putIfAbsent(_period(e.updated), () => []).add(e);
    }
    final archivedCount = hub.chats.values.where((c) => c.archived).length;
    return PageColumn(
      bottom: 96,
      children: [
        ?widget.header,
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('chat-search'),
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded, size: 20), hintText: 'Search chats', isDense: true),
              ),
            ),
            if (archivedCount > 0) ...[
              const SizedBox(width: 8),
              FilterChip(
                key: const Key('show-archived'),
                label: Text('Archived $archivedCount'),
                selected: _archived,
                visualDensity: VisualDensity.compact,
                onSelected: (v) => setState(() => _archived = v),
              ),
            ],
          ],
        ),
        if (!hub.chatsSupported && hub.connected)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('This hub is older than 0.16, so it keeps sessions rather than chats. They are listed here instead.',
                style: TextStyle(color: c.muted, fontSize: 12.5)),
          ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: _query.isNotEmpty ? 'No chats match "$_query"' : (_archived ? 'No archived chats' : 'No chats yet'),
              body: _query.isNotEmpty || _archived ? null : 'Start one and Claude picks up the work on the right machine and folder.',
              action: _query.isNotEmpty || _archived
                  ? null
                  : FilledButton.icon(onPressed: () => nav.newChat(), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New chat')),
            ),
          )
        else
          for (final MapEntry(key: period, value: list) in groups.entries) ...[
            SectionLabel(period),
            Material(
              color: c.surface,
              shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, e) in list.indexed) ...[
                    if (i > 0) Divider(height: 1, color: c.border),
                    e.chat != null
                        ? ChatTile(chat: e.chat!, onTap: () => nav.openChat(e.id))
                        : _SessionRow(session: e.session!, onTap: () => nav.push(SessionEntry(e.id))),
                  ],
                ],
              ),
            ),
          ],
      ],
    );
  }
}

/// What the history lists, newest first: chats, or sessions on a hub that
/// doesn't keep chats.
List<_Entry> _historyOf(HubSnapshot hub, {bool archived = false}) {
  if (!hub.chatsSupported) {
    return [for (final s in hub.sessions.values) if (s.archived == archived && !s.isLive || !archived && s.isLive) _Entry.session(s)]
      ..sort((a, b) => (b.updated ?? DateTime(0)).compareTo(a.updated ?? DateTime(0)));
  }
  return [for (final c in hub.chats.values) if (c.archived == archived) _Entry.chat(c, hub.chatUpdated(c))]
    ..sort((a, b) => (b.updated ?? DateTime(0)).compareTo(a.updated ?? DateTime(0)));
}

String _period(DateTime? t, {DateTime? now}) {
  if (t == null) return 'Older';
  final n = now ?? DateTime.now();
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return 'Previous 7 days';
  if (days < 30) return 'Previous 30 days';
  return 'Older';
}

/// A chat in the history: title, where it runs, what it's doing.
class ChatTile extends StatelessWidget {
  const ChatTile({super.key, required this.chat, required this.onTap});

  final Chat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (session, updated) = context.select<HubCubit, (Session?, DateTime?)>(
      (h) => (h.state.hub.sessions[chat.activeSession], h.state.hub.chatUpdated(chat)),
    );
    final extra = chat.links.length - 1;
    return InkWell(
      key: Key('chat-${chat.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: session != null && session.isLive ? StateDot(state: session.state, size: 8) : Icon(Icons.chat_bubble_outline_rounded, size: 16, color: c.faint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chat.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(targetIcon(chat.target), size: 13, color: chat.target.detecting ? c.accent : c.faint),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          [
                            targetLabel(chat.target),
                            if (session != null && session.isLive) stateLabel(session.state),
                            if (extra > 0) '$extra linked',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(ago(updated), style: TextStyle(fontSize: 11.5, color: c.faint)),
            ChatMenu(chat: chat),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            SizedBox(width: 18, child: StateDot(state: session.state, size: 8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(session.scratch ? 'Hub · scratch' : '${session.node} · ${session.cwd.isEmpty ? 'home folder' : baseName(session.cwd)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
                ],
              ),
            ),
            Text(ago(session.updated), style: TextStyle(fontSize: 11.5, color: c.faint)),
          ],
        ),
      ),
    );
  }
}

/// Rename, archive and copy for a chat.
class ChatMenu extends StatelessWidget {
  const ChatMenu({super.key, required this.chat, this.icon = Icons.more_horiz_rounded});

  final Chat chat;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChatsCubit>();
    return PopupMenuButton<String>(
      key: Key('chat-menu-${chat.id}'),
      tooltip: 'Chat options',
      icon: Icon(icon, size: 18, color: context.colors.muted),
      onSelected: (v) async {
        switch (v) {
          case 'rename':
            final title = await showRenameChat(context, chat);
            if (title != null) await cubit.rename(chat.id, title);
          case 'archive':
            await cubit.archive(chat.id, archived: !chat.archived);
          case 'copy':
            final text = await cubit.transcript(chat.id);
            if (text != null) {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) showToast(context, 'Conversation copied', icon: Icons.content_copy_rounded);
            }
        }
      },
      itemBuilder: (_) => [
        _item('rename', Icons.edit_outlined, 'Rename'),
        _item('copy', Icons.content_copy_rounded, 'Copy conversation'),
        _item('archive', chat.archived ? Icons.unarchive_outlined : Icons.archive_outlined, chat.archived ? 'Restore' : 'Archive'),
      ],
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label) => PopupMenuItem(
        value: value,
        child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 12), Flexible(child: Text(label))]),
      );
}

/// Asks for a chat's new title. An empty one hands naming back to Tether.
Future<String?> showRenameChat(BuildContext context, Chat chat) => showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(chat: chat),
    );

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.chat});

  final Chat chat;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _title = TextEditingController(text: widget.chat.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Rename chat'),
        content: SizedBox(
          width: 380,
          child: TextField(
            key: const Key('rename-chat'),
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Leave empty to name it from the conversation'),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(key: const Key('save-chat-title'), onPressed: () => Navigator.pop(context, _title.text), child: const Text('Save')),
        ],
      );
}

/// The sidebar's recents: chats as single lines, the open one highlighted.
class RecentChats extends StatelessWidget {
  const RecentChats({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final selected = context.select<NavCubit, String>((n) => n.state.selectedChat.isNotEmpty ? n.state.selectedChat : n.state.selectedSession);
    final nav = context.read<NavCubit>();
    final c = context.colors;
    final entries = _historyOf(hub).take(40).toList();
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
        child: Text('Chats you start show up here.', style: TextStyle(color: c.faint, fontSize: 12.5)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      children: [
        for (final e in entries)
          _RecentRow(
            key: Key('recent-${e.id}'),
            title: e.chat?.displayTitle ?? e.session!.displayTitle,
            live: (e.chat != null ? hub.sessions[e.chat!.activeSession] : e.session)?.isLive ?? false,
            state: (e.chat != null ? hub.sessions[e.chat!.activeSession] : e.session)?.state,
            selected: e.id == selected,
            menu: e.chat == null ? null : ChatMenu(chat: e.chat!),
            onTap: () => e.chat != null ? nav.openChat(e.id, replace: true) : nav.show(SessionEntry(e.id)),
          ),
      ],
    );
  }
}

class _RecentRow extends StatefulWidget {
  const _RecentRow({super.key, required this.title, required this.live, required this.selected, required this.onTap, this.state, this.menu});

  final String title;
  final bool live, selected;
  final SessionState? state;
  final Widget? menu;
  final VoidCallback onTap;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: widget.selected ? c.accent.withValues(alpha: 0.12) : (_hover ? c.raised : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 10),
                if (widget.live && widget.state != null) ...[StateDot(state: widget.state!, size: 6), const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: widget.selected ? c.text : c.text.withValues(alpha: 0.85), fontWeight: widget.selected ? FontWeight.w600 : null),
                  ),
                ),
                if (widget.menu != null && (_hover || widget.selected)) SizedBox(width: 32, child: widget.menu) else const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
