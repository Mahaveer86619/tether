// Draws the app's screens to PNGs, so a layout can be looked at without a
// device. Run: SCREENS=1 flutter test test/screens --update-goldens
// The images land in test/screens/out/ (not committed).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
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
      final settings = FakeSettingsRepository()..saved = const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 't');
      sl
        ..registerSingleton<HubRepository>(repo)
        ..registerSingleton<TransferRepository>(FakeTransferRepository())
        ..registerSingleton<SettingsRepository>(settings)
        ..registerSingleton<UpdateRepository>(FakeUpdateRepository())
        ..registerSingleton<TailscaleRepository>(FakeTailscale());
      configureDependencies(withData: false);
    });

    Future<void> shoot(WidgetTester t, String name, Size size) async {
      await _font('Inter', ['assets/fonts/Inter-Regular.ttf', 'assets/fonts/Inter-Medium.ttf', 'assets/fonts/Inter-SemiBold.ttf']);
      await _font('JetBrains Mono', ['assets/fonts/JetBrainsMono-Regular.ttf', 'assets/fonts/JetBrainsMono-Medium.ttf']);
      await _font('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const TetherApp());
      await _settle(t);
      await expectLater(find.byType(TetherApp), matchesGoldenFile('out/$name.png'));
    }

    testWidgets('home on a phone', (t) => shoot(t, 'home-phone', const Size(400, 860)), skip: !on);
    testWidgets('home on a desktop', (t) => shoot(t, 'home-desktop', const Size(1400, 900)), skip: !on);
  });
}
