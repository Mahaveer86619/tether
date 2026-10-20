import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/gen/tether/v1/render.pbenum.dart' as rpbe;
import 'package:tether/injection.dart';
import 'package:tether/presentation/app.dart';
import 'package:tether/presentation/home/cards.dart';
import 'package:tether/presentation/home/session_navigator.dart';
import 'package:tether/presentation/theme/syntax.dart';
import 'package:tether/presentation/theme/theme.dart';
import 'package:tether/presentation/widgets/timeline_item_view.dart';

import '../helpers/fakes.dart';

Widget themed(Widget child) => MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: SingleChildScrollView(child: child)));

/// Busy sessions pulse forever, so pumpAndSettle never returns; pump a
/// fixed number of frames instead.
/// A session's card on the overview, or its row in the sidebar.
Finder sessionCard(String id) => find.ancestor(of: find.text('Session $id'), matching: find.byWidgetPredicate((w) => w is CardShell || w is SessionTile)).first;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

rpb.Span span(String t, {bool bold = false, bool code = false}) => rpb.Span(text: t, bold: bold, code: code);

void main() {
  testWidgets('renders markdown blocks: heading, list, table, code', (tester) async {
    final item = rpb.TimelineItem(
      itemId: 'm',
      markdown: rpb.Markdown(blocks: [
        rpb.Block(heading: rpb.Heading(level: 2, spans: [span('Summary')])),
        rpb.Block(paragraph: rpb.Paragraph(spans: [span('Updated '), span('main.go', code: true)])),
        rpb.Block(list: rpb.ListBlock(items: [
          rpb.ListItem(checked: true, blocks: [rpb.Block(paragraph: rpb.Paragraph(spans: [span('tests pass')]))]),
        ])),
        rpb.Block(
          table: rpb.Table(
            header: [rpb.TableCell(spans: [span('File')]), rpb.TableCell(spans: [span('Status')])],
            rows: [rpb.TableRow(cells: [rpb.TableCell(spans: [span('a.go')]), rpb.TableCell(spans: [span('ok', bold: true)])])],
          ),
        ),
        rpb.Block(code: rpb.CodeBlock(lang: 'go', text: 'fmt.Println(1)')),
      ]),
    );
    await tester.pumpWidget(themed(TimelineItemView(item: item)));
    expect(find.text('Summary'), findsOneWidget);
    expect(find.textContaining('main.go', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.textContaining('a.go', findRichText: true), findsOneWidget);
    expect(find.textContaining('fmt.Println(1)', findRichText: true), findsOneWidget);
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('tool cards collapse to one line and expand to details', (tester) async {
    final item = rpb.TimelineItem(
      itemId: 't',
      tool: rpb.ToolCard(
        toolUseId: 't',
        name: 'Edit',
        title: '/srv/app/main.go',
        status: rpbe.ToolCard_Status.STATUS_SUCCEEDED,
        edit: rpb.EditCard(path: '/srv/app/main.go', unifiedDiff: '@@ -1 +1 @@\n-old\n+new\n', added: 1, removed: 1),
      ),
    );
    await tester.pumpWidget(themed(TimelineItemView(item: item)));
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('main.go'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+new'), findsNothing);
    await tester.tap(find.text('Edit'));
    await tester.pump();
    expect(find.text('+new'), findsOneWidget);
    expect(find.text('-old'), findsOneWidget);
  });

  test('code is coloured by the theme; unknown languages stay plain', () {
    const syntax = SyntaxColors(
      keyword: Color(0xFF000001),
      string: Color(0xFF000002),
      number: Color(0xFF000003),
      comment: Color(0xFF000004),
      function: Color(0xFF000005),
      type: Color(0xFF000006),
      variable: Color(0xFF000007),
      meta: Color(0xFF000008),
    );
    final spans = highlightCode('func main() { return "hi" }', 'golang', syntax)!;
    final colours = <Color?>{};
    void walk(InlineSpan s) {
      if (s is TextSpan) {
        colours.add(s.style?.color);
        s.children?.forEach(walk);
      }
    }
    spans.forEach(walk);
    expect(colours, containsAll([syntax.keyword, syntax.string]));
    expect(highlightCode('x', 'no-such-language', syntax), isNull);
  });

  group('app', () {
    late FakeHubRepository repo;
    late FakeSettingsRepository settings;
    late FakeTransferRepository transfers;

    setUp(() async {
      await sl.reset();
      transfers = FakeTransferRepository();
      repo = FakeHubRepository(snapshotWith([
        session('s1'),
        session('t1', node: 'laptop', host: SessionHost.terminal, state: SessionState.running),
      ], approvals: [
        Approval(
          id: 'ap',
          session: 's1',
          node: 'minipc',
          kind: ApprovalKind.tool,
          toolName: 'Bash',
          preview: rpb.ToolCard(name: 'Bash', shell: rpb.ShellCard(command: 'rm -rf build')),
          created: DateTime(2026),
        ),
      ]));
      settings = FakeSettingsRepository()..saved = const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 't');
      sl
        ..registerSingleton<HubRepository>(repo)
        ..registerSingleton<TransferRepository>(transfers)
        ..registerSingleton<SettingsRepository>(settings);
      configureDependencies(withData: false);
    });

    Future<void> pumpApp(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TetherApp());
      await settle(tester);
    }

    testWidgets('desktop: overview, approve from the dashboard, open a session and send', (tester) async {
      await pumpApp(tester, const Size(1400, 900));

      expect(find.text('Tether'), findsOneWidget);
      expect(find.text('NEEDS YOU'), findsOneWidget);
      expect(find.text('rm -rf build'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
      await tester.pump();
      expect(repo.decided.single, ('ap', true));

      await tester.tap(sessionCard('s1'));
      await settle(tester);
      repo.emitTimeline('s1', [rpb.TimelineItem(itemId: 'u', ord: Int64(1), user: rpb.UserText(text: 'earlier prompt'))]);
      await settle(tester);
      expect(find.text('earlier prompt'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('composer')), 'next step');
      await tester.pump();
      await tester.tap(find.byKey(const Key('send')));
      await settle(tester);
      expect(repo.sent.single, ('s1', 'next step', false));
      expect(find.text('next step'), findsNothing, reason: 'composer clears after sending');
    });

    testWidgets('desktop: a terminal session offers fork instead of typing', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(sessionCard('t1'));
      await settle(tester);
      expect(find.textContaining('Open in a terminal on laptop'), findsOneWidget);
      expect(find.byKey(const Key('composer')), findsNothing);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Fork'));
      await settle(tester);
      expect(find.text('Fork this session'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-fork')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('composer')), 'carry on');
      await tester.pump();
      await tester.tap(find.byKey(const Key('send')));
      await settle(tester);
      expect(repo.sent.single, ('t1', 'carry on', true));
    });

    testWidgets('desktop: interrupt a working session, end it after confirming', (tester) async {
      repo.emitHub(snapshotWith([session('s1', state: SessionState.running)]));
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(sessionCard('s1'));
      await settle(tester);
      expect(find.text('Claude is working'), findsOneWidget);

      await tester.tap(find.byKey(const Key('interrupt')));
      await settle(tester);
      expect(repo.interrupted, ['s1']);

      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('end-session')));
      await settle(tester);
      expect(find.text('End this session?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-end')));
      await settle(tester);
      expect(repo.ended, ['s1']);
    });

    testWidgets('desktop: a Windows terminal session can be typed into directly', (tester) async {
      repo.emitHub(snapshotWith([
        const Session(id: 'w1', node: 'laptop', title: 'Session w1', host: SessionHost.terminal, state: SessionState.ready, terminalInput: true),
      ]));
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(sessionCard('w1'));
      await settle(tester);
      expect(find.textContaining('typed into your terminal on laptop'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('composer')), 'from the app');
      await tester.pump();
      await tester.tap(find.byKey(const Key('send')));
      await settle(tester);
      expect(repo.sent.single, ('w1', 'from the app', false));
    });

    testWidgets('new messages animate in; history does not', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(sessionCard('s1'));
      await settle(tester);
      repo.emitTimeline('s1', [rpb.TimelineItem(itemId: 'old', ord: Int64(1), user: rpb.UserText(text: 'history'))]);
      await settle(tester);
      repo.emitTimeline('s1', [
        rpb.TimelineItem(itemId: 'old', ord: Int64(1), user: rpb.UserText(text: 'history')),
        rpb.TimelineItem(itemId: 'new', ord: Int64(2), user: rpb.UserText(text: 'fresh')),
      ], version: 2);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 10));
      final fade = tester.widget<Opacity>(find.ancestor(of: find.text('fresh'), matching: find.byType(Opacity)).first);
      expect(fade.opacity, lessThan(1));
      final old = tester.widget<Opacity>(find.ancestor(of: find.text('history'), matching: find.byType(Opacity)).first);
      expect(old.opacity, 1);
      await settle(tester);
    });

    testWidgets('consecutive tool calls fold into one group', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(sessionCard('s1'));
      await settle(tester);
      rpb.TimelineItem tool(String id, String name) => rpb.TimelineItem(
            itemId: id,
            tool: rpb.ToolCard(toolUseId: id, name: name, title: 'step $id', status: rpbe.ToolCard_Status.STATUS_SUCCEEDED),
          );
      repo.emitTimeline('s1', [
        rpb.TimelineItem(itemId: 'u', user: rpb.UserText(text: 'go')),
        tool('a', 'Bash'),
        tool('b', 'Bash'),
        tool('c', 'Read'),
        rpb.TimelineItem(itemId: 'm', markdown: rpb.Markdown(blocks: [])),
        tool('d', 'Edit'),
      ]);
      await settle(tester);
      expect(find.textContaining('Ran 3 steps', findRichText: true), findsOneWidget);
      expect(find.text('step a'), findsNothing);
      expect(find.text('step d'), findsOneWidget, reason: 'a lone tool call keeps its own card');
      await tester.tap(find.textContaining('Ran 3 steps', findRichText: true));
      await settle(tester);
      expect(find.text('step a'), findsOneWidget);
    });

    testWidgets('a queued message stays at the end until taken in; removed items vanish', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(sessionCard('s1'));
      await settle(tester);
      repo.emitTimeline('s1', [
        rpb.TimelineItem(itemId: 'q', ord: Int64(1), user: rpb.UserText(text: 'also check adb', queued: true)),
        rpb.TimelineItem(itemId: 'm', ord: Int64(2), user: rpb.UserText(text: 'earlier answer')),
        rpb.TimelineItem(itemId: 'gone', ord: Int64(3)),
      ]);
      await settle(tester);
      expect(find.textContaining('Queued'), findsOneWidget);
      final queuedY = tester.getTopLeft(find.text('also check adb')).dy;
      expect(queuedY, greaterThan(tester.getTopLeft(find.text('earlier answer')).dy), reason: 'queued messages sit below newer items');
    });

    testWidgets('settings: add a device shows a QR code; paired devices can be revoked', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      expect(find.text('Pixel'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-device')));
      await settle(tester);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('ABCDE-FGHJK'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Revoke'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
      await settle(tester);
      expect(find.text('Pixel'), findsNothing);
    });

    testWidgets("Claude's questions are answered from a card, with choices or your own words", (tester) async {
      const input = '{"questions":['
          '{"question":"Which DB?","header":"DB","multiSelect":false,"options":[{"label":"Postgres","description":"server"},{"label":"SQLite"}]},'
          '{"question":"Which parts?","header":"Scope","multiSelect":true,"options":[{"label":"API"},{"label":"Web"}]}]}';
      repo.emitHub(snapshotWith([session('s1')], approvals: [
        Approval(id: 'q', session: 's1', node: 'minipc', kind: ApprovalKind.question, toolName: 'AskUserQuestion', inputJson: input, created: DateTime(2026)),
      ]));
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(sessionCard('s1'));
      await settle(tester);
      expect(find.byKey(const Key('question-card')), findsWidgets);
      final card = find.byKey(const Key('question-card')).last;
      final answer = find.descendant(of: card, matching: find.byKey(const Key('answer-questions')));
      expect(tester.widget<FilledButton>(answer).onPressed, isNull, reason: 'every question needs an answer first');

      await tester.tap(find.descendant(of: card, matching: find.text('Postgres')));
      await tester.tap(find.descendant(of: card, matching: find.text('API')));
      await tester.tap(find.descendant(of: card, matching: find.text('Web')));
      await tester.pump();
      await tester.tap(answer);
      await tester.pump();
      expect(repo.answered.last, {'Which DB?': 'Postgres', 'Which parts?': 'API, Web'});
    });

    testWidgets('pages sessions made are listed under Files → Pages, ready to open', (tester) async {
      repo.hostedPages = [HostedPage(session: 's1', name: 'demo', files: 3, updated: DateTime(2026), url: 'http://hub/p/s1/demo/1/x/index.html')];
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(find.text('Files').first);
      await settle(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pages'));
      await settle(tester);
      expect(find.text('demo'), findsOneWidget);
      expect(find.byKey(const Key('open-page-demo')), findsOneWidget);
      expect(find.textContaining('3 files'), findsOneWidget);
    });

    testWidgets('settings: codebases show their copy on the hub and .env key names, and can be snapshotted', (tester) async {
      repo.codebaseList = [
        Codebase(
          id: 'cb1',
          node: 'laptop',
          path: r'C:\code\shop',
          name: 'shop',
          gitBranch: 'main',
          lastSnapshot: DateTime(2026),
          files: 120,
          bytes: 2 << 20,
          env: const [EnvFileInfo(path: 'server/.env', keys: ['DB_URL', 'API_KEY'])],
        ),
      ];
      await pumpApp(tester, const Size(1400, 1600));
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('shop'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('120 files'), findsOneWidget);
      await tester.tap(find.text('shop'));
      await settle(tester);
      expect(find.text('DB_URL'), findsOneWidget);
      expect(find.text('server/.env'), findsOneWidget);
      await tester.tap(find.byKey(const Key('snapshot-shop')));
      await settle(tester);
      expect(repo.snapshotted, ['cb1']);
      expect(find.text('Copying…'), findsOneWidget);
    });

    testWidgets('a long message shows its first lines until expanded', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(sessionCard('s1'));
      await settle(tester);
      final long = [for (var i = 1; i <= 30; i++) 'line $i'].join('\n');
      repo.emitTimeline('s1', [rpb.TimelineItem(itemId: 'u', ord: Int64(1), user: rpb.UserText(text: long, attachmentId: 'a1'))]);
      await settle(tester);
      expect(find.text('Show full message'), findsOneWidget);
      expect(find.textContaining('sent as a file'), findsOneWidget);
      await tester.tap(find.byKey(const Key('expand-message')));
      await settle(tester);
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets("settings: this device's own entry offers Disconnect, not Revoke", (tester) async {
      repo.devices = [
        const PairedDevice(id: 'me', kind: 'client', name: 'Desk-pc', platform: 'windows'),
        const PairedDevice(id: 'd1', kind: 'client', name: 'Pixel', platform: 'android'),
      ];
      repo.emitHub(repo.current.copyWith(deviceId: 'me'));
      settings.saved = const HubConnection(url: 'ws://minipc:7420/ws', token: 't');
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      expect(find.text('this device'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Revoke'), findsOneWidget);
      await tester.tap(find.byKey(const Key('disconnect-this-device')));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
      await settle(tester);
      expect(repo.disconnected, isTrue);
      expect(settings.saved.isComplete, isFalse);
    });

    testWidgets('desktop: Back from settings returns to where you were', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(sessionCard('s1'));
      await settle(tester);
      expect(find.byKey(const Key('composer')), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      expect(find.byKey(const Key('composer')), findsNothing);
      await tester.tap(find.byTooltip('Back (Esc)'));
      await settle(tester);
      expect(find.byKey(const Key('composer')), findsOneWidget);
    });

    testWidgets('a fork links to its parent, and marks where it split off', (tester) async {
      repo.emitHub(snapshotWith([
        session('s1'),
        Session(id: 'f1', node: 'minipc', title: 'Session f1', cwd: '/srv/app', parent: 's1', forkPoint: 'shared', lineage: 'fork', updated: DateTime(2026, 10, 12)),
      ]));
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(sessionCard('f1'));
      await settle(tester);
      expect(find.text('Forked from Session s1'), findsOneWidget);
      repo.emitTimeline('f1', [
        rpb.TimelineItem(itemId: 'shared', ord: Int64(1), user: rpb.UserText(text: 'before the fork')),
        rpb.TimelineItem(itemId: 'own', ord: Int64(2), user: rpb.UserText(text: 'after the fork')),
      ]);
      await settle(tester);
      expect(find.textContaining('Forked here'), findsOneWidget);

      await tester.tap(find.byKey(const Key('forked-from')));
      await settle(tester);
      expect(find.text('1 fork'), findsOneWidget);
    });

    testWidgets('usage: the plan limits once per account, then tokens per machine', (tester) async {
      await pumpApp(tester, const Size(1400, 1000));
      await tester.tap(find.text('Usage'));
      await settle(tester);
      expect(find.text('Current session'), findsOneWidget, reason: 'two machines on one account share a card');
      expect(find.text('9% used'), findsOneWidget);
      expect(find.text('Resets Oct 12, 3:20am'), findsOneWidget);
      expect(find.text('Same Claude account, so the same limits.'), findsOneWidget);
      expect(find.text('1.5k'), findsWidgets);
    });

    testWidgets('long messages can be written in the full editor and sent from there', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(sessionCard('s1'));
      await settle(tester);
      expect(find.byTooltip('Expand'), findsNothing);
      await tester.enterText(find.byKey(const Key('composer')), 'line one\nline two\nline three');
      await tester.pump();
      await tester.tap(find.byTooltip('Expand'));
      await settle(tester);
      expect(find.byKey(const Key('editor')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('editor')), 'line one\nline two\nline three\nand a fourth');
      await tester.tap(find.byKey(const Key('editor-send')));
      await settle(tester);
      expect(repo.sent.single, ('s1', 'line one\nline two\nline three\nand a fourth', false));
    });

    testWidgets('desktop: sessions filter, devices, activity and files', (tester) async {
      repo.emitHub(snapshotWith([
        session('s1'),
        Session(id: 'e1', node: 'minipc', title: 'Session e1', state: SessionState.error, error: 'boom', updated: DateTime.now()),
      ]).copyWith(artifacts: {
        'a1': Artifact(id: 'a1', name: 'notes.md', mime: 'text/markdown', size: 2048, session: 's1', created: DateTime.now()),
      }));
      await pumpApp(tester, const Size(1400, 1000));
      expect(find.text('Session e1'), findsOneWidget, reason: 'a fresh failure needs you');

      await tester.tap(find.text('Sessions').first);
      await settle(tester);
      await tester.tap(find.text('Failed 1'));
      await settle(tester);
      expect(find.text('boom'), findsOneWidget);
      expect(find.descendant(of: find.byType(CardShell), matching: find.text('Session s1')), findsNothing);

      await tester.tap(find.text('Devices').first);
      await settle(tester);
      expect(find.text('RUNNING TETHER'), findsOneWidget);

      await tester.tap(find.text('Activity').first);
      await settle(tester);
      expect(find.text('Saved notes.md'), findsOneWidget);
      expect(find.text('Failed: Session e1'), findsOneWidget);

      await tester.tap(find.text('Files').first);
      await settle(tester);
      expect(find.text('notes.md'), findsOneWidget);
      expect(find.text('1 file · 2 KB'), findsOneWidget);
    });

    testWidgets('files: search, filters, sort, and a download with its progress and controls', (tester) async {
      final now = DateTime.now();
      repo.emitHub(snapshotWith([session('s1'), session('s2')]).copyWith(artifacts: {
        'big': Artifact(id: 'big', name: 'sales.csv', mime: 'text/csv', size: 600 * 1024 * 1024, session: 's1', origin: 'attachment', note: 'Q3 export', created: now),
        'img': Artifact(id: 'img', name: 'shot.png', mime: 'image/png', size: 2048, session: 's2', origin: 'read', created: now.subtract(const Duration(hours: 1))),
        'doc': Artifact(id: 'doc', name: 'report.pdf', mime: 'application/pdf', size: 5 * 1024 * 1024, session: 's2', created: now.subtract(const Duration(hours: 2))),
      }));
      await pumpApp(tester, const Size(1400, 1000));
      await tester.tap(find.text('Files').first);
      await settle(tester);
      expect(find.text('3 files · 605.0 MB'), findsOneWidget);
      expect(find.textContaining('600.0 MB · ', findRichText: true), findsOneWidget, reason: 'sizes are shown plainly');
      expect(find.text('Q3 export'), findsOneWidget, reason: 'an attachment shows its note');

      await tester.enterText(find.byKey(const Key('file-search')), 'q3');
      await settle(tester);
      expect(find.text('sales.csv'), findsOneWidget, reason: 'search covers notes');
      expect(find.text('report.pdf'), findsNothing);
      await tester.enterText(find.byKey(const Key('file-search')), '');
      await settle(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Data'));
      await settle(tester);
      expect(find.text('sales.csv'), findsOneWidget);
      expect(find.text('shot.png'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await settle(tester);

      await tester.tap(find.byKey(const Key('filter-size')));
      await settle(tester);
      await tester.tap(find.text('Over 100 MB').last);
      await settle(tester);
      expect(find.text('1 file · 600.0 MB'), findsOneWidget);
      await tester.tap(find.byKey(const Key('filter-size')));
      await settle(tester);
      await tester.tap(find.text('Any size').last);
      await settle(tester);

      await tester.tap(find.byKey(const Key('filter-session')));
      await settle(tester);
      await tester.tap(find.text('Session s2').last);
      await settle(tester);
      expect(find.text('sales.csv'), findsNothing);
      expect(find.text('2 files · 5.0 MB'), findsOneWidget);
      await tester.tap(find.byKey(const Key('filter-session')));
      await settle(tester);
      await tester.tap(find.text('Any session').last);
      await settle(tester);

      await tester.tap(find.byKey(const Key('sort-files')));
      await settle(tester);
      await tester.tap(find.text('Smallest first').last);
      await settle(tester);
      expect(tester.getTopLeft(find.text('shot.png')).dy, lessThan(tester.getTopLeft(find.text('sales.csv')).dy));

      await tester.tap(find.byKey(const Key('download-big')));
      await settle(tester);
      expect(transfers.downloads.single.id, 'big');
      transfers.emit(transfers.current['big']!.copyWith(bytes: 150 * 1024 * 1024, speed: 3 * 1024 * 1024));
      await settle(tester);
      expect(find.text('150.0 MB of 600.0 MB · 3.0 MB/s'), findsWidgets);
      await tester.tap(find.byKey(const Key('pause-big')).first);
      await settle(tester);
      expect(find.text('Paused · 150.0 MB of 600.0 MB'), findsWidgets);
      await tester.tap(find.byKey(const Key('resume-big')).first);
      await settle(tester);
      transfers.emit(transfers.current['big']!.copyWith(state: TransferState.done, bytes: 600 * 1024 * 1024, savedTo: 'Download/Tether/sales.csv'));
      await settle(tester);
      expect(find.text('Saved sales.csv · sha256 checked'), findsOneWidget);
    });

    testWidgets('a session can have files attached with a note, and lists its own files', (tester) async {
      repo.emitHub(snapshotWith([session('s1')]).copyWith(artifacts: {
        'mine': Artifact(id: 'mine', name: 'mine.csv', mime: 'text/csv', size: 10, session: 's1', origin: 'attachment', created: DateTime.now()),
        'other': Artifact(id: 'other', name: 'other.csv', mime: 'text/csv', size: 10, session: 'zz', created: DateTime.now()),
      }));
      await pumpApp(tester, const Size(1400, 1000));
      await tester.tap(find.text('Session s1').first);
      await settle(tester);
      await tester.tap(find.byTooltip('More').last);
      await settle(tester);
      expect(find.text('Attach files to this session'), findsOneWidget);
      await tester.tap(find.text("This session's files"));
      await settle(tester);
      expect(find.text('mine.csv'), findsOneWidget);
      expect(find.text('other.csv'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Attach'), findsOneWidget, reason: "uploads here are attached to the session");
    });

    testWidgets('settings: picking a theme and an accent saves them', (tester) async {
      // Tall enough that Appearance, below devices and codebases, is on screen.
      await pumpApp(tester, const Size(1400, 2600));
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      await tester.ensureVisible(find.text('Ocean'));
      await tester.tap(find.text('Ocean'));
      await settle(tester);
      expect(settings.appearance.palette, 'ocean');
      expect(settings.appearance.accent, isNull);
    });

    testWidgets('phone: home, the bottom tabs, and a pushed session page', (tester) async {
      await pumpApp(tester, const Size(400, 860));
      expect(find.byKey(const Key('quick-start')), findsOneWidget);
      expect(find.text('RUNNING NOW'), findsOneWidget);

      await tester.tap(find.text('Sessions').last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('session-search')), 't1');
      await settle(tester);
      expect(find.text('Session s1'), findsNothing);
      expect(find.text('Session t1'), findsOneWidget);

      await tester.tap(find.text('Home').last);
      await settle(tester);
      final card = find.descendant(of: find.byType(CardShell), matching: find.text('Session s1')).first;
      await tester.ensureVisible(card);
      await settle(tester);
      await tester.tap(card);
      await settle(tester);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byKey(const Key('composer')), findsOneWidget);
    });
  });
}
