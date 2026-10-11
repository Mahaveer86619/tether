import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/gen/tether/v1/render.pbenum.dart' as rpbe;
import 'package:tether/injection.dart';
import 'package:tether/presentation/app.dart';
import 'package:tether/presentation/home/overview_page.dart';
import 'package:tether/presentation/theme/theme.dart';
import 'package:tether/presentation/widgets/timeline_item_view.dart';

import '../helpers/fakes.dart';

Widget themed(Widget child) => MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: SingleChildScrollView(child: child)));

/// Busy sessions pulse forever, so pumpAndSettle never returns; pump a
/// fixed number of frames instead.
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
    expect(find.text('fmt.Println(1)'), findsOneWidget);
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

  group('app', () {
    late FakeHubRepository repo;

    setUp(() async {
      await sl.reset();
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
      final settings = FakeSettingsRepository()..saved = const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 't');
      sl
        ..registerSingleton<HubRepository>(repo)
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

      await tester.tap(find.text('Session s1').first);
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
      await tester.tap(find.text('Session t1').first);
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
      await tester.tap(find.text('Session s1').first);
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
      await tester.tap(find.text('Session w1').first);
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
      await tester.tap(find.text('Session s1').first);
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
      await tester.tap(find.text('Session s1').first);
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

    testWidgets('phone: dashboard with devices and a pushed session page', (tester) async {
      await pumpApp(tester, const Size(400, 860));
      expect(find.byKey(const Key('quick-start')), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(CardShell), matching: find.text('Session s1')).first);
      await settle(tester);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byKey(const Key('composer')), findsOneWidget);
    });
  });
}
