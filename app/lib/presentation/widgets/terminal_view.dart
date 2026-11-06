import 'package:flutter/material.dart';

import '../../gen/tether/v1/render.pb.dart';
import '../theme/theme.dart';
import '../ui/tokens.dart';

enum TermKind { prompt, text, code, toolOk, toolFailed, toolRunning, detail, dim, warning, error }

class TermLine {
  const TermLine(this.kind, this.text);

  final TermKind kind;
  final String text;
}

String _spans(Iterable<Span> spans) => spans.map((s) => s.text).join();

List<String> _blockLines(Block b, {String indent = ''}) {
  switch (b.whichKind()) {
    case Block_Kind.heading:
      return ['$indent${'#' * b.heading.level.clamp(1, 6)} ${_spans(b.heading.spans)}'];
    case Block_Kind.paragraph:
      return [for (final l in _spans(b.paragraph.spans).split('\n')) '$indent$l'];
    case Block_Kind.list:
      final out = <String>[];
      for (final (i, item) in b.list.items.indexed) {
        final mark = item.hasChecked() ? (item.checked ? '[x]' : '[ ]') : (b.list.ordered ? '${b.list.start + i}.' : '-');
        final inner = [for (final blk in item.blocks) ..._blockLines(blk)];
        out.add('$indent$mark ${inner.isEmpty ? '' : inner.first}');
        for (final l in inner.skip(1)) {
          out.add('$indent   $l');
        }
      }
      return out;
    case Block_Kind.code:
      return [for (final l in b.code.text.split('\n')) '$indent  $l'];
    case Block_Kind.table:
      return [
        '$indent${b.table.header.map((c) => _spans(c.spans)).join(' | ')}',
        for (final r in b.table.rows) '$indent${r.cells.map((c) => _spans(c.spans)).join(' | ')}',
      ];
    case Block_Kind.quote:
      return [for (final blk in b.quote.blocks) for (final l in _blockLines(blk)) '$indent> $l'];
    case Block_Kind.divider:
      return ['$indent---'];
    case Block_Kind.image:
      return ['$indent[image: ${b.image.alt}]'];
    case Block_Kind.notSet:
      return const [];
  }
}

String _duration(int ms) {
  final s = ms ~/ 1000;
  if (s < 60) return '${s}s';
  return '${s ~/ 60}m ${s % 60}s';
}

/// The conversation as a terminal prints it: what you typed after a `>`,
/// Claude's words as plain text, and each tool call as a line with its
/// outcome under it. The same items the chat draws, so the two always agree.
List<TermLine> transcriptLines(Iterable<TimelineItem> items, {int outputLines = 3}) {
  final out = <TermLine>[];
  for (final it in items) {
    switch (it.whichKind()) {
      case TimelineItem_Kind.user:
        final lines = it.user.text.split('\n');
        for (final (i, l) in lines.indexed) {
          out.add(TermLine(TermKind.prompt, i == 0 ? '> $l' : '  $l'));
        }
        if (it.user.queued) out.add(const TermLine(TermKind.dim, '  (queued: Claude reads it at its next step)'));
      case TimelineItem_Kind.markdown:
        for (final b in it.markdown.blocks) {
          final code = b.whichKind() == Block_Kind.code;
          for (final l in _blockLines(b)) {
            out.add(TermLine(code ? TermKind.code : TermKind.text, l));
          }
        }
      case TimelineItem_Kind.thinking:
        out.add(const TermLine(TermKind.dim, '∴ thinking…'));
      case TimelineItem_Kind.tool:
        final t = it.tool;
        final kind = switch (t.status) {
          ToolCard_Status.STATUS_FAILED => TermKind.toolFailed,
          ToolCard_Status.STATUS_RUNNING || ToolCard_Status.STATUS_PENDING => TermKind.toolRunning,
          _ => TermKind.toolOk,
        };
        out.add(TermLine(kind, '● ${t.name}${t.title.isEmpty ? '' : '(${t.title})'}'));
        if (t.hasEdit()) {
          out.add(TermLine(TermKind.detail, '  └ +${t.edit.added} −${t.edit.removed}'));
        }
        final text = t.output.text.trimRight();
        if (text.isNotEmpty) {
          final lines = text.split('\n');
          for (final (i, l) in lines.take(outputLines).indexed) {
            out.add(TermLine(t.output.isError ? TermKind.error : TermKind.detail, '  ${i == 0 ? '└' : ' '} $l'));
          }
          final more = lines.length - outputLines + t.output.omittedLines;
          if (more > 0) out.add(TermLine(TermKind.dim, '    … $more more lines'));
        }
      case TimelineItem_Kind.notice:
        out.add(TermLine(it.notice.level == Notice_Level.LEVEL_ERROR ? TermKind.error : TermKind.warning, '! ${it.notice.text}'));
      case TimelineItem_Kind.result:
        final r = it.result;
        out.add(TermLine(r.isError ? TermKind.error : TermKind.dim, [
          '── ${r.isError ? 'failed' : 'finished'}',
          if (r.durationMs > 0) _duration(r.durationMs.toInt()),
          if (r.numTurns > 0) '${r.numTurns} turns',
          if (r.costUsd > 0) '\$${r.costUsd.toStringAsFixed(2)}',
        ].join(' · ')));
      case TimelineItem_Kind.notSet:
        break;
    }
    out.add(const TermLine(TermKind.dim, ''));
  }
  if (out.isNotEmpty) out.length -= 1;
  return out;
}

/// A transcript in monospace on the code background, pinned to the newest
/// line, selectable.
class TerminalTranscript extends StatelessWidget {
  const TerminalTranscript({super.key, required this.items, this.working = false});

  final Iterable<TimelineItem> items;
  final bool working;

  Color _color(BuildContext context, TermKind k) {
    final c = context.colors;
    return switch (k) {
      TermKind.prompt => c.accent,
      TermKind.text => c.text,
      TermKind.code => c.syntax.string,
      TermKind.toolOk => c.success,
      TermKind.toolFailed => c.danger,
      TermKind.toolRunning => c.warning,
      TermKind.detail => c.muted,
      TermKind.dim => c.faint,
      TermKind.warning => c.warning,
      TermKind.error => c.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = transcriptLines(items);
    final style = Type.meta(context, size: 12.5, color: c.text).copyWith(height: 1.5);
    return Container(
      key: const Key('terminal-transcript'),
      color: c.codeBg,
      child: SelectionArea(
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
          itemCount: lines.length + (working ? 1 : 0),
          itemBuilder: (context, i) {
            if (working && i == 0) return Text('█', style: style.copyWith(color: c.accent));
            final l = lines[lines.length - 1 - (i - (working ? 1 : 0))];
            return Text(l.text.isEmpty ? ' ' : l.text, style: style.copyWith(color: _color(context, l.kind), fontWeight: l.kind == TermKind.prompt ? FontWeight.w500 : null));
          },
        ),
      ),
    );
  }
}
