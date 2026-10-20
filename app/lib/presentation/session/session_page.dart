import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import '../../injection.dart';
import '../artifacts/attachments.dart';
import '../artifacts/files_page.dart';
import '../artifacts/pages_view.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/prompt_box.dart';
import '../widgets/timeline_item_view.dart';
import '../widgets/todo_checklist.dart';
import '../widgets/tool_card.dart';
import 'mode_picker.dart';
import 'prompt_card.dart';
import 'question_card.dart';
import 'terminal_sheet.dart';
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
              SessionHeader(session: session, leading: leading, onOpenSession: onOpenSession),
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
                        if (session.state == SessionState.awaitingApproval && s.approvals.isEmpty && session.hasScreen)
                          StuckBanner(sessionId: session.id),
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
  const SessionHeader({super.key, required this.session, this.leading, this.onOpenSession});

  final Session session;
  final Widget? leading;
  final ValueChanged<String>? onOpenSession;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bloc = context.read<SessionBloc>();
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final (parent, forks) = context.select<HubCubit, (Session?, List<Session>)>(
      (h) => (h.state.hub.sessions[session.parent], h.state.hub.childrenOf(session.id)),
    );
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
                if (session.isFork)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: InkWell(
                      key: const Key('forked-from'),
                      borderRadius: BorderRadius.circular(4),
                      onTap: parent == null || onOpenSession == null ? null : () => onOpenSession!(parent.id),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call_split_rounded, size: 13, color: c.accent),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Forked from ${parent?.displayTitle ?? 'a session no longer here'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: c.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ModeChip(session: session)),
          if (forks.isNotEmpty && onOpenSession != null)
            PopupMenuButton<String>(
              key: const Key('forks'),
              tooltip: 'Forks of this session',
              onSelected: onOpenSession,
              itemBuilder: (_) => [
                for (final f in forks)
                  PopupMenuItem(
                    value: f.id,
                    child: Row(
                      children: [
                        StateDot(state: f.state, size: 7),
                        const SizedBox(width: 10),
                        Flexible(child: Text(f.displayTitle, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Pill('${forks.length} ${forks.length == 1 ? 'fork' : 'forks'}', color: c.accent),
              ),
            ),
          if (session.canInterrupt)
            BlocSelector<SessionBloc, SessionViewState, bool>(
              selector: (s) => s.interrupting,
              builder: (context, interrupting) => IconButton(
                key: const Key('interrupt'),
                tooltip: interrupting ? 'Stopping…' : 'Interrupt (Esc)',
                icon: interrupting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.stop_circle_outlined),
                onPressed: interrupting ? null : () => bloc.add(const InterruptRequested()),
              ),
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
                case 'global':
                  bloc.add(GlobalToggled(!session.global));
                  showToast(context, session.global ? 'The hub stops keeping a copy' : 'The hub keeps a copy after every turn',
                      icon: Icons.cloud_done_outlined);
                  return;
                case 'continue':
                  final text = await showDialog<String>(context: context, builder: (_) => const _ContinueDialog());
                  if (text != null && text.trim().isNotEmpty) bloc.add(ContinueOnHubRequested(text.trim()));
                  return;
                case 'pages':
                  await showSessionPages(context, session.id);
                  return;
                case 'attach-files':
                  await attachToSession(context, session.id);
                  return;
                case 'terminal':
                  await showTerminalSheet(context, session.id);
                  return;
                case 'files':
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text('Files · ${session.displayTitle}', overflow: TextOverflow.ellipsis)),
                      body: FilesPage(session: session.id),
                    ),
                  ));
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
              _menuItem('global', session.global ? Icons.cloud_off_outlined : Icons.cloud_upload_outlined,
                  session.global ? 'Stop keeping a copy on the hub' : 'Keep a copy on the hub'),
              if (session.global) _menuItem('continue', Icons.cloud_sync_outlined, 'Continue on the hub'),
              if (session.hasScreen) _menuItem('terminal', Icons.terminal_rounded, 'Screen & keys'),
              _menuItem('attach-files', Icons.attach_file_rounded, 'Attach files to this session'),
              _menuItem('files', Icons.folder_open_rounded, "This session's files"),
              _menuItem('pages', Icons.web_rounded, 'Pages this session made'),
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
  String _selected = '';

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
    // Items sent again without a kind were removed; queued messages stay at
    // the end, as in the terminal, until Claude takes them in.
    final shown = s.items.where((i) => i.whichKind() != TimelineItem_Kind.notSet);
    final queued = shown.where((i) => i.whichKind() == TimelineItem_Kind.user && i.user.queued).toList();
    final items = shown.where((i) => !(i.whichKind() == TimelineItem_Kind.user && i.user.queued)).toList();
    final busy = s.session?.isBusy ?? false;
    final approval = s.session?.state == SessionState.awaitingApproval;
    final entries = [..._entries(items), for (final q in queued) _Entry([q])];
    // The hub's own "queued" item stands for a message once it has one.
    final outbox = [
      for (final o in s.outbox)
        if (o.state != OutboxState.sent || !Outbox.queuedOnHub(o, s.items)) o,
    ];
    if (_initial == null && (!s.loading || items.isNotEmpty)) {
      _initial = {for (final e in entries) e.key};
    }
    if (entries.isEmpty && outbox.isEmpty) {
      if (busy) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: contentWidth),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Working(waitingForApproval: approval, stopping: s.interrupting),
                if (s.interruptSlow && s.session != null) _StillWorking(session: s.session!),
              ]),
            ),
          ),
        );
      }
      return s.loading
          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
          : const EmptyState(icon: Icons.forum_outlined, title: 'No messages yet', body: 'History appears here as the session runs.');
    }
    final last = items.lastOrNull;
    final streaming = last != null && last.whichKind() == TimelineItem_Kind.markdown && last.markdown.streaming;
    final working = busy && !streaming;
    final keyIndex = {for (var i = 0; i < entries.length; i++) entries[i].key: entries.length - i};
    final side = MediaQuery.sizeOf(context).width < 600 ? 14.0 : 16.0;
    return Stack(
      children: [
        SelectionArea(
          onSelectionChanged: (content) => _selected = content?.plainText ?? '',
          contextMenuBuilder: (context, area) => AdaptiveTextSelectionToolbar.buttonItems(
            anchors: area.contextMenuAnchors,
            buttonItems: [
              ...area.contextMenuButtonItems,
              if (s.canType)
                ContextMenuButtonItem(
                  label: 'Quote',
                  onPressed: () {
                    context.read<SessionBloc>().add(QuoteRequested(_selected));
                    area.clearSelection();
                    ContextMenuController.removeAny();
                  },
                ),
            ],
          ),
          // Reversed so the view stays pinned to the newest row. Rows are keyed
          // so a new message doesn't shift every row's state down by one.
          child: ListView.builder(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final o in outbox) _OutboxBubble(key: ValueKey('outbox-${o.id}'), entry: o),
                    working ? _Working(waitingForApproval: approval, stopping: s.interrupting) : const SizedBox(width: double.infinity),
                    if (s.interruptSlow && s.session != null) _StillWorking(session: s.session!),
                  ],
                ),
              );
            } else {
              final e = entries[entries.length - i];
              key = ValueKey(e.key);
              final splitHere = s.session?.forkPoint.isNotEmpty == true && e.items.any((i) => i.itemId == s.session!.forkPoint);
              child = _Appear(
                animate: !(_initial?.contains(e.key) ?? true),
                child: splitHere
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          e.isGroup ? ActivityGroup(items: e.items) : TimelineItemView(item: e.items.first),
                          const _ForkMarker(),
                        ],
                      )
                    : e.isGroup
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

/// A message from this device the timeline doesn't show yet: on its way,
/// waiting in Claude Code's queue, or not sent, with Retry.
class _OutboxBubble extends StatelessWidget {
  const _OutboxBubble({super.key, required this.entry});

  final OutboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = entry;
    final bloc = context.read<SessionBloc>();
    final unconfirmed = e.unconfirmed(DateTime.now());
    final failed = e.state == OutboxState.failed;
    final (IconData icon, String status) = switch (e.state) {
      OutboxState.sending => (Icons.upload_rounded, 'Sending…'),
      OutboxState.failed => (Icons.error_outline_rounded, e.error.isEmpty ? 'Not sent' : 'Not sent · ${e.error}'),
      OutboxState.sent when unconfirmed => (Icons.help_outline_rounded, 'Sent, but not in the session yet'),
      OutboxState.sent => (Icons.schedule_rounded, 'Queued · Claude reads it at its next step'),
    };
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, left: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.userBubble.withValues(alpha: failed ? 0.5 : 0.8),
                borderRadius: BorderRadius.circular(16),
                border: failed ? Border.all(color: c.danger.withValues(alpha: 0.5)) : null,
              ),
              child: Text(SendMessage.wording(e.text), maxLines: 8, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: failed ? c.danger : c.faint),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(status, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: failed ? c.danger : c.faint)),
                  ),
                  if (failed || unconfirmed) ...[
                    TextButton(
                      key: Key('outbox-retry-${e.id}'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => bloc.add(OutboxRetried(e.id)),
                      child: Text(failed ? 'Retry' : 'Resend'),
                    ),
                    TextButton(
                      key: Key('outbox-discard-${e.id}'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => bloc.add(OutboxDiscarded(e.id)),
                      child: const Text('Discard'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where a fork split off: history above it is shared with the parent.
class _ForkMarker extends StatelessWidget {
  const _ForkMarker();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.accent.withValues(alpha: 0.4))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.call_split_rounded, size: 14, color: c.accent),
                const SizedBox(width: 6),
                Text('Forked here · above is shared with the original', style: TextStyle(fontSize: 12, color: c.accent)),
              ],
            ),
          ),
          Expanded(child: Divider(color: c.accent.withValues(alpha: 0.4))),
        ],
      ),
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
  const _Working({required this.waitingForApproval, this.stopping = false});

  final bool waitingForApproval, stopping;

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
          Text(
              widget.stopping
                  ? 'Stopping…'
                  : widget.waitingForApproval
                      ? 'Waiting for your approval'
                      : 'Claude is working',
              style: TextStyle(fontSize: 12.5, color: c.muted)),
        ],
      ),
    );
  }

  static double _pulse(double t) => t < 0.5 ? t * 2 : (1 - t) * 2;
}

/// An interrupt that didn't stop the turn: press Esc again, look at the
/// screen, or end the session.
class _StillWorking extends StatelessWidget {
  const _StillWorking({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bloc = context.read<SessionBloc>();
    return Container(
      key: const Key('still-working'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(session.error.isNotEmpty ? session.error : "Claude hasn't stopped yet.", style: const TextStyle(fontSize: 13)),
          TextButton(key: const Key('interrupt-again'), onPressed: () => bloc.add(const InterruptRequested()), child: const Text('Esc again')),
          if (session.hasScreen)
            TextButton(onPressed: () => showTerminalSheet(context, session.id), child: const Text('Show screen')),
          if (session.canEnd)
            TextButton(
              key: const Key('interrupt-end'),
              style: TextButton.styleFrom(foregroundColor: c.danger),
              onPressed: () async {
                if (await _confirmEnd(context, session)) bloc.add(const EndRequested());
              },
              child: const Text('End session'),
            ),
        ],
      ),
    );
  }
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
  final _focus = FocusNode();
  final _files = <Artifact>[];
  int _uploading = 0;

  Future<void> _attach() async {
    final added = await pickAndUpload(context,
        session: widget.state.sessionId, forMessage: true, onUploading: (n) => mounted ? setState(() => _uploading = n) : null);
    if (mounted && added.isNotEmpty) setState(() => _files.addAll(added));
  }

  @override
  void initState() {
    super.initState();
    _restore(widget.state.draft);
    _text.addListener(() {
      setState(() {});
      if (_text.text != _lastReported) {
        _lastReported = _text.text;
        context.read<SessionBloc>().add(DraftChanged(_text.text));
      }
    });
  }

  String _lastReported = '';

  void _restore(String? draft) {
    if (draft == null || draft.isEmpty || _text.text.isNotEmpty) return;
    _lastReported = draft;
    _text.text = draft;
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    if (old.state.draft == null) _restore(widget.state.draft);
    // After the frame: the full editor may still be listening while it closes.
    if (old.state.sentId != widget.state.sentId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _text.clear();
        if (mounted) setState(_files.clear);
      });
    }
    if (old.state.quoteId != widget.state.quoteId) _insertQuote(widget.state.quote);
  }

  void _insertQuote(String quote) {
    final quoted = quote.split('\n').map((l) => l.isEmpty ? '>' : '> $l').join('\n');
    final before = _text.text.trimRight();
    _text.text = '${before.isEmpty ? '' : '$before\n\n'}$quoted\n\n';
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final s = widget.state;
    if (!s.canType || s.sending || _uploading > 0 || (_text.text.trim().isEmpty && _files.isEmpty)) return;
    context.read<SessionBloc>().add(MessageSubmitted(_text.text, attachments: [for (final f in _files) f.id]));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.state;
    final bloc = context.read<SessionBloc>();
    final hint = !s.nodeOnline
        ? '${s.session?.node ?? 'Device'} is offline'
        : (s.forking ? 'First message of the new fork…' : 'Reply to Claude…');
    final canSubmit = s.canType && !s.sending && _uploading == 0 && (_text.text.trim().isNotEmpty || _files.isNotEmpty);
    final canStop = s.session?.canInterrupt ?? false;
    return PromptBox(
      controller: _text,
      focusNode: _focus,
      fieldKey: const Key('composer'),
      hint: hint,
      enabled: s.canType,
      canSubmit: s.canType && !s.sending,
      autofocus: s.forking,
      highlight: s.forking,
      onSubmit: _submit,
      onEscape: canStop ? () => bloc.add(const InterruptRequested()) : null,
      header: s.forking || _files.isNotEmpty || _uploading > 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.forking) _forkBanner(c, bloc),
                if (_files.isNotEmpty || _uploading > 0)
                  AttachmentChips(files: _files, uploading: _uploading, onRemove: (f) => setState(() => _files.remove(f))),
              ],
            )
          : null,
      actions: [
        PromptButton(
          key: const Key('attach'),
          tooltip: 'Attach files',
          icon: Icons.attach_file_rounded,
          plain: true,
          onPressed: s.canType ? _attach : null,
        ),
        if (canStop)
          PromptButton(
            tooltip: s.interrupting ? 'Stopping…' : 'Stop',
            icon: Icons.stop_rounded,
            onPressed: s.interrupting ? null : () => bloc.add(const InterruptRequested()),
          ),
        PromptButton(key: const Key('send'), tooltip: 'Send', icon: Icons.arrow_upward_rounded, filled: true, busy: s.sending, onPressed: canSubmit ? _submit : null),
      ],
      footer: isDesktop
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Enter to send · Shift+Enter for a new line', style: TextStyle(fontSize: 11, color: c.faint)),
            )
          : null,
    );
  }

  Widget _forkBanner(TetherColors c, SessionBloc bloc) => Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2, right: 4),
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
            );
}

class _ContinueDialog extends StatefulWidget {
  const _ContinueDialog();

  @override
  State<_ContinueDialog> createState() => _ContinueDialogState();
}

class _ContinueDialogState extends State<_ContinueDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Continue on the hub'),
        content: SizedBox(
          width: 420,
          child: TextField(
            key: const Key('continue-text'),
            controller: _text,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'First message',
              helperText: 'Starts a new session on the hub with this conversation',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(key: const Key('continue-go'), onPressed: () => Navigator.pop(context, _text.text), child: const Text('Continue')),
        ],
      );
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
    if (a.kind == ApprovalKind.question) return QuestionCard(approval: a, sessionTitle: sessionTitle);
    if (a.kind == ApprovalKind.prompt) return PromptCard(approval: a, sessionTitle: sessionTitle);
    final trust = a.kind == ApprovalKind.folderTrust;
    final busy = context.select<HubCubit, bool>((cubit) => cubit.state.deciding.contains(a.id));
    final hub = context.read<HubCubit>();
    void decide(bool allow) => hub.decide(a.id, allow: allow);
    final mode = context.select<HubCubit, String>((h) => h.state.hub.sessions[a.session]?.permissionMode ?? '');
    final plan = a.toolName == 'ExitPlanMode';
    // Edits asked one by one in the default mode: offer to stop asking.
    final edit = !plan && mode != 'acceptEdits' && const {'Edit', 'Write', 'MultiEdit', 'NotebookEdit'}.contains(a.toolName);
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
          // Wraps on narrow cards (dashboard, phone) rather than overflowing.
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (plan || edit)
                TextButton(
                  key: Key('allow-accept-edits-${a.id}'),
                  onPressed: busy ? null : () => hub.decideWithMode(a.id, a.session, PermissionMode.acceptEdits),
                  child: Text(plan ? 'Approve, accept edits' : 'Allow, accept edits'),
                ),
              OutlinedButton(onPressed: busy ? null : () => decide(false), child: Text(trust ? "Don't trust" : (plan ? 'Keep planning' : 'Deny'))),
              FilledButton(onPressed: busy ? null : () => decide(true), child: Text(trust ? 'Trust folder' : (plan ? 'Approve plan' : 'Allow'))),
            ],
          ),
        ],
      ),
    );
  }
}
