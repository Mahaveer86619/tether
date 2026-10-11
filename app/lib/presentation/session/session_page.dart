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
                    padding: MediaQuery.sizeOf(context).width < 600 ? const EdgeInsets.fromLTRB(10, 2, 10, 8) : const EdgeInsets.fromLTRB(16, 4, 16, 12),
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
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final details = [
      session.node,
      if (session.cwd.isNotEmpty) baseName(session.cwd),
      if (!narrow && session.gitBranch.isNotEmpty) session.gitBranch,
      if (!narrow && session.model.isNotEmpty) shortModel(session.model),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(leading == null ? 16 : 0, narrow ? 4 : 10, 4, narrow ? 4 : 10),
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    StateDot(state: session.state),
                    const SizedBox(width: 6),
                    Text(stateLabel(session.state), style: TextStyle(fontSize: 12, color: stateColor(context, session.state))),
                    if (!narrow && hostLabel(session.host).isNotEmpty) ...[const SizedBox(width: 8), Pill(hostLabel(session.host))],
                    Expanded(
                      child: Text('  ·  ${details.join(' · ')}', maxLines: 1, overflow: TextOverflow.ellipsis,
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
          if (!narrow)
            IconButton(
              tooltip: 'Fork: continue in a new session',
              icon: const Icon(Icons.call_split_rounded),
              onPressed: () => startFork(context),
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) async {
              switch (v) {
                case 'fork':
                  startFork(context);
                  return;
                case 'archive':
                  context.read<HubCubit>().setArchived(session.id, archived: !session.archived);
                  showToast(context, session.archived ? 'Moved back to "Pick up"' : 'Marked as done', icon: Icons.done_all_rounded);
                  return;
                case 'end':
                  if (await _confirmEnd(context, session)) bloc.add(const EndRequested());
                  return;
              }
              final text = switch (v) {
                'attach' => session.attachCommand,
                'resume' => 'claude --resume ${session.id}',
                _ => session.id,
              };
              Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) showToast(context, 'Copied to clipboard', icon: Icons.content_copy_rounded);
            },
            itemBuilder: (_) => [
              if (narrow) _menuItem('fork', Icons.call_split_rounded, 'Fork into a new session'),
              _menuItem('archive', session.archived ? Icons.unarchive_outlined : Icons.done_all_rounded,
                  session.archived ? 'Move back to "Pick up"' : 'Mark as done'),
              const PopupMenuDivider(),
              if (session.attachCommand.isNotEmpty) _menuItem('attach', Icons.terminal_rounded, 'Copy tmux attach command'),
              _menuItem('resume', Icons.content_copy_rounded, 'Copy "claude --resume" command'),
              _menuItem('id', Icons.tag_rounded, 'Copy session id'),
              if (session.canEnd) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  key: const Key('end-session'),
                  value: 'end',
                  child: Row(
                    children: [
                      Icon(Icons.power_settings_new_rounded, size: 18, color: context.colors.danger),
                      const SizedBox(width: 12),
                      Text('End session', style: TextStyle(color: context.colors.danger)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) => PopupMenuItem(
        value: value,
        child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 12), Flexible(child: Text(label))]),
      );
}

/// Explains what a fork is, then puts the composer in fork mode.
Future<void> startFork(BuildContext context) async {
  final bloc = context.read<SessionBloc>();
  final c = context.colors;
  final body = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.call_split_rounded, color: c.accent),
          const SizedBox(width: 10),
          const Text('Fork this session', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ],
      ),
      const SizedBox(height: 14),
      for (final (icon, text) in const [
        (Icons.content_copy_rounded, 'A new session starts with a copy of this whole conversation, so Claude remembers everything said so far.'),
        (Icons.lock_outline_rounded, 'This session stays exactly as it is. Nothing you do in the fork changes it.'),
        (Icons.alt_route_rounded, 'Use it to try another approach, or to continue here a session that is open in a terminal.'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: c.muted),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.45))),
            ],
          ),
        ),
    ],
  );
  Widget actions(BuildContext ctx) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const Key('confirm-fork'),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.call_split_rounded, size: 18),
            label: const Text('Fork'),
          ),
        ],
      );
  final ok = isDesktop
      ? await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(content: SizedBox(width: 420, child: body), actions: [actions(ctx)]),
        )
      : await showModalBottomSheet<bool>(
          context: context,
          useSafeArea: true,
          builder: (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [body, const SizedBox(height: 8), actions(ctx)]),
          ),
        );
  if (ok ?? false) bloc.add(const ForkModeChanged(true));
}

class _Timeline extends StatefulWidget {
  const _Timeline({required this.state});

  final SessionViewState state;

  @override
  State<_Timeline> createState() => _TimelineState();
}

/// One row of the chat: a single item, or a run of tool calls folded into
/// an [ActivityGroup].
class _Entry {
  _Entry(this.items);

  final List<TimelineItem> items;

  String get key => items.first.itemId;
  bool get isGroup => items.where((i) => i.whichKind() == TimelineItem_Kind.tool).length > 1;
}

bool _isStep(TimelineItem i) => i.whichKind() == TimelineItem_Kind.tool || i.whichKind() == TimelineItem_Kind.thinking;

List<_Entry> _entries(List<TimelineItem> items) {
  final runs = <_Entry>[];
  List<TimelineItem>? run;
  for (final it in items) {
    if (_isStep(it) && run != null) {
      run.add(it);
    } else {
      run = _isStep(it) ? [it] : null;
      runs.add(_Entry(run ?? [it]));
    }
  }
  // A run with a single tool call reads better as its own card.
  return [
    for (final e in runs)
      if (e.items.length > 1 && !e.isGroup) ...[for (final i in e.items) _Entry([i])] else e,
  ];
}

class _TimelineState extends State<_Timeline> {
  final _scroll = ScrollController();
  bool _awayFromLatest = false;

  /// Rows present when the history finished loading; only rows arriving
  /// after that animate in.
  Set<String>? _initial;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final away = _scroll.hasClients && _scroll.offset > 400;
      if (away != _awayFromLatest) setState(() => _awayFromLatest = away);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final items = s.items;
    final busy = s.session?.isBusy ?? false;
    final approval = s.session?.state == SessionState.awaitingApproval;
    final entries = _entries(items);
    if (_initial == null && (!s.loading || items.isNotEmpty)) {
      _initial = {for (final e in entries) e.key};
    }
    if (items.isEmpty) {
      if (busy) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: contentWidth), child: _Working(waitingForApproval: approval)),
          ),
        );
      }
      return s.loading
          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
          : const EmptyState(icon: Icons.forum_outlined, title: 'No messages yet', body: 'History appears here as the session runs.');
    }
    final last = items.last;
    final streaming = last.whichKind() == TimelineItem_Kind.markdown && last.markdown.streaming;
    final working = busy && !streaming;
    final keyIndex = {for (var i = 0; i < entries.length; i++) entries[i].key: entries.length - i};
    final side = MediaQuery.sizeOf(context).width < 600 ? 14.0 : 16.0;
    return Stack(
      children: [
        // Reversed so the view stays pinned to the newest row. Rows are keyed
        // so a new message doesn't shift every row's state down by one.
        ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: EdgeInsets.fromLTRB(side, 8, side, 12),
          itemCount: entries.length + 1,
          findChildIndexCallback: (key) => key is ValueKey<String> ? keyIndex[key.value] : null,
          itemBuilder: (context, i) {
            final Widget child;
            final Key key;
            if (i == 0) {
              key = const ValueKey('working');
              child = AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: working ? _Working(waitingForApproval: approval) : const SizedBox(width: double.infinity),
              );
            } else {
              final e = entries[entries.length - i];
              key = ValueKey(e.key);
              child = _Appear(
                animate: !(_initial?.contains(e.key) ?? true),
                child: e.isGroup
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ActivityGroup(items: e.items, active: working && i == 1),
                      )
                    : TimelineItemView(item: e.items.first),
              );
            }
            return KeyedSubtree(
              key: key,
              child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: contentWidth), child: child)),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 12,
          child: AnimatedScale(
            scale: _awayFromLatest ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IconButton.filledTonal(
              tooltip: 'Jump to latest',
              onPressed: () => _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic),
              icon: const Icon(Icons.arrow_downward_rounded, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fades a new row in once, rising a few pixels, when it first appears.
class _Appear extends StatefulWidget {
  const _Appear({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: widget.animate ? 0 : 1);
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
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        // A fixed offset: a relative one makes tall messages jump.
        builder: (context, child) => Opacity(
          opacity: _curve.value,
          child: Transform.translate(offset: Offset(0, 10 * (1 - _curve.value)), child: child),
        ),
        child: widget.child,
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
            child: Text('Messages are typed into your terminal on ${session.node}',
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
            onPressed: () => startFork(context),
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
    final compact = !isDesktop;
    final stop = (s.session?.canInterrupt ?? false)
        ? IconButton.outlined(
            tooltip: 'Stop',
            onPressed: () => bloc.add(const InterruptRequested()),
            icon: const Icon(Icons.stop_rounded, size: 18),
            style: IconButton.styleFrom(side: BorderSide(color: c.border)),
          )
        : null;
    final send = IconButton.filled(
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
    );
    final field = CallbackShortcuts(
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
        maxLines: compact ? 6 : 8,
        textInputAction: TextInputAction.newline,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: compact ? 10 : 8),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(compact ? 22 : 18),
        border: Border.all(color: s.forking ? c.accent.withValues(alpha: 0.6) : c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      padding: compact ? const EdgeInsets.fromLTRB(16, 4, 5, 4) : const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.forking)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.call_split_rounded, size: 14, color: c.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('New fork · starts with this conversation; the original stays as it is',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.accent)),
                  ),
                  InkWell(
                    onTap: () => bloc.add(const ForkModeChanged(false)),
                    child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 16, color: c.faint)),
                  ),
                ],
              ),
            ),
          if (compact)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: field),
                if (stop != null) Padding(padding: const EdgeInsets.only(bottom: 2), child: stop),
                Padding(padding: const EdgeInsets.only(left: 4, bottom: 2), child: send),
              ],
            )
          else ...[
            field,
            Row(
              children: [
                Expanded(
                  child: Text('Enter to send · Shift+Enter for a new line', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: c.faint)),
                ),
                if (stop != null) Padding(padding: const EdgeInsets.only(right: 6), child: stop),
                send,
              ],
            ),
          ],
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
            ToolDetail(card: a.preview!)
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
