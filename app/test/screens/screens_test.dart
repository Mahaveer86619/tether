// Draws the app's screens to PNGs, so a layout can be looked at without a
// device. Run: SCREENS=1 flutter test test/screens --update-goldens
// The images land in test/screens/out/ (not committed).
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/gen/tether/v1/render.pbenum.dart' as rpbe;
import 'package:tether/injection.dart';
import 'package:tether/presentation/app.dart';

import '../helpers/fakes.dart';

Future<void> _font(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final a in assets) {
    loader.addFont(rootBundle.load(a));
  }
  await loader.load();
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final on = Platform.environment['SCREENS'] == '1';

  group('screens', () {
    late FakeHubRepository repo;
    late FakeSettingsRepository settings;
    late FakeTailscale tailscale;
    late FakeHubProbe probe;

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
      ]).copyWith(hubVersion: '0.17.2', chats: {
        'c1': Chat(id: 'c1', title: 'Fix Stripe webhooks on laptop', activeSession: 's1', links: const [ChatLink(session: 's1')], updated: DateTime.now()),
        'c2': Chat(id: 'c2', title: 'Refactor docker-compose volumes', activeSession: 't1', links: const [ChatLink(session: 't1')], updated: DateTime.now().subtract(const Duration(hours: 3))),
      }));
      settings = FakeSettingsRepository()..saved = const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 't');
      sl
        ..registerSingleton<HubRepository>(repo)
        ..registerSingleton<TransferRepository>(FakeTransferRepository())
        ..registerSingleton<SettingsRepository>(settings)
        ..registerSingleton<UpdateRepository>(FakeUpdateRepository())
        ..registerSingleton<TailscaleRepository>(tailscale = FakeTailscale())
        ..registerSingleton<HubProbe>(probe = FakeHubProbe());
      configureDependencies(withData: false);
    });

    rpb.Span span(String t, {bool bold = false, bool code = false}) => rpb.Span(text: t, bold: bold, code: code);

    Future<void> shoot(WidgetTester t, String name, Size size, {String? chat, String? go, String? view}) async {
      await _font('Inter', ['assets/fonts/Inter-Regular.ttf', 'assets/fonts/Inter-Medium.ttf', 'assets/fonts/Inter-SemiBold.ttf']);
      await _font('JetBrains Mono', ['assets/fonts/JetBrainsMono-Regular.ttf', 'assets/fonts/JetBrainsMono-Medium.ttf']);
      await _font('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const TetherApp());
      await _settle(t);
      if (go != null) {
        await t.tap(find.byKey(Key(go)));
        await _settle(t);
      }
      if (chat != null) {
        await t.tap(find.byKey(Key('chat-$chat')));
        await _settle(t);
        repo.emitTimeline('s1', [
          rpb.TimelineItem(itemId: 'u1', ord: Int64(1), user: rpb.UserText(text: 'Webhook retries are double-charging. Find the cause and fix it on the laptop.')),
          rpb.TimelineItem(itemId: 'a1', ord: Int64(2), markdown: rpb.Markdown(blocks: [
            rpb.Block(paragraph: rpb.Paragraph(spans: [span('Looking at '), span('internal/billing/webhook.go', code: true), span(' first. The handler acknowledges after processing, so a slow response makes Stripe retry.')])),
          ])),
          rpb.TimelineItem(itemId: 't1', ord: Int64(3), tool: rpb.ToolCard(toolUseId: 't1', name: 'Bash', title: 'go test ./internal/billing', status: rpbe.ToolCard_Status.STATUS_SUCCEEDED, shell: rpb.ShellCard(command: 'go test ./internal/billing'))),
          rpb.TimelineItem(itemId: 't2', ord: Int64(4), tool: rpb.ToolCard(toolUseId: 't2', name: 'Edit', title: 'internal/billing/webhook.go', status: rpbe.ToolCard_Status.STATUS_SUCCEEDED, edit: rpb.EditCard(path: 'internal/billing/webhook.go', unifiedDiff: '@@ -42,3 +42,4 @@\n-\tprocess(evt)\n+\tack(w)\n+\tgo process(evt)\n', added: 2, removed: 1))),
          rpb.TimelineItem(itemId: 'a2', ord: Int64(5), markdown: rpb.Markdown(blocks: [
            rpb.Block(paragraph: rpb.Paragraph(spans: [span('Fixed: the handler now acknowledges first and processes in the background, and the event id is checked for repeats.', bold: false)])),
            rpb.Block(list: rpb.ListBlock(items: [
              rpb.ListItem(checked: true, blocks: [rpb.Block(paragraph: rpb.Paragraph(spans: [span('tests pass')]))]),
              rpb.ListItem(checked: false, blocks: [rpb.Block(paragraph: rpb.Paragraph(spans: [span('deploy to staging')]))]),
            ])),
          ])),
        ]);
        await _settle(t);
        if (view != null) {
          await t.tap(find.byKey(Key('view-$view')));
          await _settle(t);
        }
      }
      await expectLater(find.byType(TetherApp), matchesGoldenFile('out/$name.png'));
    }

    for (final size in [const Size(400, 860), const Size(1400, 900)]) {
      testWidgets('first run ${size.width.toInt()}', (t) async {
        settings.saved = const HubConnection(url: '', token: '');
        settings.knownHubs.add(const KnownHub(url: 'ws://100.64.0.9:7420/ws', name: 'work-hub'));
        tailscale.peerList = const [TailnetPeer(name: 'minipc', ip: '100.64.0.2'), TailnetPeer(name: 'nas', ip: '100.64.0.5')];
        probe.hubs['100.64.0.2'] = const HubHello(version: '0.17.4', trusted: true);
        await shoot(t, 'first-run-${size.width.toInt()}', size);
      }, skip: !on);
    }
    testWidgets('home on a phone', (t) => shoot(t, 'home-phone', const Size(400, 860)), skip: !on);
    testWidgets('a chat on a phone', (t) => shoot(t, 'chat-phone', const Size(400, 860), chat: 'c1'), skip: !on);
    testWidgets('a chat as a terminal', (t) => shoot(t, 'terminal-desktop', const Size(1400, 900), chat: 'c1', view: 'terminal'), skip: !on);
    testWidgets('a chat split', (t) => shoot(t, 'split-desktop', const Size(1400, 900), chat: 'c1', view: 'split'), skip: !on);
    testWidgets('a chat as a terminal on a phone', (t) => shoot(t, 'terminal-phone', const Size(400, 860), chat: 'c1', view: 'terminal'), skip: !on);
    testWidgets('a chat on a desktop', (t) => shoot(t, 'chat-desktop', const Size(1400, 900), chat: 'c1'), skip: !on);
    for (final d in ['devices', 'activity', 'files', 'routines', 'usage', 'chats']) {
      testWidgets('$d on a desktop', (t) => shoot(t, '$d-desktop', const Size(1400, 900), go: 'nav-$d'), skip: !on);
    }
    testWidgets('devices on a phone', (t) => shoot(t, 'devices-phone', const Size(400, 860), go: 'nav-devices'), skip: !on);
    testWidgets('home on a desktop', (t) => shoot(t, 'home-desktop', const Size(1400, 900)), skip: !on);
  });
}
