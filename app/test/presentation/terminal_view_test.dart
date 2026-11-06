import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/gen/tether/v1/render.pb.dart';
import 'package:tether/presentation/widgets/terminal_view.dart';

Span _s(String t) => Span(text: t);

void main() {
  test('a conversation reads as a terminal transcript', () {
    final lines = transcriptLines([
      TimelineItem(itemId: 'u', user: UserText(text: 'fix the retries\nand add a test')),
      TimelineItem(itemId: 'a', markdown: Markdown(blocks: [
        Block(paragraph: Paragraph(spans: [_s('Looking at '), Span(text: 'webhook.go', code: true)])),
        Block(list: ListBlock(items: [
          ListItem(checked: true, blocks: [Block(paragraph: Paragraph(spans: [_s('tests pass')]))]),
          ListItem(checked: false, blocks: [Block(paragraph: Paragraph(spans: [_s('deploy')]))]),
        ])),
      ])),
      TimelineItem(itemId: 't', tool: ToolCard(name: 'Bash', title: 'go test', status: ToolCard_Status.STATUS_SUCCEEDED, output: ToolOutput(text: 'ok\nok2\nok3\nok4\nok5'))),
      TimelineItem(itemId: 'e', tool: ToolCard(name: 'Edit', title: 'a.go', status: ToolCard_Status.STATUS_FAILED, edit: EditCard(added: 2, removed: 1))),
      TimelineItem(itemId: 'r', result: ResultSummary(durationMs: Int64(125000), numTurns: 3, costUsd: 0.5)),
    ]);
    expect([for (final l in lines) l.text], [
      '> fix the retries',
      '  and add a test',
      '',
      'Looking at webhook.go',
      '[x] tests pass',
      '[ ] deploy',
      '',
      '● Bash(go test)',
      '  └ ok',
      '    ok2',
      '    ok3',
      '    … 2 more lines',
      '',
      '● Edit(a.go)',
      '  └ +2 −1',
      '',
      '── finished · 2m 5s · 3 turns · \$0.50',
    ]);
    expect(lines.first.kind, TermKind.prompt);
    expect(lines.firstWhere((l) => l.text == '● Edit(a.go)').kind, TermKind.toolFailed);
    expect(lines.firstWhere((l) => l.text == '● Bash(go test)').kind, TermKind.toolOk);
  });

  test('nothing in, nothing out', () => expect(transcriptLines(const []), isEmpty));
}
