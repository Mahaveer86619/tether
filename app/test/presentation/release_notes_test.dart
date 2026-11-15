import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/presentation/theme/theme.dart';
import 'package:tether/presentation/update/release_notes.dart';

void main() {
  test('bullets with a bold title and code are read apart', () {
    final items = parseReleaseNotes('''
## 0.17.9

- **Smoother.** Opening it from the recents no longer says `offline`.
- Plain bullet.

A closing paragraph.
''');
    expect(items, hasLength(3));
    expect(items[0].bullet, isTrue);
    expect(items[0].spans, [const NoteSpan('Smoother.', bold: true), const NoteSpan(' Opening it from the recents no longer says '), const NoteSpan('offline', code: true), const NoteSpan('.')]);
    expect(items[1].spans, [const NoteSpan('Plain bullet.')]);
    expect(items[2].bullet, isFalse);
  });

  test('headings and blank lines are left out, and nothing at all is nothing', () {
    expect(parseReleaseNotes(''), isEmpty);
    expect(parseReleaseNotes('\n\n# Title\n\n'), isEmpty);
  });

  testWidgets('the notes show without their Markdown marks, one dot per change', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: const Scaffold(body: ReleaseNotesView(notes: '- **Smoother.** Works with `code`.\n- Second change.'))));
    final text = tester.widgetList<SelectableText>(find.byType(SelectableText)).map((t) => t.textSpan!.toPlainText()).toList();
    expect(text, ['Smoother. Works with code.', 'Second change.']);
    expect(find.textContaining('**', findRichText: true), findsNothing);
  });

  testWidgets('with no notes it says so', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: const Scaffold(body: ReleaseNotesView(notes: ''))));
    expect(find.text('No notes for this release.'), findsOneWidget);
  });
}
