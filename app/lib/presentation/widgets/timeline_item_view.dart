import 'package:flutter/material.dart';

import '../../gen/tether/v1/render.pb.dart' as pb;
import '../../gen/tether/v1/render.pbenum.dart' as pbe;
import 'markdown_view.dart';
import '../theme/theme.dart';
import 'tool_card.dart';

/// Max width of the conversation column, like a reading layout.
const double contentWidth = 760;

/// One timeline item.
class TimelineItemView extends StatelessWidget {
  const TimelineItemView({super.key, required this.item});

  final pb.TimelineItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget child = switch (item.whichKind()) {
      pb.TimelineItem_Kind.user => _UserBubble(text: item.user.text),
      pb.TimelineItem_Kind.markdown => MarkdownView(blocks: item.markdown.blocks, streaming: item.markdown.streaming),
      pb.TimelineItem_Kind.tool => ToolCardView(card: item.tool),
      pb.TimelineItem_Kind.thinking => _Thinking(thinking: item.thinking),
      pb.TimelineItem_Kind.notice => _NoticeView(notice: item.notice),
      pb.TimelineItem_Kind.result => _ResultView(result: item.result),
      pb.TimelineItem_Kind.notSet => const SizedBox.shrink(),
    };
    if (item.parentToolUseId.isNotEmpty) {
      child = Container(
        padding: const EdgeInsets.only(left: 12),
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: c.border, width: 2))),
        child: child,
      );
    }
    final gap = switch (item.whichKind()) {
      pb.TimelineItem_Kind.tool => 6.0,
      pb.TimelineItem_Kind.user => 22.0,
      _ => 14.0,
    };
    return Padding(padding: EdgeInsets.only(top: gap), child: child);
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: contentWidth * 0.85),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(color: c.userBubble, borderRadius: BorderRadius.circular(16)),
          child: SelectableText(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}

class _Thinking extends StatefulWidget {
  const _Thinking({required this.thinking});

  final pb.Thinking thinking;

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology_alt_outlined, size: 16, color: c.faint),
                const SizedBox(width: 6),
                Text(widget.thinking.streaming ? 'Thinking…' : 'Thought process', style: TextStyle(color: c.muted, fontSize: 13)),
                Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: c.faint),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 4),
            child: Text(widget.thinking.text, style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.5, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }
}

class _NoticeView extends StatelessWidget {
  const _NoticeView({required this.notice});

  final pb.Notice notice;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (notice.level) {
      pbe.Notice_Level.LEVEL_ERROR => c.danger,
      pbe.Notice_Level.LEVEL_WARNING => c.warning,
      _ => c.faint,
    };
    return Center(
      child: Text(notice.text, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 12.5)),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final pb.ResultSummary result;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final secs = result.durationMs.toInt() / 1000;
    final parts = [
      if (result.isError) 'Failed' else 'Done',
      '${result.numTurns} ${result.numTurns == 1 ? 'turn' : 'turns'}',
      '${secs.toStringAsFixed(secs < 10 ? 1 : 0)}s',
      if (result.costUsd > 0) '\$${result.costUsd.toStringAsFixed(result.costUsd < 0.1 ? 4 : 2)}',
    ];
    return Row(
      children: [
        Icon(result.isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 14, color: result.isError ? c.danger : c.faint),
        const SizedBox(width: 6),
        Text(parts.join(' · '), style: TextStyle(color: c.faint, fontSize: 12)),
      ],
    );
  }
}
