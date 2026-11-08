import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/gen/tether/v1/render.pb.dart';
import 'package:tether/presentation/widgets/changes_pane.dart';
import 'package:tether/presentation/widgets/terminal_view.dart';

Span _s(String t) => Span(text: t);

Block _p(String t) => Block(paragraph: Paragraph(spans: [_s(t)]));

void main() {
  test('a conversation reads as a terminal transcript', () {
    final lines = transcriptLines([
      TimelineItem(itemId: 'u', user: UserText(text: 'fix the retries\nand add a test')),
      TimelineItem(itemId: 'a', markdown: Markdown(blocks: [
        Block(paragraph: Paragraph(spans: [_s('Looking at '), Span(text: 'webhook.go', code: true)])),
        Block(list: ListBlock(items: [
          ListItem(checked: true, blocks: [_p('tests pass')]),
          ListItem(checked: false, blocks: [_p('deploy')]),
          ListItem(blocks: [_p('plain')]),
        ])),
      ])),
      TimelineItem(itemId: 't', tool: ToolCard(name: 'Bash', title: 'go test', status: ToolCard_Status.STATUS_SUCCEEDED, output: ToolOutput(text: 'ok\nok2\nok3\nok4\nok5'))),
      TimelineItem(itemId: 'r', result: ResultSummary(durationMs: Int64(125000), numTurns: 3, costUsd: 0.5)),
    ]);
    expect([for (final l in lines) l.text], [
      '> fix the retries',
      '  and add a test',
      '',
      'Looking at webhook.go',
      '[x] tests pass',
      '[ ] deploy',
      '• plain',
      '',
      '● Bash(go test)',
      '  └ ok',
      '    ok2',
      '    ok3',
      '    … 2 more lines',
      '',
      '── finished · 2m 5s · 3 turns · \$0.50',
    ]);
    expect(lines.first.kind, TermKind.prompt);
    expect(lines.firstWhere((l) => l.text == '● Bash(go test)').kind, TermKind.toolOk);
  });

  test('a table is drawn with box characters, columns as wide as their widest cell', () {
    final lines = transcriptLines([
      TimelineItem(itemId: 'a', markdown: Markdown(blocks: [
        Block(table: Table(
          align: [Table_Align.ALIGN_LEFT, Table_Align.ALIGN_RIGHT],
          header: [TableCell(spans: [_s('File')]), TableCell(spans: [_s('Lines')])],
          rows: [
            TableRow(cells: [TableCell(spans: [_s('webhook.go')]), TableCell(spans: [_s('120')])]),
            TableRow(cells: [TableCell(spans: [_s('a.go')]), TableCell(spans: [_s('7')])]),
          ],
        )),
      ])),
    ]);
    expect([for (final l in lines) l.text], [
      '┌────────────┬───────┐',
      '│ File       │ Lines │',
      '├────────────┼───────┤',
      '│ webhook.go │   120 │',
      '│ a.go       │     7 │',
      '└────────────┴───────┘',
    ]);
    expect(lines[1].kind, TermKind.tableHeader);
    expect(lines[3].kind, TermKind.tableRow);
  });

  test('code is framed with its language, an edit shows its diff, a write its text, and to-dos their state', () {
    final lines = transcriptLines([
      TimelineItem(itemId: 'a', markdown: Markdown(blocks: [Block(code: CodeBlock(lang: 'go', text: 'x := 1'))])),
      TimelineItem(itemId: 'e', tool: ToolCard(
        name: 'Edit',
        title: 'a.go',
        status: ToolCard_Status.STATUS_SUCCEEDED,
        edit: EditCard(path: 'a.go', added: 1, removed: 1, unifiedDiff: '--- a/a.go\n+++ b/a.go\n@@ -1 +1 @@\n-old()\n+fresh()\n'),
      )),
      TimelineItem(itemId: 'w', tool: ToolCard(name: 'Write', title: 'b.dart', status: ToolCard_Status.STATUS_SUCCEEDED, write: WriteCard(path: 'b.dart', lines: 2, preview: 'void main() {}\nvoid x() {}'))),
      TimelineItem(itemId: 'd', tool: ToolCard(name: 'TodoWrite', status: ToolCard_Status.STATUS_SUCCEEDED, todos: TodoCard(todos: [
        Todo(content: 'write tests', status: Todo_Status.STATUS_COMPLETED),
        Todo(content: 'ship it', activeForm: 'shipping it', status: Todo_Status.STATUS_IN_PROGRESS),
        Todo(content: 'celebrate', status: Todo_Status.STATUS_PENDING),
      ]))),
    ]);
    final text = [for (final l in lines) l.text];
    expect(text, containsAllInOrder(['┌─ go', '│ x := 1', '└─']));
    expect(lines.firstWhere((l) => l.text == '│ x := 1').lang, 'go');
    expect(text, containsAllInOrder(['  └ +1 −1', '    @@ -1 +1 @@', '    -old()', '    +fresh()']));
    expect(lines.firstWhere((l) => l.text == '    -old()').kind, TermKind.diffRemove);
    expect(lines.firstWhere((l) => l.text == '    +fresh()').kind, TermKind.diffAdd);
    expect(text, containsAllInOrder(['  └ wrote 2 lines', '    void main() {}']));
    expect(lines.firstWhere((l) => l.text == '    void main() {}').lang, 'dart');
    expect(text, containsAllInOrder(['  [x] write tests', '  [>] shipping it', '  [ ] celebrate']));
  });

  test('nothing in, nothing out', () => expect(transcriptLines(const []), isEmpty));

  group('fileChanges', () {
    TimelineItem edit(String id, String path, {int added = 1, int removed = 0, ToolCard_Status status = ToolCard_Status.STATUS_SUCCEEDED}) =>
        TimelineItem(itemId: id, tool: ToolCard(name: 'Edit', status: status, edit: EditCard(path: path, added: added, removed: removed, unifiedDiff: '@@\n+x\n')));

    test('gathers the changes to each file in order, and knows which file was touched last', () {
      final files = fileChanges([
        edit('1', '/src/a.go'),
        edit('2', '/src/b.go', added: 3, removed: 1),
        edit('3', '/src/a.go', added: 2),
        TimelineItem(itemId: '4', tool: ToolCard(name: 'Write', status: ToolCard_Status.STATUS_SUCCEEDED, write: WriteCard(path: '/src/c.dart', lines: 9, preview: 'x'))),
        TimelineItem(itemId: '5', user: UserText(text: 'ignored')),
        edit('6', '/src/d.go', status: ToolCard_Status.STATUS_FAILED),
      ]);
      expect([for (final f in files) f.name], ['a.go', 'b.go', 'c.dart']);
      expect(files[0].chunks.length, 2);
      expect((files[0].added, files[0].removed), (3, 0));
      expect((files[1].added, files[1].removed), (3, 1));
      expect(files[2].chunks.single.created, isTrue);
      expect(files[2].lang, 'dart');
      expect(files.reduce((a, b) => a.lastTouched >= b.lastTouched ? a : b).name, 'c.dart');
    });

    test('a running edit marks its file as in progress', () {
      final files = fileChanges([edit('1', 'a.go', status: ToolCard_Status.STATUS_RUNNING)]);
      expect(files.single.running, isTrue);
    });

    test('no edits, no files', () => expect(fileChanges(const []), isEmpty));
  });
}
