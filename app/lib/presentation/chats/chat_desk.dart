import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../gen/tether/v1/render.pb.dart' as pb;
import '../theme/theme.dart';
import '../widgets/common.dart';
import 'chat_desk_cubit.dart';

/// "42k", "1.2M": a token count in a few characters.
String shortTokens(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1)}M';
  if (n >= 1000) return '${(n / 1000).round()}k';
  return '$n';
}

/// The chat's context size as a small meter in its header, with the
/// rewind, handoff and Remind actions behind it.
class ContextMeter extends StatelessWidget {
  const ContextMeter({super.key, required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<ChatDeskCubit>();
    final desk = context.select<ChatDeskCubit, ChatDesk?>((x) => x.state.desk);
    if (desk == null) return const SizedBox.shrink();
    final share = desk.handoffAt > 0 ? (desk.tokens / desk.handoffAt).clamp(0.0, 1.0) : 0.0;
    final color = desk.heavy ? c.warning : (share > 0.6 ? c.accent : c.muted);
    final how = desk.fromUsage ? 'from its last turn' : 'estimated from the saved text';
    return PopupMenuButton<String>(
      key: const Key('context-meter'),
      tooltip: 'About ${shortTokens(desk.tokens)} tokens of context ($how). A handoff is offered at ${shortTokens(desk.handoffAt)}.',
      onSelected: (v) async {
        switch (v) {
          case 'rewind':
            await showRewindPicker(context, cubit);
          case 'handoff':
            await confirmHandoff(context, cubit);
          case 'remind':
            await cubit.setRemind(!desk.remind);
        }
      },
      itemBuilder: (_) => [
        _item('rewind', Icons.history_rounded, 'Rewind to an earlier prompt…', enabled: desk.prompts.isNotEmpty),
        _item('handoff', Icons.fast_forward_rounded, 'Continue in a fresh session…'),
        _item('remind', desk.remind ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, 'Remind me before sending'),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 4,
              child: ClipRRect(
                borderRadius: context.round(2),
                child: LinearProgressIndicator(value: share, color: color, backgroundColor: c.border),
              ),
            ),
            const SizedBox(width: 6),
            Text(shortTokens(desk.tokens), key: const Key('context-tokens'), style: TextStyle(fontSize: 11.5, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label, {bool enabled = true}) => PopupMenuItem(
        value: value,
        enabled: enabled,
        child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 12), Flexible(child: Text(label))]),
      );
}

/// What sits above the composer: the recap after a gap, the handoff
/// banner when the context is large, and the Remind chips when on.
class DeskAboveComposer extends StatelessWidget {
  const DeskAboveComposer({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ChatDeskCubit>().state;
    final desk = s.desk;
    if (desk == null) return const SizedBox.shrink();
    final recap = desk.recap;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.showRecap && recap != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: RecapCard(recap: recap, onClose: context.read<ChatDeskCubit>().dismissRecap)),
        if (desk.heavy) Padding(padding: const EdgeInsets.only(bottom: 8), child: _HandoffBanner(desk: desk, busy: s.busy)),
        if (desk.remind && (recap != null || desk.rules.isNotEmpty)) Padding(padding: const EdgeInsets.only(bottom: 6), child: _RemindChips(desk: desk)),
      ],
    );
  }
}

/// Where the chat stood: last asked, what was done, what is open.
class RecapCard extends StatelessWidget {
  const RecapCard({super.key, required this.recap, this.onClose});

  final ChatRecap recap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget row(String label, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '$label  ', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
              TextSpan(text: text),
            ]),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5),
          ),
        );
    return Container(
      key: const Key('recap-card'),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: context.round(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_outline_rounded, size: 15, color: c.accent),
              const SizedBox(width: 6),
              Expanded(child: Text('Where this chat stood', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.text))),
              if (onClose != null)
                InkWell(
                  key: const Key('recap-close'),
                  onTap: onClose,
                  child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 16, color: c.faint)),
                ),
            ],
          ),
          if (recap.asked.isNotEmpty) row('Asked', recap.asked),
          if (recap.done.isNotEmpty) row('Done', recap.done),
          if (recap.open.isNotEmpty) row('Open', recap.open.join(' · ')),
        ],
      ),
    );
  }
}

class _HandoffBanner extends StatelessWidget {
  const _HandoffBanner({required this.desk, required this.busy});

  final ChatDesk desk;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      key: const Key('handoff-banner'),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.08), borderRadius: context.round(10), border: Border.all(color: c.warning.withValues(alpha: 0.35))),
      child: Row(
        children: [
          Icon(Icons.data_usage_rounded, size: 16, color: c.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This chat carries about ${shortTokens(desk.tokens)} tokens. A fresh session with a summary costs far less.',
              style: TextStyle(fontSize: 12.5, color: c.text),
            ),
          ),
          TextButton(
            key: const Key('handoff'),
            onPressed: busy ? null : () => confirmHandoff(context, context.read<ChatDeskCubit>()),
            child: const Text('Continue fresh'),
          ),
        ],
      ),
    );
  }
}

class _RemindChips extends StatelessWidget {
  const _RemindChips({required this.desk});

  final ChatDesk desk;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final recap = desk.recap;
    Widget chip(Key key, IconData icon, String label, String title, String body) => ActionChip(
          key: key,
          visualDensity: VisualDensity.compact,
          avatar: Icon(icon, size: 14, color: c.muted),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(child: SelectableText(body)),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
            ),
          ),
        );
    return SizedBox(
      height: 34,
      child: ListView(
        key: const Key('remind-chips'),
        scrollDirection: Axis.horizontal,
        children: [
          if (recap != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: chip(const Key('remind-recap'), Icons.bookmark_outline_rounded, 'Recap', 'Where this chat stood',
                  ['Asked: ${recap.asked}', if (recap.done.isNotEmpty) 'Done: ${recap.done}', if (recap.open.isNotEmpty) 'Open: ${recap.open.join('; ')}'].join('\n\n')),
            ),
          for (final r in desk.rules)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: chip(Key('remind-rule-${r.id}'), Icons.rule_rounded, r.name, 'Standing rule (${r.scope})', r.text),
            ),
        ],
      ),
    );
  }
}

Future<void> confirmHandoff(BuildContext context, ChatDeskCubit cubit) async {
  final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Continue in a fresh session?'),
          content: const Text(
            'Tether writes a summary of this chat (the goal, decisions, open items, files touched and the last three turns) '
            'and starts a new session at the same place with it. The summary is made by rules from the saved text, not by Claude, '
            'so it can miss things. This session stays in the chat.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(key: const Key('confirm-handoff'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue fresh')),
          ],
        ),
      ) ??
      false;
  if (ok) await cubit.handoff();
}

/// Asks before rewinding to [to], saying what will happen.
Future<void> confirmRewind(BuildContext context, ChatDeskCubit cubit, ChatPrompt to) async {
  final which = to.n > 0 ? 'prompt ${to.n}' : 'this prompt';
  final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Rewind to before $which?'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'A new session starts with the conversation up to $which, and the prompt comes back in the composer for you to edit and send. '
                  'The current session stays in the chat, marked as rewound.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: ctx.colors.userBubble, borderRadius: ctx.round(8)),
                  child: Text(to.text, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(key: const Key('confirm-rewind'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Rewind')),
          ],
        ),
      ) ??
      false;
  if (ok) await cubit.rewind(to);
}

/// The quick choices (edit the last prompt, 2 back, 3 back) and every
/// prompt, under the recap so the context is visible before going back.
Future<void> showRewindPicker(BuildContext context, ChatDeskCubit cubit) async {
  final picked = await showModalBottomSheet<ChatPrompt>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => BlocProvider.value(value: cubit, child: const _RewindPicker()),
  );
  if (picked != null && context.mounted) await confirmRewind(context, cubit, picked);
}

class _RewindPicker extends StatelessWidget {
  const _RewindPicker();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<ChatDeskCubit>();
    final desk = context.watch<ChatDeskCubit>().state.desk ?? const ChatDesk();
    final quick = [(1, 'Edit the last prompt'), (2, '2 back'), (3, '3 back')];
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: ListView(
        key: const Key('rewind-picker'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Text('Rewind to before…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (desk.recap != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: RecapCard(recap: desk.recap!)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (back, label) in quick)
                if (cubit.promptBack(back) case final p?)
                  ActionChip(key: Key('rewind-back-$back'), label: Text(label), onPressed: () => Navigator.pop(context, p)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Or pick any', style: TextStyle(fontSize: 12, color: c.muted)),
          for (final p in desk.prompts.reversed)
            ListTile(
              key: Key('rewind-prompt-${p.n}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(width: 28, child: Text('${p.n}', textAlign: TextAlign.right, style: TextStyle(color: c.muted))),
              title: Text(p.text, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(context, p),
            ),
        ],
      ),
    );
  }
}

/// Wraps one of the user's messages in the chat with its actions: a long
/// press on a phone, a button on hover on a desktop.
class UserMessageActions extends StatefulWidget {
  const UserMessageActions({super.key, required this.item, required this.child});

  final pb.TimelineItem item;
  final Widget child;

  @override
  State<UserMessageActions> createState() => _UserMessageActionsState();
}

class _UserMessageActionsState extends State<UserMessageActions> {
  bool _hover = false;

  Future<void> _menu(Offset at) async {
    final cubit = context.read<ChatDeskCubit>();
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      items: const [
        PopupMenuItem(key: Key('rewind-here'), value: 'rewind', child: Row(children: [Icon(Icons.history_rounded, size: 18), SizedBox(width: 12), Flexible(child: Text('Rewind to before this'))])),
        PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.content_copy_rounded, size: 18), SizedBox(width: 12), Flexible(child: Text('Copy'))])),
      ],
    );
    if (!mounted) return;
    switch (v) {
      case 'rewind':
        await confirmRewind(context, cubit, cubit.promptFor(widget.item.itemId, widget.item.user.text));
      case 'copy':
        await Clipboard.setData(ClipboardData(text: widget.item.user.text));
        if (mounted) showToast(context, 'Copied', icon: Icons.content_copy_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onLongPressStart: (d) => _menu(d.globalPosition),
        child: Stack(
          children: [
            widget.child,
            if (_hover)
              Positioned(
                left: 0,
                top: 22,
                child: Builder(
                  builder: (ctx) => IconButton(
                    key: const Key('user-message-menu'),
                    tooltip: 'Message actions',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.more_horiz_rounded, size: 18, color: c.muted),
                    onPressed: () {
                      final box = ctx.findRenderObject() as RenderBox;
                      _menu(box.localToGlobal(box.size.bottomLeft(Offset.zero)));
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
