import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/timeline_item_view.dart';
import '../widgets/todo_checklist.dart';
import '../widgets/tool_card.dart';
import 'session_bloc.dart';

/// Provides a [SessionBloc] for one session and shows it.
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key, required this.sessionId, required this.onOpenSession, this.leading});

  final String sessionId;
  final ValueChanged<String> onOpenSession;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(sessionId),
      create: (_) => sl<SessionBloc>(param1: sessionId)..add(const SessionOpened()),
      child: _SessionBody(onOpenSession: onOpenSession, leading: leading),
    );
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({required this.onOpenSession, this.leading});

  final ValueChanged<String> onOpenSession;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SessionBloc, SessionViewState>(
          listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
          listener: (context, s) => showFailure(context, s.failure!),
        ),
        BlocListener<SessionBloc, SessionViewState>(
          listenWhen: (a, b) => a.forkedTo != b.forkedTo && b.forkedTo != null,
          listener: (context, s) => onOpenSession(s.forkedTo!),
        ),
      ],
      child: BlocBuilder<SessionBloc, SessionViewState>(
        builder: (context, s) {
          final session = s.session;
          if (session == null) {
            return s.timeline == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : const EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'Session not found');
          }
          return Column(
            children: [
              SessionHeader(session: session, leading: leading),
              Expanded(child: _Timeline(state: s)),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: contentWidth + 32),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final a in s.approvals) Padding(padding: const EdgeInsets.only(bottom: 8), child: ApprovalCard(approval: a)),
                        if (session.todos.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: _Progress(session: session)),
                        if (!session.acceptsInput && !s.forking)
                          _TerminalNotice(session: session)
                        else ...[
                          if (session.host == SessionHost.terminal && session.terminalInput && !s.forking)
                            _TypingHint(session: session),
                          Composer(state: s),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SessionHeader extends StatelessWidget {
  const SessionHeader({super.key, required this.session, this.leading});

  final Session session;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bloc = context.read<SessionBloc>();
    final details = [
      session.node,
      if (session.cwd.isNotEmpty) baseName(session.cwd),
      if (session.gitBranch.isNotEmpty) session.gitBranch,
      if (session.model.isNotEmpty) shortModel(session.model),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Row(
        children: [
          ?leading,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    StateDot(state: session.state),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(stateLabel(session.state), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: stateColor(context, session.state))),
                    ),
                    if (hostLabel(session.host).isNotEmpty) ...[const SizedBox(width: 8), Pill(hostLabel(session.host))],
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(details.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.muted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (session.canInterrupt)
            IconButton(
              key: const Key('interrupt'),
              tooltip: 'Interrupt (Esc)',
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: () => bloc.add(const InterruptRequested()),
            ),
          IconButton(
            tooltip: 'Fork and continue',
            icon: const Icon(Icons.call_split_rounded),
            onPressed: () => bloc.add(const ForkModeChanged(true)),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (v) async {
              if (v == 'end') {
                if (await _confirmEnd(context, session)) bloc.add(const EndRequested());
                return;
              }
              final text = switch (v) {
                'attach' => session.attachCommand,
                'resume' => 'claude --resume ${session.id}',
                _ => session.id,
              };
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $text'), duration: const Duration(seconds: 2)));
            },
            itemBuilder: (_) => [
              if (session.attachCommand.isNotEmpty) const PopupMenuItem(value: 'attach', child: Text('Copy tmux attach command')),
              const PopupMenuItem(value: 'resume', child: Text('Copy "claude --resume" command')),
              const PopupMenuItem(value: 'id', child: Text('Copy session id')),
              if (session.canEnd) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  key: const Key('end-session'),
                  value: 'end',
                  child: Text('End session', style: TextStyle(color: context.colors.danger)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatefulWidget {
  const _Timeline({required this.state});

  final SessionViewState state;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  /// Items present when the history finished loading; only items arriving
  /// after that animate in.
  Set<String>? _initial;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final items = s.items;
    if (_initial == null && (!s.loading || items.isNotEmpty)) {
      _initial = {for (final i in items) i.itemId};
    }
    if (items.isEmpty) {
      if (s.session?.isBusy ?? false) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: contentWidth),
              child: _Working(waitingForApproval: s.session?.state == SessionState.awaitingApproval),
            ),
          ),
        );
      }
      return s.loading
          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
          : const EmptyState(icon: Icons.forum_outlined, title: 'No messages yet', body: 'History appears here as the session runs.');
    }
    final last = items.last;
    final streaming = last.whichKind() == TimelineItem_Kind.markdown && last.markdown.streaming;
    final working = (s.session?.isBusy ?? false) && !streaming;
    final extra = working ? 1 : 0;
    // Reversed so the view stays pinned to the newest item.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length + extra,
      itemBuilder: (context, i) {
        final Widget child;
        if (i < extra) {
          child = _Working(waitingForApproval: s.session?.state == SessionState.awaitingApproval);
        } else {
          final item = items[items.length - 1 - (i - extra)];
          child = _Appear(
            key: ValueKey(item.itemId),
            animate: !(_initial?.contains(item.itemId) ?? true),
            child: TimelineItemView(item: item),
          );
        }
        return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: contentWidth), child: child));
      },
    );
  }
}

/// Fades and slides a new message in once, when it first appears.
class _Appear extends StatefulWidget {
  const _Appear({super.key, required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: widget.animate ? 0 : 1);
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(_curve),
          child: widget.child,
        ),
      );
}

/// Shown at the end of the chat while Claude works between messages.
class _Working extends StatefulWidget {
  const _Working({required this.waitingForApproval});

  final bool waitingForApproval;

  @override
  State<_Working> createState() => _WorkingState();
}

class _WorkingState extends State<_Working> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent.withValues(alpha: 0.25 + 0.75 * _pulse((_c.value - i * 0.18) % 1)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(widget.waitingForApproval ? 'Waiting for your approval' : 'Claude is working',
              style: TextStyle(fontSize: 12.5, color: c.muted)),
        ],
      ),
    );
  }

  static double _pulse(double t) => t < 0.5 ? t * 2 : (1 - t) * 2;
}

Future<bool> _confirmEnd(BuildContext context, Session session) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this session?'),
        content: Text(
          session.host == SessionHost.tmux
              ? 'Claude Code exits and its tmux window on ${session.node} closes. The history stays, and you can resume it later.'
              : 'The Claude Code process on ${session.node} stops. The history stays, and you can resume it later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('confirm-end'),
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End session'),
          ),
        ],
      ),
    ) ??
    false;

class _TypingHint extends StatelessWidget {
  const _TypingHint({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 6),
      child: Row(
        children: [
          Icon(Icons.keyboard_outlined, size: 14, color: c.info),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Open in your terminal on ${session.node} · messages are typed there',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatefulWidget {
  const _Progress({required this.session});

  final Session session;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.session;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 16, color: c.muted),
                  const SizedBox(width: 8),
                  Text('${s.todosDone} of ${s.todos.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.currentTodo?.label ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: c.muted)),
                  ),
                  SizedBox(
                    width: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: s.todosDone / s.todos.length, minHeight: 4, backgroundColor: c.raised, color: c.accent),
                    ),
                  ),
                  Icon(_open ? Icons.expand_more_rounded : Icons.expand_less_rounded, size: 18, color: c.faint),
                ],
              ),
            ),
          ),
          if (_open) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: TodoChecklist(todos: s.todos)),
        ],
      ),
    );
  }
}

class _TerminalNotice extends StatelessWidget {
  const _TerminalNotice({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.terminal_rounded, size: 18, color: c.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Open in a terminal on ${session.node}. You can watch it and answer its approvals here; fork it to continue from this app.',
              style: TextStyle(fontSize: 13, color: c.muted),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => context.read<SessionBloc>().add(const ForkModeChanged(true)),
            icon: const Icon(Icons.call_split_rounded, size: 16),
            label: const Text('Fork'),
          ),
        ],
      ),
    );
  }
}

/// The message box at the bottom of a session.
class Composer extends StatefulWidget {
  const Composer({super.key, required this.state});

  final SessionViewState state;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    if (old.state.sentId != widget.state.sentId) _text.clear();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final s = widget.state;
    if (!s.canType || s.sending || _text.text.trim().isEmpty) return;
    context.read<SessionBloc>().add(MessageSubmitted(_text.text));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.state;
    final bloc = context.read<SessionBloc>();
    final hint = !s.nodeOnline
        ? '${s.session?.node ?? 'Device'} is offline'
        : (s.forking ? 'First message of the new fork…' : 'Reply to Claude…');
    final canSubmit = s.canType && !s.sending && _text.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: s.forking ? c.accent.withValues(alpha: 0.6) : c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.forking)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.call_split_rounded, size: 14, color: c.accent),
                  const SizedBox(width: 6),
                  Text('Forking into a new session', style: TextStyle(fontSize: 12, color: c.accent)),
                  const Spacer(),
                  InkWell(
                    onTap: () => bloc.add(const ForkModeChanged(false)),
                    child: Icon(Icons.close_rounded, size: 16, color: c.faint),
                  ),
                ],
              ),
            ),
          CallbackShortcuts(
            bindings: {
              if (isDesktop) const SingleActivator(LogicalKeyboardKey.enter): _submit,
              if (s.session?.canInterrupt ?? false) const SingleActivator(LogicalKeyboardKey.escape): () => bloc.add(const InterruptRequested()),
            },
            child: TextField(
              key: const Key('composer'),
              controller: _text,
              enabled: s.canType,
              autofocus: s.forking,
              minLines: 1,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: hint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: isDesktop
                    ? Text('Enter to send · Shift+Enter for a new line', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.faint))
                    : const SizedBox.shrink(),
              ),
              if (s.session?.canInterrupt ?? false)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton.outlined(
                    tooltip: 'Stop',
                    onPressed: () => bloc.add(const InterruptRequested()),
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    style: IconButton.styleFrom(side: BorderSide(color: c.border)),
                  ),
                ),
              IconButton.filled(
                key: const Key('send'),
                tooltip: 'Send',
                onPressed: canSubmit ? _submit : null,
                style: IconButton.styleFrom(
                  backgroundColor: c.accent,
                  disabledBackgroundColor: c.raised,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: s.sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_upward_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A pending permission prompt or folder-trust question, answered through
/// the app-wide [HubCubit].
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({super.key, required this.approval, this.sessionTitle});

  final Approval approval;
  final String? sessionTitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = approval;
    final trust = a.kind == ApprovalKind.folderTrust;
    final busy = context.select<HubCubit, bool>((cubit) => cubit.state.deciding.contains(a.id));
    void decide(bool allow) => context.read<HubCubit>().decide(a.id, allow: allow);
    return Container(
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
              Icon(trust ? Icons.folder_open_rounded : Icons.shield_outlined, size: 18, color: c.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(trust ? 'Trust this folder?' : 'Allow ${a.toolName}?', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              Text(a.node, style: TextStyle(fontSize: 12, color: c.faint)),
            ],
          ),
          if (sessionTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(sessionTitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
            ),
          const SizedBox(height: 8),
          if (!trust && a.preview != null)
            ConstrainedBox(constraints: const BoxConstraints(maxHeight: 260), child: SingleChildScrollView(child: ToolDetail(card: a.preview!)))
          else
            Text(a.description, style: TextStyle(fontSize: 13, color: c.muted)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: busy ? null : () => decide(false), child: Text(trust ? "Don't trust" : 'Deny')),
              const SizedBox(width: 8),
              FilledButton(onPressed: busy ? null : () => decide(true), child: Text(trust ? 'Trust folder' : 'Allow')),
            ],
          ),
        ],
      ),
    );
  }
}
