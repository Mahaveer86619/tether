import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../nav/nav_cubit.dart';
import '../session/session_page.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/prompt_box.dart';
import '../widgets/timeline_item_view.dart';
import 'chat_tasks.dart';
import 'chats_cubit.dart';
import 'chats_page.dart';
import 'target_picker.dart';

/// A chat: its active session's conversation under the chat's own title,
/// with where it runs and the sessions linked to it.
class ChatPage extends StatelessWidget {
  const ChatPage({super.key, required this.chatId, this.leading});

  final String chatId;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final (chat, hasSession, connected) = context.select<HubCubit, (Chat?, bool, bool)>((h) {
      final c = h.state.hub.chats[chatId];
      return (c, c != null && h.state.hub.sessions.containsKey(c.activeSession), h.state.hub.connected);
    });
    if (chat == null) {
      return Column(
        children: [
          if (leading != null) Align(alignment: Alignment.centerLeft, child: leading!),
          Expanded(
            child: connected
                ? const EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'Chat not found')
                : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      );
    }
    final nav = context.read<NavCubit>();
    final title = ChatTitle(chat: chat);
    final bar = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [ChatTargetBar(chat: chat), ChatTasks(chat: chat)]);
    if (!hasSession) return _NoSession(chat: chat, leading: leading, title: title, bar: bar);
    return SessionScreen(
      key: ValueKey(chat.activeSession),
      sessionId: chat.activeSession,
      leading: leading,
      title: title,
      subtitle: bar,
      // A fork made here isn't linked yet: the hub makes it the active
      // session and this screen follows. Other sessions open on their own.
      onOpenSession: (id) {
        if (id != chat.activeSession && chat.links.any((l) => l.session == id)) nav.push(SessionEntry(id));
      },
    );
  }
}

/// The chat's title, renamed in place: tap it, type, Enter.
class ChatTitle extends StatefulWidget {
  const ChatTitle({super.key, required this.chat});

  final Chat chat;

  @override
  State<ChatTitle> createState() => _ChatTitleState();
}

class _ChatTitleState extends State<ChatTitle> {
  bool _editing = false;
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _save();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _edit() {
    _text.text = widget.chat.title;
    _text.selection = TextSelection(baseOffset: 0, extentOffset: _text.text.length);
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _save() {
    final title = _text.text.trim();
    setState(() => _editing = false);
    if (title != widget.chat.title.trim()) context.read<ChatsCubit>().rename(widget.chat.id, title);
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    if (_editing) {
      return SizedBox(
        height: 24,
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => setState(() => _editing = false)},
          child: TextField(
            key: const Key('chat-title-field'),
            controller: _text,
            focusNode: _focus,
            style: style,
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero, filled: false),
            onSubmitted: (_) => _save(),
          ),
        ),
      );
    }
    return InkWell(
      key: const Key('chat-title'),
      borderRadius: BorderRadius.circular(4),
      onTap: _edit,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(widget.chat.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          const SizedBox(width: 4),
          Icon(Icons.edit_outlined, size: 13, color: context.colors.faint),
        ],
      ),
    );
  }
}

/// Where the chat works, why, a way to change it, and its linked sessions.
class ChatTargetBar extends StatelessWidget {
  const ChatTargetBar({super.key, required this.chat});

  final Chat chat;

  Future<void> _change(BuildContext context) async {
    final cubit = context.read<ChatsCubit>();
    final choice = await showTargetPicker(context, current: chat.target, forChat: true);
    final target = choice?.target;
    if (target == null) return;
    await cubit.retarget(chat.id, target, move: choice!.move);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = chat.target;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final busy = context.select<ChatsCubit, bool>((x) => x.state.busy.contains(chat.id));
    return Container(
      padding: EdgeInsets.fromLTRB(narrow ? 12 : 16, 6, 8, 6),
      decoration: BoxDecoration(
        color: t.detecting ? c.accent.withValues(alpha: 0.07) : null,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(targetIcon(t), size: 15, color: t.detecting ? c.accent : c.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: t.detecting ? 'Claude is working out where this belongs' : targetLabel(t), style: TextStyle(color: c.text)),
                if (!t.detecting && t.reason.isNotEmpty) TextSpan(text: '  ·  ${t.reason}', style: TextStyle(color: c.muted)),
              ]),
              key: const Key('chat-target'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          if (busy) const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
          TextButton(
            key: const Key('change-target'),
            onPressed: busy ? null : () => _change(context),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text(t.detecting ? 'Choose myself' : 'Change'),
          ),
          if (chat.links.length > 1) _LinkedSessions(chat: chat),
          ChatMenu(chat: chat, icon: Icons.more_horiz_rounded),
        ],
      ),
    );
  }
}

const _roleLabels = {
  'main': 'Started the chat',
  'moved': 'Carried on here',
  'fork': 'Forked',
  'started': 'Started by Claude',
  'linked': 'Linked',
};

class _LinkedSessions extends StatelessWidget {
  const _LinkedSessions({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.select<HubCubit, Map<String, Session>>((h) => h.state.hub.sessions);
    final nav = context.read<NavCubit>();
    return PopupMenuButton<String>(
      key: const Key('linked-sessions'),
      tooltip: 'Sessions in this chat',
      onSelected: (id) => nav.push(SessionEntry(id)),
      itemBuilder: (_) => [
        for (final l in chat.links.reversed)
          PopupMenuItem(
            value: l.session,
            enabled: sessions.containsKey(l.session),
            child: _LinkRow(link: l, session: sessions[l.session], active: l.session == chat.activeSession),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Pill('${chat.links.length} sessions', color: c.accent),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.session, required this.active});

  final ChatLink link;
  final Session? session;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    return SizedBox(
      width: 300,
      child: Row(
        children: [
          if (s != null) StateDot(state: s.state, size: 7) else Icon(Icons.remove_circle_outline_rounded, size: 12, color: c.faint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s?.displayTitle ?? 'A session no longer here', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                Text(
                  [_roleLabels[link.role] ?? link.role, if (s != null) '${s.node} · ${s.cwd.isEmpty ? 'home folder' : baseName(s.cwd)}', if (active) 'active'].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A chat whose session is gone: the next message starts a new one at the
/// chat's target, carrying what was said.
class _NoSession extends StatefulWidget {
  const _NoSession({required this.chat, required this.title, required this.bar, this.leading});

  final Chat chat;
  final Widget title, bar;
  final Widget? leading;

  @override
  State<_NoSession> createState() => _NoSessionState();
}

class _NoSessionState extends State<_NoSession> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_text.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await context.read<ChatsCubit>().send(widget.chat.id, _text.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(widget.leading == null ? 16 : 0, 10, 8, 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
          child: Row(children: [?widget.leading, Expanded(child: widget.title)]),
        ),
        widget.bar,
        Expanded(
          child: EmptyState(
            icon: Icons.history_toggle_off_rounded,
            title: 'This chat has no session right now',
            body: 'Its last one has been cleaned up. Write to carry on: a new session starts at ${targetLabel(widget.chat.target)} with the conversation so far.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: contentWidth + 32),
            child: PromptBox(
              controller: _text,
              fieldKey: const Key('chat-composer'),
              hint: 'Carry on…',
              onSubmit: _send,
              actions: [
                PromptButton(tooltip: 'Send', icon: Icons.arrow_upward_rounded, filled: true, busy: _sending, onPressed: _send),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
