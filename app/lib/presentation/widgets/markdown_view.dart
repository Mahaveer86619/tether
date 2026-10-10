import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../gen/tether/v1/render.pb.dart' as pb;
import '../../gen/tether/v1/render.pbenum.dart' as pbe;
import '../theme/theme.dart';

/// Renders the hub's parsed Markdown blocks. The hub did the parsing, so
/// this only maps block types to widgets.
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.blocks, this.streaming = false});

  final List<pb.Block> blocks;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 12));
      children.add(BlockView(block: blocks[i], cursor: streaming && i == blocks.length - 1));
    }
    if (blocks.isEmpty && streaming) children.add(const _Cursor());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class BlockView extends StatelessWidget {
  const BlockView({super.key, required this.block, this.cursor = false});

  final pb.Block block;
  final bool cursor;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyLarge!;
    switch (block.whichKind()) {
      case pb.Block_Kind.heading:
        final h = block.heading;
        final size = switch (h.level) { 1 => 22.0, 2 => 19.0, 3 => 17.0, _ => 15.5 };
        return Padding(
          padding: EdgeInsets.only(top: h.level <= 2 ? 6 : 2),
          child: SpanText(spans: h.spans, style: body.copyWith(fontSize: size, fontWeight: FontWeight.w600, height: 1.35), cursor: cursor),
        );
      case pb.Block_Kind.paragraph:
        return SpanText(spans: block.paragraph.spans, style: body, cursor: cursor);
      case pb.Block_Kind.list:
        return _ListView(list: block.list);
      case pb.Block_Kind.code:
        return CodeBox(code: block.code.text, lang: block.code.lang);
      case pb.Block_Kind.table:
        return _TableView(table: block.table);
      case pb.Block_Kind.quote:
        return Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: context.colors.border, width: 3))),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: context.colors.muted),
            child: MarkdownView(blocks: block.quote.blocks),
          ),
        );
      case pb.Block_Kind.divider:
        return const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider());
      case pb.Block_Kind.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            block.image.url,
            errorBuilder: (_, _, _) => Text('[image: ${block.image.alt}]', style: TextStyle(color: context.colors.muted)),
          ),
        );
      case pb.Block_Kind.notSet:
        return const SizedBox.shrink();
    }
  }
}

/// Inline text with bold, italic, code, strike and links.
class SpanText extends StatelessWidget {
  const SpanText({super.key, required this.spans, required this.style, this.cursor = false});

  final List<pb.Span> spans;
  final TextStyle style;
  final bool cursor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final children = <InlineSpan>[
      for (final s in spans)
        TextSpan(
          text: s.text,
          style: TextStyle(
            fontWeight: s.bold ? FontWeight.w600 : null,
            fontStyle: s.italic ? FontStyle.italic : null,
            decoration: s.strike ? TextDecoration.lineThrough : (s.link.isNotEmpty ? TextDecoration.underline : null),
            decorationColor: s.link.isNotEmpty ? c.accent.withValues(alpha: 0.5) : null,
            color: s.link.isNotEmpty ? c.accent : null,
            fontFamily: s.code ? monoFont : null,
            fontFamilyFallback: s.code ? monoFallback : null,
            fontSize: s.code ? style.fontSize! * 0.88 : null,
            backgroundColor: s.code ? c.codeBg : null,
          ),
          recognizer: s.link.isNotEmpty ? (TapGestureRecognizer()..onTap = () => _open(s.link)) : null,
        ),
      if (cursor) const WidgetSpan(alignment: PlaceholderAlignment.middle, child: _Cursor()),
    ];
    return Text.rich(TextSpan(style: style, children: children));
  }

  static void _open(String link) {
    final uri = Uri.tryParse(link);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.list});

  final pb.ListBlock list;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = Theme.of(context).textTheme.bodyLarge!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < list.items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 26,
                  child: list.items[i].hasChecked()
                      ? Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Icon(
                            list.items[i].checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: list.items[i].checked ? c.success : c.faint,
                          ),
                        )
                      : Text(list.ordered ? '${list.start + i}.' : '•', style: body.copyWith(color: c.muted)),
                ),
                Expanded(child: MarkdownView(blocks: list.items[i].blocks)),
              ],
            ),
          ),
      ],
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.table});

  final pb.Table table;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = Theme.of(context).textTheme.bodyMedium!;
    final cols = [table.header.length, ...table.rows.map((r) => r.cells.length)].reduce((a, b) => a > b ? a : b);
    TextAlign align(int i) => switch (i < table.align.length ? table.align[i] : pbe.Table_Align.ALIGN_UNSPECIFIED) {
          pbe.Table_Align.ALIGN_CENTER => TextAlign.center,
          pbe.Table_Align.ALIGN_RIGHT => TextAlign.right,
          _ => TextAlign.left,
        };
    TableRow row(List<pb.TableCell> cells, {bool header = false}) => TableRow(
          decoration: header ? BoxDecoration(color: c.raised) : null,
          children: [
            for (var i = 0; i < cols; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: i < cells.length
                    ? DefaultTextStyle.merge(
                        textAlign: align(i),
                        child: SpanText(spans: cells[i].spans, style: body.copyWith(fontWeight: header ? FontWeight.w600 : null)),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        );
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(horizontalInside: BorderSide(color: c.border), verticalInside: BorderSide(color: c.border)),
            children: [row(table.header, header: true), for (final r in table.rows) row(r.cells)],
          ),
        ),
      ),
    );
  }
}

/// A code block with its language and a copy button.
class CodeBox extends StatelessWidget {
  const CodeBox({super.key, required this.code, this.lang = '', this.maxHeight});

  final String code;
  final String lang;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget text = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: SelectableText(code, style: monoStyle(context, size: 12.5)),
    );
    if (maxHeight != null) {
      text = ConstrainedBox(constraints: BoxConstraints(maxHeight: maxHeight!), child: SingleChildScrollView(child: text));
    }
    return Container(
      decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 0),
            child: Row(
              children: [
                Text(lang.isEmpty ? 'text' : lang, style: TextStyle(color: c.faint, fontSize: 12)),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  color: c.faint,
                  icon: const Icon(Icons.content_copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
                  },
                ),
              ],
            ),
          ),
          text,
        ],
      ),
    );
  }
}

class _Cursor extends StatefulWidget {
  const _Cursor();

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: Container(
          width: 8,
          height: 16,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(color: context.colors.accent, borderRadius: BorderRadius.circular(2)),
        ),
      );
}
