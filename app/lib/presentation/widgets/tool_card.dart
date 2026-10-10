import 'dart:convert';

import 'package:flutter/material.dart';

import '../../gen/tether/v1/render.pb.dart' as pb;
import '../../gen/tether/v1/render.pbenum.dart' as pbe;
import '../../domain/entities/entities.dart' show TodoItem, TodoStatus;
import 'format.dart';
import 'markdown_view.dart';
import 'todo_checklist.dart';
import '../theme/theme.dart';

/// A tool call as a single collapsible line, like Claude's own UI: icon,
/// tool, short title and status; details on tap.
class ToolCardView extends StatefulWidget {
  const ToolCardView({super.key, required this.card, this.initiallyExpanded = false});

  final pb.ToolCard card;
  final bool initiallyExpanded;

  @override
  State<ToolCardView> createState() => _ToolCardViewState();
}

class _ToolCardViewState extends State<ToolCardView> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = widget.card;
    final running = card.status == pbe.ToolCard_Status.STATUS_RUNNING || card.status == pbe.ToolCard_Status.STATUS_PENDING;
    final failed = card.status == pbe.ToolCard_Status.STATUS_FAILED;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: failed ? c.danger.withValues(alpha: 0.5) : c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(toolIcon(card), size: 16, color: c.muted),
                  const SizedBox(width: 10),
                  Text(card.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: c.text)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _title(card),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.muted),
                    ),
                  ),
                  if (card.whichDetail() == pb.ToolCard_Detail.edit) ...[
                    Text('+${card.edit.added}', style: TextStyle(fontSize: 12, color: c.success)),
                    const SizedBox(width: 4),
                    Text('−${card.edit.removed}', style: TextStyle(fontSize: 12, color: c.danger)),
                    const SizedBox(width: 8),
                  ],
                  if (running)
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: c.accent))
                  else if (failed)
                    Icon(Icons.error_outline_rounded, size: 16, color: c.danger)
                  else
                    Icon(Icons.check_rounded, size: 16, color: c.success),
                  const SizedBox(width: 4),
                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: c.faint),
                ],
              ),
            ),
          ),
          if (_open) ...[
            Divider(height: 1, color: c.border),
            Padding(padding: const EdgeInsets.all(12), child: ToolDetail(card: card)),
          ],
        ],
      ),
    );
  }

  String _title(pb.ToolCard card) {
    if (card.title == card.name) return '';
    return card.whichDetail() == pb.ToolCard_Detail.edit ||
            card.whichDetail() == pb.ToolCard_Detail.write ||
            card.whichDetail() == pb.ToolCard_Detail.read
        ? baseName(card.title)
        : card.title;
  }
}

IconData toolIcon(pb.ToolCard card) => switch (card.whichDetail()) {
      pb.ToolCard_Detail.shell => Icons.terminal_rounded,
      pb.ToolCard_Detail.edit => Icons.edit_note_rounded,
      pb.ToolCard_Detail.write => Icons.note_add_outlined,
      pb.ToolCard_Detail.read => Icons.description_outlined,
      pb.ToolCard_Detail.search => Icons.search_rounded,
      pb.ToolCard_Detail.todos => Icons.checklist_rounded,
      pb.ToolCard_Detail.agent => Icons.hub_outlined,
      pb.ToolCard_Detail.web => Icons.public_rounded,
      _ => Icons.extension_outlined,
    };

/// The expanded body of a tool card; also used in approval sheets.
class ToolDetail extends StatelessWidget {
  const ToolDetail({super.key, required this.card});

  final pb.ToolCard card;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parts = <Widget>[];
    switch (card.whichDetail()) {
      case pb.ToolCard_Detail.shell:
        parts.add(CodeBox(code: card.shell.command, lang: card.shell.shell));
      case pb.ToolCard_Detail.edit:
        parts.add(_label(context, card.edit.path));
        parts.add(DiffView(diff: card.edit.unifiedDiff));
      case pb.ToolCard_Detail.write:
        parts.add(_label(context, '${card.write.path} · ${card.write.lines} lines'));
        parts.add(CodeBox(code: card.write.preview, lang: _ext(card.write.path), maxHeight: 280));
      case pb.ToolCard_Detail.read:
        final r = card.read;
        parts.add(_label(context, r.path + (r.offset > 0 || r.limit > 0 ? ' · lines ${r.offset}–${r.offset + r.limit}' : '')));
      case pb.ToolCard_Detail.search:
        final s = card.search;
        parts.add(_label(context, [s.pattern, if (s.path.isNotEmpty) 'in ${s.path}', if (s.glob.isNotEmpty) s.glob].join('  ')));
      case pb.ToolCard_Detail.todos:
        parts.add(TodoChecklist(todos: [
          for (final t in card.todos.todos)
            TodoItem(
              content: t.content,
              activeForm: t.activeForm,
              status: switch (t.status) {
                pbe.Todo_Status.STATUS_COMPLETED => TodoStatus.completed,
                pbe.Todo_Status.STATUS_IN_PROGRESS => TodoStatus.inProgress,
                _ => TodoStatus.pending,
              },
            ),
        ]));
      case pb.ToolCard_Detail.agent:
        parts.add(_label(context, [card.agent.subagentType, card.agent.description].where((s) => s.isNotEmpty).join(' · ')));
        if (card.agent.prompt.isNotEmpty) {
          parts.add(Text(card.agent.prompt, style: TextStyle(color: c.muted, fontSize: 13), maxLines: 8, overflow: TextOverflow.ellipsis));
        }
      case pb.ToolCard_Detail.web:
        parts.add(_label(context, card.web.url.isNotEmpty ? card.web.url : card.web.query));
      case pb.ToolCard_Detail.generic:
        parts.add(CodeBox(code: card.generic.inputJson, lang: 'json', maxHeight: 240));
      case pb.ToolCard_Detail.notSet:
        break;
    }
    final out = card.output;
    if (card.hasOutput() && out.text.trim().isNotEmpty && card.whichDetail() != pb.ToolCard_Detail.edit) {
      parts.add(_OutputBox(output: out));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final p in parts) Padding(padding: const EdgeInsets.only(bottom: 8), child: p)],
    );
  }

  static String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i < 0 ? '' : path.substring(i + 1);
  }

  Widget _label(BuildContext context, String text) =>
      SelectableText(text, style: monoStyle(context, size: 12, color: context.colors.muted));
}

class _OutputBox extends StatelessWidget {
  const _OutputBox({required this.output});

  final pb.ToolOutput output;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: c.codeBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: output.isError ? c.danger.withValues(alpha: 0.4) : c.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            output.text,
            style: monoStyle(context, size: 12, color: output.isError ? c.danger : c.muted),
          ),
        ),
      ),
    );
  }
}

class DiffView extends StatelessWidget {
  const DiffView({super.key, required this.diff});

  final String diff;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = const LineSplitter().convert(diff).where((l) => !l.startsWith('+++') && !l.startsWith('---')).toList();
    return Container(
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in lines)
                Container(
                  color: l.startsWith('+')
                      ? c.diffAdd
                      : l.startsWith('-')
                          ? c.diffRemove
                          : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                  child: Text(
                    l.isEmpty ? ' ' : l,
                    style: monoStyle(context, size: 12, color: l.startsWith('@@') ? c.info : c.text),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
