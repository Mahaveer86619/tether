import 'package:flutter/material.dart' hide Table;

import '../../gen/tether/v1/render.pb.dart' hide Divider;
import '../theme/syntax.dart';
import '../theme/theme.dart';
import '../ui/tokens.dart';

enum TermKind {
  prompt,
  text,
  heading,
  code,
  codeLabel,
  tableBorder,
  tableHeader,
  tableRow,
  quote,
  toolOk,
  toolFailed,
  toolRunning,
  detail,
  diffAdd,
  diffRemove,
  diffHunk,
  todoDone,
  todoActive,
  todoPending,
  dim,
  warning,
  error,
}

class TermLine {
  const TermLine(this.kind, this.text, {this.lang = ''});

  final TermKind kind;
  final String text;

  /// For code lines: the language to colour it as.
  final String lang;
}

String _spans(Iterable<Span> spans) => spans.map((s) => s.text).join();

String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1)}…';

/// A table drawn with box characters, columns as wide as their widest cell
/// (up to [maxCol]).
List<TermLine> _table(Table t, {int maxCol = 36}) {
  final header = [for (final c in t.header) _spans(c.spans).replaceAll('\n', ' ')];
  final rows = [
    for (final r in t.rows) [for (final c in r.cells) _spans(c.spans).replaceAll('\n', ' ')],
  ];
  final cols = [header.length, ...rows.map((r) => r.length)].reduce((a, b) => a > b ? a : b);
  if (cols == 0) return const [];
  final width = List<int>.filled(cols, 3);
  for (final r in [header, ...rows]) {
    for (var i = 0; i < r.length; i++) {
      width[i] = [width[i], r[i].length.clamp(0, maxCol)].reduce((a, b) => a > b ? a : b);
    }
  }
  String cell(String s, int i) {
    final text = _clip(s, width[i]);
    final align = i < t.align.length ? t.align[i] : Table_Align.ALIGN_UNSPECIFIED;
    return switch (align) {
      Table_Align.ALIGN_RIGHT => text.padLeft(width[i]),
      Table_Align.ALIGN_CENTER => text.padLeft((width[i] + text.length) ~/ 2).padRight(width[i]),
      _ => text.padRight(width[i]),
    };
  }

  String rule(String l, String m, String r) => '$l${[for (final w in width) '─' * (w + 2)].join(m)}$r';
  String row(List<String> r) => '│ ${[for (var i = 0; i < cols; i++) cell(i < r.length ? r[i] : '', i)].join(' │ ')} │';
  return [
    TermLine(TermKind.tableBorder, rule('┌', '┬', '┐')),
    if (header.isNotEmpty) ...[
      TermLine(TermKind.tableHeader, row(header)),
      TermLine(TermKind.tableBorder, rule('├', '┼', '┤')),
    ],
    for (final r in rows) TermLine(TermKind.tableRow, row(r)),
    TermLine(TermKind.tableBorder, rule('└', '┴', '┘')),
  ];
}

List<TermLine> _blockLines(Block b, {String indent = ''}) {
  switch (b.whichKind()) {
    case Block_Kind.heading:
      return [TermLine(TermKind.heading, '$indent${'#' * b.heading.level.clamp(1, 6)} ${_spans(b.heading.spans)}')];
    case Block_Kind.paragraph:
      return [for (final l in _spans(b.paragraph.spans).split('\n')) TermLine(TermKind.text, '$indent$l')];
    case Block_Kind.list:
      final out = <TermLine>[];
      for (final (i, item) in b.list.items.indexed) {
        final mark = item.hasChecked() ? (item.checked ? '[x]' : '[ ]') : (b.list.ordered ? '${b.list.start + i}.' : '•');
        final inner = [for (final blk in item.blocks) ..._blockLines(blk)];
        out.add(TermLine(TermKind.text, '$indent$mark ${inner.isEmpty ? '' : inner.first.text}'));
        for (final l in inner.skip(1)) {
          out.add(TermLine(l.kind, '$indent  ${l.text}', lang: l.lang));
        }
      }
      return out;
    case Block_Kind.code:
      final lang = b.code.lang;
      return [
        TermLine(TermKind.codeLabel, '$indent┌─ ${lang.isEmpty ? 'code' : lang}'),
        for (final l in b.code.text.split('\n')) TermLine(TermKind.code, '$indent│ $l', lang: lang),
        TermLine(TermKind.codeLabel, '$indent└─'),
      ];
    case Block_Kind.table:
      return _table(b.table);
    case Block_Kind.quote:
      return [for (final blk in b.quote.blocks) for (final l in _blockLines(blk)) TermLine(TermKind.quote, '$indent│ ${l.text}')];
    case Block_Kind.divider:
      return [TermLine(TermKind.dim, '$indent${'─' * 40}')];
    case Block_Kind.image:
      return [TermLine(TermKind.dim, '$indent[image: ${b.image.alt}]')];
    case Block_Kind.notSet:
      return const [];
  }
}

String _duration(int ms) {
  final s = ms ~/ 1000;
  if (s < 60) return '${s}s';
  return '${s ~/ 60}m ${s % 60}s';
}

String _extension(String path) {
  final name = path.split(RegExp(r'[\\/]')).last;
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i + 1).toLowerCase();
}

/// The conversation as a terminal prints it: what you typed after a `>`,
/// Claude's words with tables, lists and code drawn in text, and each tool
/// call as a line with what it did under it (a diff for an edit, the new
/// text for a write, the checklist for to-dos). The same items the chat
/// draws, so the two always agree.
List<TermLine> transcriptLines(Iterable<TimelineItem> items, {int outputLines = 3, int diffLines = 16}) {
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
          out.addAll(_blockLines(b));
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
          final diff = t.edit.unifiedDiff.split('\n').where((l) => l.isNotEmpty && !l.startsWith('+++') && !l.startsWith('---')).toList();
          for (final l in diff.take(diffLines)) {
            out.add(TermLine(l.startsWith('@@') ? TermKind.diffHunk : (l.startsWith('+') ? TermKind.diffAdd : (l.startsWith('-') ? TermKind.diffRemove : TermKind.detail)), '    $l'));
          }
          if (diff.length > diffLines) out.add(TermLine(TermKind.dim, '    … ${diff.length - diffLines} more lines'));
        } else if (t.hasWrite()) {
          out.add(TermLine(TermKind.detail, '  └ wrote ${t.write.lines} lines'));
          final preview = t.write.preview.split('\n');
          for (final l in preview.take(6)) {
            out.add(TermLine(TermKind.code, '    $l', lang: _extension(t.write.path)));
          }
          if (preview.length > 6) out.add(TermLine(TermKind.dim, '    …'));
        } else if (t.hasTodos()) {
          for (final todo in t.todos.todos) {
            final (kindOf, mark) = switch (todo.status) {
              Todo_Status.STATUS_COMPLETED => (TermKind.todoDone, '[x]'),
              Todo_Status.STATUS_IN_PROGRESS => (TermKind.todoActive, '[>]'),
              _ => (TermKind.todoPending, '[ ]'),
            };
            out.add(TermLine(kindOf, '  $mark ${todo.status == Todo_Status.STATUS_IN_PROGRESS && todo.activeForm.isNotEmpty ? todo.activeForm : todo.content}'));
          }
        }
        final text = t.output.text.trimRight();
        if (text.isNotEmpty && !t.hasTodos()) {
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
/// line, selectable. Code is coloured for its language and diffs by what
/// they add and remove.
class TerminalTranscript extends StatelessWidget {
  const TerminalTranscript({super.key, required this.items, this.working = false});

  final Iterable<TimelineItem> items;
  final bool working;

  Color _color(BuildContext context, TermKind k) {
    final c = context.colors;
    return switch (k) {
      TermKind.prompt => c.accent,
      TermKind.text => c.text,
      TermKind.heading => c.accent,
      TermKind.code => c.text,
      TermKind.codeLabel => c.faint,
      TermKind.tableBorder => c.faint,
      TermKind.tableHeader => c.text,
      TermKind.tableRow => c.text,
      TermKind.quote => c.muted,
      TermKind.toolOk => c.success,
      TermKind.toolFailed => c.danger,
      TermKind.toolRunning => c.warning,
      TermKind.detail => c.muted,
      TermKind.diffAdd => c.success,
      TermKind.diffRemove => c.danger,
      TermKind.diffHunk => c.info,
      TermKind.todoDone => c.muted,
      TermKind.todoActive => c.accent,
      TermKind.todoPending => c.text,
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
    Widget line(TermLine l) {
      final bold = l.kind == TermKind.prompt || l.kind == TermKind.heading || l.kind == TermKind.tableHeader || l.kind == TermKind.todoActive;
      final base = style.copyWith(color: _color(context, l.kind), fontWeight: bold ? FontWeight.w600 : null);
      if (l.kind == TermKind.code && l.lang.isNotEmpty) {
        // "│ " is the frame; the code after it is coloured.
        final cut = l.text.indexOf('│ ');
        final prefix = cut < 0 ? '' : l.text.substring(0, cut + 2);
        final code = cut < 0 ? l.text : l.text.substring(cut + 2);
        final spans = highlightCode(code, l.lang, c.syntax);
        return Text.rich(TextSpan(style: base.copyWith(color: c.text), children: [TextSpan(text: prefix, style: TextStyle(color: c.faint)), ...(spans ?? [TextSpan(text: code)])]));
      }
      final text = Text(l.text.isEmpty ? ' ' : l.text, style: base);
      if (l.kind == TermKind.diffAdd || l.kind == TermKind.diffRemove) {
        return Container(color: l.kind == TermKind.diffAdd ? c.diffAdd : c.diffRemove, child: text);
      }
      return text;
    }

    bool isTable(TermLine l) => l.kind == TermKind.tableBorder || l.kind == TermKind.tableHeader || l.kind == TermKind.tableRow;
    // A table scrolls sideways as one piece; everything else wraps.
    final blocks = <List<TermLine>>[];
    for (final l in lines) {
      if (isTable(l) && blocks.isNotEmpty && isTable(blocks.last.first)) {
        blocks.last.add(l);
      } else {
        blocks.add([l]);
      }
    }
    Widget block(List<TermLine> b) => isTable(b.first)
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final l in b) line(l)]))
        : line(b.first);
    return Container(
      key: const Key('terminal-transcript'),
      color: c.codeBg,
      child: SelectionArea(
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
          itemCount: blocks.length + (working ? 1 : 0),
          itemBuilder: (context, i) {
            if (working && i == 0) return Text('█', style: style.copyWith(color: c.accent));
            return block(blocks[blocks.length - 1 - (i - (working ? 1 : 0))]);
          },
        ),
      ),
    );
  }
}
