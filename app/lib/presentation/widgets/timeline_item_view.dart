import 'package:flutter/material.dart';

import '../../gen/tether/v1/render.pb.dart' as pb;
import '../../gen/tether/v1/render.pbenum.dart' as pbe;
import '../../domain/entities/entities.dart' show Artifact;
import '../artifacts/artifact_widgets.dart';
import 'common.dart';
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
      pb.TimelineItem_Kind.user => _UserBubble(
          text: item.user.text,
          queued: item.user.queued,
          source: item.user.source,
          sentAsFile: item.user.attachmentId.isNotEmpty,
          // A long message's own file is shown as the text itself.
          files: [for (final a in linkedArtifacts(context, item.itemId)) if (a.id != item.user.attachmentId) a],
        ),
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

/// A run of consecutive tool calls (and the thinking between them) folded
/// into one line, so a long turn reads as "Ran 12 steps" until opened.
class ActivityGroup extends StatefulWidget {
  const ActivityGroup({super.key, required this.items, this.active = false});

  final List<pb.TimelineItem> items;

  /// Claude is still working on this run.
  final bool active;

  @override
  State<ActivityGroup> createState() => _ActivityGroupState();
}

class _ActivityGroupState extends State<ActivityGroup> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tools = [for (final i in widget.items) if (i.whichKind() == pb.TimelineItem_Kind.tool) i.tool];
    final failed = tools.where((t) => t.status == pbe.ToolCard_Status.STATUS_FAILED).length;
    final running = tools.lastWhere(
      (t) => t.status == pbe.ToolCard_Status.STATUS_RUNNING || t.status == pbe.ToolCard_Status.STATUS_PENDING,
      orElse: () => pb.ToolCard(),
    );
    final busy = widget.active || running.name.isNotEmpty;
    final counts = <String, int>{};
    for (final t in tools) {
      counts[t.name] = (counts[t.name] ?? 0) + 1;
    }
    final summary = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key)
        .join(' · ');
    final current = running.name.isNotEmpty ? running : tools.last;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: failed > 0 ? c.danger.withValues(alpha: 0.45) : c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => keepInPlace(context, () => setState(() => _open = !_open)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined, size: 16, color: c.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: busy ? 'Working · ${tools.length} steps' : 'Ran ${tools.length} steps',
                              style: TextStyle(fontWeight: FontWeight.w600, color: c.text),
                            ),
                            TextSpan(text: '  $summary', style: TextStyle(color: c.faint)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (busy && !_open)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${current.name} · ${current.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: c.muted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (busy)
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: c.accent))
                  else if (failed > 0)
                    Text('$failed failed', style: TextStyle(fontSize: 12, color: c.danger))
                  else
                    Icon(Icons.check_rounded, size: 16, color: c.success),
                  const SizedBox(width: 4),
                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: c.faint),
                ],
              ),
            ),
          ),
          if (_open)
            for (final i in widget.items) ...[
              Divider(height: 1, color: c.border),
              Padding(
                padding: EdgeInsets.only(left: i.parentToolUseId.isNotEmpty ? 16 : 0),
                child: i.whichKind() == pb.TimelineItem_Kind.tool
                    ? ToolCardView(key: ValueKey(i.itemId), card: i.tool, flat: true)
                    : Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4), child: _Thinking(thinking: i.thinking)),
              ),
            ],
        ],
      ),
    );
  }
}

class _UserBubble extends StatefulWidget {
  const _UserBubble({required this.text, this.queued = false, this.source = '', this.files = const [], this.sentAsFile = false});

  final String text;
  final bool queued;

  /// Went to the session as a file because it was long.
  final bool sentAsFile;

  /// Pictures pasted into it and files attached to it.
  final List<Artifact> files;

  /// Who sent it, as the hub recorded: an app's name, or "terminal".
  final String source;

  static (IconData, String) _describe(String source) {
    if (source == 'terminal') return (Icons.terminal_rounded, 'Typed in the terminal');
    final name = source.replaceAll(RegExp(r' \((\w+)\)$'), '');
    final icon = switch (RegExp(r'\((\w+)\)$').firstMatch(source)?.group(1)) {
      'android' || 'ios' => Icons.phone_android_rounded,
      'windows' || 'linux' || 'macos' => Icons.laptop_windows_outlined,
      _ => source.startsWith('tetherctl') ? Icons.code_rounded : Icons.devices_outlined,
    };
    return (icon, name);
  }

  @override
  State<_UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends State<_UserBubble> {
  static const _collapsedLines = 10;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final w = widget;
    final text = w.text, queued = w.queued, source = w.source, files = w.files;
    final long = w.sentAsFile || '\n'.allMatches(text).length >= _collapsedLines || text.length > 1500;
    final style = Theme.of(context).textTheme.bodyLarge;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: c.userBubble,
        borderRadius: BorderRadius.circular(16),
        border: queued ? Border.all(color: c.border) : null,
      ),
      // Plain text: the timeline's SelectionArea makes it selectable across messages.
      child: !long
          ? Text(text, style: style)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: style, maxLines: _open ? null : _collapsedLines, overflow: _open ? null : TextOverflow.fade),
                const SizedBox(height: 6),
                InkWell(
                  key: const Key('expand-message'),
                  onTap: () => setState(() => _open = !_open),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: c.muted),
                      const SizedBox(width: 4),
                      Text(_open ? 'Show less' : 'Show full message', style: TextStyle(fontSize: 12.5, color: c.muted, fontWeight: FontWeight.w600)),
                      if (w.sentAsFile) Text('  ·  sent as a file', style: TextStyle(fontSize: 12, color: c.faint)),
                    ],
                  ),
                ),
              ],
            ),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: contentWidth * 0.85),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (queued) Opacity(opacity: 0.7, child: bubble) else bubble,
            if (files.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: ArtifactStrip(artifacts: files, alignEnd: true)),
            if (!queued && source.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_UserBubble._describe(source).$1, size: 12, color: c.faint),
                    const SizedBox(width: 4),
                    Text(_UserBubble._describe(source).$2, style: TextStyle(fontSize: 11.5, color: c.faint)),
                  ],
                ),
              ),
            if (queued)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: c.faint),
                    const SizedBox(width: 4),
                    Text('Queued · Claude reads it at its next step', style: TextStyle(fontSize: 11.5, color: c.faint)),
                  ],
                ),
              ),
          ],
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
          onTap: () => keepInPlace(context, () => setState(() => _open = !_open)),
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
