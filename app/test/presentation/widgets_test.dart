import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/gen/tether/v1/render.pbenum.dart' as rpbe;
import 'package:tether/presentation/chats/chats_page.dart';
import 'package:tether/injection.dart';
import 'package:tether/presentation/app.dart';
import 'package:tether/presentation/home/cards.dart';
import 'package:tether/presentation/theme/syntax.dart';
import 'package:tether/presentation/theme/theme.dart';
import 'package:tether/presentation/widgets/timeline_item_view.dart';

import '../helpers/fakes.dart';

Widget themed(Widget child) => MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: SingleChildScrollView(child: child)));

/// Busy sessions pulse forever, so pumpAndSettle never returns; pump a
/// fixed number of frames instead.
/// Opens a session from Home's history, which lists sessions on a hub
/// without chats; it sits below the start box and the live cards.
Future<void> openSession(WidgetTester tester, String id) async {
  final row = find.descendant(of: find.byType(ChatsPage), matching: find.text('Session $id')).last;
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row);
}

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
    late FakeUpdateRepository updates;

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
        ..registerSingleton<SettingsRepository>(settings)
        ..registerSingleton<UpdateRepository>(updates = FakeUpdateRepository());
      configureDependencies(withData: false);
    });

    /// Opens the app on Home: the start-a-chat box, what's running and the chats.
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

      await openSession(tester, 's1');
      await settle(tester);
      repo.emitTimeline('s1', [rpb.TimelineItem(itemId: 'u', ord: Int64(1), user: rpb.UserText(text: 'earlier prompt'))]);
      await settle(tester);
      expect(find.text('earlier prompt'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('composer')), 'next step');
      await tester.pump();
      await tester.tap(find.byKey(const Key('send')));
      await settle(tester);
      expect(repo.sent.single, ('s1', 'next step', false));
      expect(tester.widget<TextField>(find.byKey(const Key('composer'))).controller!.text, isEmpty, reason: 'composer clears after sending');
      expect(find.text('Queued · Claude reads it at its next step'), findsOneWidget, reason: 'the message waits in the outbox');

      // It reaches the timeline, stamped with its client id: shown once.
      repo.emitTimeline('s1', [
        rpb.TimelineItem(itemId: 'u', ord: Int64(1), user: rpb.UserText(text: 'earlier prompt')),
        rpb.TimelineItem(itemId: 'u2', ord: Int64(2), user: rpb.UserText(text: 'next step', clientId: repo.clientIds.single)),
      ]);
      await settle(tester);
      expect(find.text('next step'), findsOneWidget);
      expect(find.text('Queued · Claude reads it at its next step'), findsNothing);
    });

    testWidgets('desktop: a terminal session offers fork instead of typing', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      await openSession(tester, 't1');
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
      await openSession(tester, 's1');
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
      await openSession(tester, 'w1');
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
      await openSession(tester, 's1');
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
      await openSession(tester, 's1');
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
      await openSession(tester, 's1');
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

    testWidgets('a dialog on screen comes as a card with its options, Esc, and the terminal', (tester) async {
      repo.screenText = '● How is Claude doing this session?\n  1: Bad  2: Fine  3: Good  0: Dismiss';
      repo.emitHub(snapshotWith([session('s1', state: SessionState.awaitingApproval)], approvals: [
        Approval(
          id: 'p1',
          session: 's1',
          node: 'minipc',
          kind: ApprovalKind.prompt,
          description: 'How is Claude doing this session?',
          options: const ['Bad', 'Fine', 'Good', 'Dismiss'],
          created: DateTime(2026),
        ),
      ]));
      await pumpApp(tester, const Size(1400, 900));
      await openSession(tester, 's1');
      await settle(tester);
      expect(find.text('Claude Code is asking'), findsWidgets);
      expect(find.byKey(const Key('stuck-banner')), findsNothing, reason: 'the card says what it waits on');
      await tester.tap(find.byKey(const Key('prompt-option-3')).last);
      await settle(tester);
      expect(repo.decided.last, ('p1', true));
      expect(repo.options.last, 3);
    });

    testWidgets('a session waiting on something with no card offers its screen and keys', (tester) async {
      repo.screenText = 'Some dialog Tether cannot read\n  [y/N]';
      repo.emitHub(snapshotWith([session('s1', state: SessionState.awaitingApproval)]));
      await pumpApp(tester, const Size(1400, 900));
      await openSession(tester, 's1');
      await settle(tester);
      expect(find.byKey(const Key('stuck-banner')), findsOneWidget);
      await tester.tap(find.byKey(const Key('stuck-open-terminal')));
      await settle(tester);
      expect(find.textContaining('Some dialog Tether cannot read'), findsOneWidget);
      await tester.tap(find.byKey(const Key('key-Down')));
      await settle(tester);
      expect([repo.keysSent.last.$1, ...repo.keysSent.last.$2, repo.keysSent.last.$3], ['s1', 'Down', '']);
      await tester.enterText(find.byKey(const Key('terminal-text')), 'y');
      await tester.tap(find.byKey(const Key('terminal-type-enter')));
      await settle(tester);
      final typed = repo.keysSent.sublist(repo.keysSent.length - 2);
      expect([for (final k in typed) '${k.$2.join('+')}|${k.$3}'], ['|y', 'Enter|'], reason: 'the text, then Enter on its own');
    });

    testWidgets('the permission mode shows in the header and can be switched for a while', (tester) async {
      repo.emitHub(snapshotWith([
        Session(
          id: 's1',
          node: 'minipc',
          title: 'Session s1',
          state: SessionState.ready,
          host: SessionHost.tmux,
          updated: DateTime(2026, 10, 11),
          permissionMode: 'plan',
          modeRevert: DateTime.now().add(const Duration(minutes: 12, seconds: 30)),
          modeRevertTo: 'default',
        ),
      ]));
      await pumpApp(tester, const Size(1400, 900));
      await openSession(tester, 's1');
      await settle(tester);
      expect(find.text('Plan · 12m left'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mode-chip')));
      await settle(tester);
      expect(find.textContaining('Goes back to Ask first'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mode-for-60')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('mode-acceptEdits')));
      await settle(tester);
      expect(repo.modes.single, ('s1', PermissionMode.acceptEdits, const Duration(hours: 1)));
    });

    testWidgets('approving a plan can also let its edits go ahead', (tester) async {
      repo.emitHub(snapshotWith([session('s1', state: SessionState.awaitingApproval)], approvals: [
        Approval(id: 'pl', session: 's1', node: 'minipc', kind: ApprovalKind.tool, toolName: 'ExitPlanMode', inputJson: '{"plan":"1. do it"}', created: DateTime(2026)),
      ]));
      await pumpApp(tester, const Size(1400, 900));
      await openSession(tester, 's1');
      await settle(tester);
      expect(find.text('Approve plan'), findsWidgets);
      await tester.tap(find.byKey(const Key('allow-accept-edits-pl')).last);
      await settle(tester);
      expect(repo.decided.last, ('pl', true));
      expect(repo.modes.single.$2, PermissionMode.acceptEdits);
    });

    testWidgets('an interrupt shows it is stopping, and offers more if Claude keeps going', (tester) async {
      repo.emitHub(snapshotWith([session('s1', state: SessionState.running)]));
      await pumpApp(tester, const Size(1400, 900));
      await openSession(tester, 's1');
      await settle(tester);
      await tester.tap(find.byKey(const Key('interrupt')));
      await settle(tester);
      expect(repo.interrupted.single, 's1');
      expect(find.text('Stopping…'), findsOneWidget);
      expect(find.byKey(const Key('still-working')), findsNothing);

      await tester.pump(const Duration(seconds: 9));
      await settle(tester);
      expect(find.byKey(const Key('still-working')), findsOneWidget);
      await tester.tap(find.byKey(const Key('interrupt-end')));
      await settle(tester);
      expect(find.text('End this session?'), findsOneWidget, reason: 'ending asks first');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(repo.ended, isEmpty);

      repo.emitHub(snapshotWith([session('s1', state: SessionState.ready)]));
      await settle(tester);
      expect(find.byKey(const Key('still-working')), findsNothing);
    });

    testWidgets('devices: hub, agents and apps in install order, older ones flagged for an update', (tester) async {
      repo.emitHub(snapshotWith([session('s1')], nodes: const [
        Node(name: 'minipc', online: true, os: 'linux', agentVersion: '0.15.0'),
        Node(name: 'laptop', online: true, os: 'windows', agentVersion: '0.13.0'),
      ]).copyWith(hubVersion: '0.15.0', hubNode: 'minipc'));
      await pumpApp(tester, const Size(1400, 1400));
      await tester.tap(find.text('Devices').first);
      await settle(tester);
      expect(find.byKey(const Key('hub-card')), findsOneWidget);
      expect(find.textContaining('Hub 0.15.0'), findsOneWidget);
      expect(find.byKey(const Key('update-laptop')), findsOneWidget, reason: 'its agent is older than the hub');
      expect(find.byKey(const Key('update-minipc')), findsNothing);
      final app = find.byKey(const Key('app-Pixel (android)'));
      expect(app, findsOneWidget);
      expect(find.descendant(of: app, matching: find.text('update')), findsOneWidget, reason: 'app 0.14.0 on a 0.15.0 hub');
      await tester.ensureVisible(find.byKey(const Key('setup-guide')));
      await tester.tap(find.byKey(const Key('setup-guide')));
      await settle(tester);
      expect(find.textContaining('Update it first'), findsOneWidget);

      repo.clientList = null;
      await tester.tap(find.byKey(const Key('nav-chats')));
      await settle(tester);
      await tester.tap(find.text('Devices').first);
      await settle(tester);
      expect(find.textContaining('too old to list its apps'), findsOneWidget);
    });

    testWidgets('the app tells the hub when it is in use, for backups, and sessions show their last backup', (tester) async {
      repo.emitHub(snapshotWith([
        Session(
          id: 's1',
          node: 'minipc',
          title: 'Session s1',
          state: SessionState.ready,
          host: SessionHost.tmux,
          updated: DateTime(2026, 10, 11),
          backedUp: DateTime.now().subtract(const Duration(minutes: 5)),
          backedUpBytes: 2048,
        ),
      ]));
      await pumpApp(tester, const Size(1400, 900));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);
      expect(repo.activity.last, isFalse, reason: 'in the background');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(repo.activity.last, isTrue);
      expect(repo.activity, contains(true), reason: 'an unfocused window still counts as in use');

      await openSession(tester, 's1');
      await settle(tester);
      expect(find.textContaining('backed up 5m ago'), findsOneWidget);
    });

    testWidgets("Claude's questions are answered from a card, with choices or your own words", (tester) async {
      const input = '{"questions":['
          '{"question":"Which DB?","header":"DB","multiSelect":false,"options":[{"label":"Postgres","description":"server"},{"label":"SQLite"}]},'
          '{"question":"Which parts?","header":"Scope","multiSelect":true,"options":[{"label":"API"},{"label":"Web"}]}]}';
      repo.emitHub(snapshotWith([session('s1')], approvals: [
        Approval(id: 'q', session: 's1', node: 'minipc', kind: ApprovalKind.question, toolName: 'AskUserQuestion', inputJson: input, created: DateTime(2026)),
      ]));
      await pumpApp(tester, const Size(1400, 900));
      await openSession(tester, 's1');
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
      await openSession(tester, 's1');
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
      await openSession(tester, 's1');
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
      await openSession(tester, 'f1');
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
      await openSession(tester, 's1');
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

    testWidgets('desktop: devices, activity and files', (tester) async {
      repo.emitHub(snapshotWith([
        session('s1'),
        Session(id: 'e1', node: 'minipc', title: 'Session e1', state: SessionState.error, error: 'boom', updated: DateTime.now()),
      ]).copyWith(artifacts: {
        'a1': Artifact(id: 'a1', name: 'notes.md', mime: 'text/markdown', size: 2048, session: 's1', created: DateTime.now()),
      }));
      await pumpApp(tester, const Size(1400, 1000));
      expect(find.descendant(of: find.byType(CardShell), matching: find.text('Session e1')), findsOneWidget, reason: 'a fresh failure needs you');

      await tester.tap(find.text('Devices').first);
      await settle(tester);
      expect(find.text('1 · HUB'), findsOneWidget);
      expect(find.text('2 · DEVICES RUNNING THE AGENT'), findsOneWidget);
      expect(find.text('3 · APPS'), findsOneWidget);

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

    testWidgets('phone: home with the start box, the bottom tabs, a pushed session page, and Back through the nav state', (tester) async {
      await pumpApp(tester, const Size(400, 860));
      expect(find.byKey(const Key('new-chat-input')), findsOneWidget, reason: 'Home starts with the box for a new chat');
      expect(find.text('RUNNING NOW'), findsOneWidget);
      expect(find.byKey(const Key('nav-monitor')), findsNothing);
      expect(find.byKey(const Key('nav-sessions')), findsNothing, reason: 'sessions are opened from their chat, not from a tab');

      await tester.tap(find.byKey(const Key('nav-devices')));
      await settle(tester);
      expect(find.byKey(const Key('new-chat-input')), findsNothing);

      await tester.tap(find.byKey(const Key('nav-chats')));
      await settle(tester);
      await openSession(tester, 's1');
      await settle(tester);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byKey(const Key('composer')), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byKey(const Key('composer')), findsNothing);
      expect(find.text('RUNNING NOW'), findsOneWidget, reason: 'Back returns to Home');

      // The system back button walks the same history: Home, Devices, Home.
      for (var i = 0; i < 2; i++) {
        await tester.binding.handlePopRoute();
        await settle(tester);
      }
      expect(find.byKey(const Key('new-chat-input')), findsOneWidget, reason: 'back on Home, with the start box');
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.byKey(const Key('more-destinations')));
      await settle(tester);
      await tester.tap(find.text('Usage').last);
      await settle(tester);
      expect(find.byType(NavigationBar), findsNothing, reason: 'pages from the menu sit on top, with a back arrow');
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('chats: start one with an auto target, rename it inline, and see where it runs', (tester) async {
      repo.emitHub(repo.current.copyWith(hubVersion: '0.16.0', hubNode: 'minipc'));
      repo.suggestions = const TargetSuggestions(
        candidates: [TargetCandidate(node: 'laptop', cwd: '/src/tether', label: 'tether', online: true, score: 10, reason: 'matched "tether"')],
        pick: TargetCandidate(node: 'laptop', cwd: '/src/tether', label: 'tether', online: true, score: 10, reason: 'matched "tether"'),
      );
      await pumpApp(tester, const Size(1400, 900));
      expect(find.text('No chats yet'), findsOneWidget);

      await tester.tap(find.byKey(const Key('new-chat')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('new-chat-input')), 'fix the tether login');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      expect(find.text('Auto · tether on laptop'), findsOneWidget, reason: 'the chip previews what auto would pick');
      expect(repo.suggestionPrompts.last, 'fix the tether login');

      await tester.tap(find.byKey(const Key('new-chat-send')));
      await settle(tester);
      expect(repo.chatsCreated.single.target, isNull, reason: 'auto leaves the choice to the hub');
      expect(find.byKey(const Key('composer')), findsOneWidget, reason: 'the new chat opens on its session');
      expect(find.byKey(const Key('chat-target')), findsOneWidget);
      expect(find.textContaining('matched "app"', findRichText: true), findsOneWidget);
      expect(find.byKey(const Key('recent-chat-1')), findsOneWidget, reason: 'it shows in the sidebar recents');

      await tester.tap(find.byKey(const Key('chat-title')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('chat-title-field')), 'Login bug');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(repo.current.chats['chat-1']!.title, 'Login bug');
      expect(find.text('Login bug'), findsWidgets);
    });

    testWidgets('chats: pick a folder by hand, and move a chat to another one', (tester) async {
      repo.emitHub(repo.current.copyWith(hubVersion: '0.16.0', hubNode: 'minipc'));
      repo.suggestions = const TargetSuggestions(candidates: [
        TargetCandidate(node: 'laptop', cwd: '/src/tether', label: 'tether', online: true),
        TargetCandidate(node: 'laptop', cwd: '/src/other', label: 'other', online: true),
      ]);
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(find.byKey(const Key('new-chat')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('new-chat-input')), 'hello');
      await tester.tap(find.byKey(const Key('target-chip')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('target-node-laptop')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('target-folder-tether')));
      await settle(tester);
      expect(find.text('laptop · tether'), findsOneWidget);
      await tester.tap(find.byKey(const Key('new-chat-send')));
      await settle(tester);
      final t = repo.chatsCreated.single.target!;
      expect((t.mode, t.node, t.cwd), (TargetMode.manual, 'laptop', '/src/tether'));

      await tester.tap(find.byKey(const Key('change-target')));
      await settle(tester);
      expect(find.byKey(const Key('move-now')), findsOneWidget);
      await tester.tap(find.byKey(const Key('target-folder-other')));
      await settle(tester);
      expect(repo.retargets.single, ('chat-1', const ChatTarget(mode: TargetMode.manual, node: 'laptop', cwd: '/src/other'), true));
      expect(find.text('The chat carries on there'), findsOneWidget);
    });

    testWidgets('chats: the history groups, searches and archives chats; Back leaves a chat', (tester) async {
      final now = DateTime.now();
      repo.emitHub(repo.current.copyWith(hubVersion: '0.16.0', chats: {
        'c1': Chat(id: 'c1', title: 'Fix login', activeSession: 's1', links: const [ChatLink(session: 's1')], updated: now),
        'c2': Chat(id: 'c2', title: 'Old idea', activeSession: 'gone', links: const [ChatLink(session: 'gone')], updated: now.subtract(const Duration(days: 40))),
      }));
      await pumpApp(tester, const Size(1400, 900));
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('OLDER'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat-search')), 'idea');
      await settle(tester);
      expect(find.byKey(const Key('chat-c1')), findsNothing);

      await tester.tap(find.byKey(const Key('chat-c2')));
      await settle(tester);
      expect(find.text('This chat has no session right now'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat-composer')), 'carry on please');
      await tester.tap(find.byTooltip('Send'));
      await settle(tester);
      expect(repo.chatSends.single, ('c2', 'carry on please'));

      // The mouse's back button leaves the chat.
      await tester.sendEventToBinding(const PointerDownEvent(buttons: kBackMouseButton, position: Offset(900, 400)));
      await tester.sendEventToBinding(const PointerUpEvent(position: Offset(900, 400)));
      await settle(tester);
      expect(find.byKey(const Key('chat-search')), findsOneWidget, reason: 'back on the history');

      await tester.enterText(find.byKey(const Key('chat-search')), '');
      await settle(tester);
      await tester.tap(find.byKey(const Key('chat-menu-c1')).first);
      await settle(tester);
      await tester.tap(find.text('Archive'));
      await settle(tester);
      expect(repo.current.chats['c1']!.archived, isTrue);
      expect(find.text('Chat archived'), findsOneWidget);
    });

    testWidgets('chats: a monitored session that is a chat opens as the chat', (tester) async {
      repo.emitHub(repo.current.copyWith(hubVersion: '0.16.0', chats: {
        'c1': Chat(id: 'c1', title: 'Chat about s1', activeSession: 's1', links: const [ChatLink(session: 's1'), ChatLink(session: 't1', role: 'started')]),
      }));
      await pumpApp(tester, const Size(1400, 900));
      final tile = find.byKey(const Key('chat-c1'));
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile);
      await settle(tester);
      expect(find.text('Chat about s1'), findsWidgets);
      expect(find.text('1 working'), findsOneWidget);
      expect(find.byKey(const Key('task-t1')), findsOneWidget, reason: 'the session Claude started shows as a task of the chat, open while it works');
      await tester.tap(find.byKey(const Key('chat-tasks')));
      await settle(tester);
      expect(find.byKey(const Key('task-t1')), findsNothing, reason: 'the header folds the list away');
      expect(find.byKey(const Key('linked-sessions')), findsOneWidget);
      await tester.tap(find.byKey(const Key('linked-sessions')));
      await settle(tester);
      expect(find.text('Started by Claude · laptop · app'), findsOneWidget);
    });

    testWidgets('updates: a banner with the notes, Skip, and Update through to Install', (tester) async {
      updates.release = release('9.0.0');
      await pumpApp(tester, const Size(1400, 900));
      expect(find.byKey(const Key('update-banner')), findsOneWidget);
      expect(find.textContaining('Tether 9.0.0 is available'), findsOneWidget);
      await tester.tap(find.byKey(const Key('update-notes')));
      await settle(tester);
      expect(find.textContaining('Faster chats'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await settle(tester);

      await tester.tap(find.byKey(const Key('update-now')));
      await settle(tester);
      expect(updates.installed, ['/tmp/update.bin'], reason: 'android: downloaded, checked, then the installer');

      updates.release = release('9.0.1');
      repo.emitHub(repo.current.copyWith(update: () => release('9.0.1')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('update-skip')));
      await settle(tester);
      expect(find.byKey(const Key('update-banner')), findsNothing);
      expect(updates.skippedVersion, '9.0.1');
    });

    testWidgets('updates: below the minimum, nothing but the update is offered', (tester) async {
      updates.release = release('9.0.0', minSupported: '8.0.0');
      await pumpApp(tester, const Size(1400, 900));
      expect(find.byKey(const Key('forced-update')), findsOneWidget);
      expect(find.byKey(const Key('nav-chats')), findsNothing);
      await tester.tap(find.byKey(const Key('forced-update-now')));
      await settle(tester);
      expect(updates.installed, isNotEmpty);
    });

    testWidgets('offline: the countdown to the next try, the last error, and Retry', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      repo.emitHub(repo.current.copyWith(
        status: ConnectionStatus.offline,
        retryAt: () => DateTime.now().add(const Duration(seconds: 8)),
        attempts: 3,
        lastError: () => 'no answer from the hub for 10s',
      ));
      await tester.pump();
      expect(find.textContaining('retrying in'), findsOneWidget);
      await tester.tap(find.byKey(const Key('connection-retry')));
      await tester.pump();
      expect(repo.retries, 1);
      expect(find.byTooltip('no answer from the hub for 10s\n3 failed tries'), findsOneWidget);
    });

    testWidgets('tablet widths get the icon rail', (tester) async {
      await pumpApp(tester, const Size(800, 900));
      expect(find.text('RUNNING NOW'), findsOneWidget);
      expect(find.byKey(const Key('nav-chats')), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('RECENTS'), findsNothing, reason: 'recents need the full sidebar');
    });
  });
}
