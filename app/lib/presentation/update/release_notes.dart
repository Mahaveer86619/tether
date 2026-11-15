import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../ui/tokens.dart';

/// One line of a release's notes: a bullet with a title and what it says, or a plain paragraph.
class NoteItem {
  const NoteItem({required this.spans, this.bullet = true});

  final List<NoteSpan> spans;
  final bool bullet;
}

class NoteSpan {
  const NoteSpan(this.text, {this.bold = false, this.code = false});

  final String text;
  final bool bold, code;

  @override
  bool operator ==(Object other) => other is NoteSpan && other.text == text && other.bold == bold && other.code == code;

  @override
  int get hashCode => Object.hash(text, bold, code);

  @override
  String toString() => '${bold ? '**' : ''}${code ? '`' : ''}$text${code ? '`' : ''}${bold ? '**' : ''}';
}

/// Reads a release's notes, which are a small piece of Markdown: bullets
/// starting with a bold title, `code`, and the odd paragraph. Headings and
/// blank lines are left out.
List<NoteItem> parseReleaseNotes(String notes) {
  final items = <NoteItem>[];
  for (final raw in notes.split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final bullet = RegExp(r'^\s*[-*]\s+').hasMatch(line);
    final text = line.replaceFirst(RegExp(r'^\s*[-*]\s+'), '').trim();
    items.add(NoteItem(spans: _spans(text), bullet: bullet));
  }
  return items;
}

List<NoteSpan> _spans(String text) {
  final out = <NoteSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
  var at = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > at) out.add(NoteSpan(text.substring(at, m.start)));
    if (m.group(1) != null) {
      out.add(NoteSpan(m.group(1)!, bold: true));
    } else {
      out.add(NoteSpan(m.group(2)!, code: true));
    }
    at = m.end;
  }
  if (at < text.length) out.add(NoteSpan(text.substring(at)));
  return out;
}

/// A release's notes, laid out to be read: a dot for each change, its title
/// in bold, then what it means, in a quieter colour.
class ReleaseNotesView extends StatelessWidget {
  const ReleaseNotesView({super.key, required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = parseReleaseNotes(notes);
    if (items.isEmpty) return Text('No notes for this release.', style: TextStyle(color: c.muted));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (it.bullet)
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                  ),
                Expanded(
                  child: SelectableText.rich(
                    TextSpan(
                      children: [
                        for (final s in it.spans)
                          TextSpan(
                            text: s.text,
                            style: s.bold
                                ? TextStyle(color: c.text, fontWeight: FontWeight.w600)
                                : s.code
                                    ? monoStyle(context, size: 12.5, color: c.text).copyWith(backgroundColor: c.raised)
                                    : null,
                          ),
                      ],
                    ),
                    style: TextStyle(fontSize: 13.5, height: 1.5, color: c.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
