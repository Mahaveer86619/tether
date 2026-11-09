import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/injection.dart';
import 'package:tether/presentation/app.dart';
import 'package:tether/presentation/home/cards.dart';
import 'package:tether/presentation/theme/theme.dart';
import 'package:tether/presentation/ui/motion.dart';
import 'package:tether/presentation/ui/refresh.dart';

import '../helpers/fakes.dart';

double _opacity(WidgetTester t, Finder f) => t.widget<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)).first).opacity;

void main() {
  group('FadeIn', () {
    testWidgets('a row comes in from transparent, and is whole when the animation ends', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FadeIn(child: Text('row'))));
      expect(_opacity(tester, find.text('row')), 0);
      await tester.pump(kFadeDuration ~/ 2);
      expect(_opacity(tester, find.text('row')), inExclusiveRange(0, 1));
      await tester.pump(kFadeDuration);
      expect(_opacity(tester, find.text('row')), 1);
    });

    testWidgets('a row that has come in before is there at once when it is built again', (tester) async {
      final shown = <Object>{'a'};
      await tester.pumpWidget(MaterialApp(home: Column(children: [FadeIn(shown: shown, id: 'a', child: const Text('old')), FadeIn(shown: shown, id: 'b', child: const Text('new'))])));
      expect(_opacity(tester, find.text('old')), 1, reason: 'seen already');
      expect(_opacity(tester, find.text('new')), 0, reason: 'first time');
      expect(shown, containsAll(['a', 'b']));
      await tester.pump(kFadeDuration * 2);

      // Built again, as a list does when you scroll back to it.
      await tester.pumpWidget(MaterialApp(home: Column(children: [FadeIn(key: const ValueKey('again'), shown: shown, id: 'b', child: const Text('new'))])));
      expect(_opacity(tester, find.text('new')), 1);
    });

    testWidgets('a delay holds a row back, so the first rows come in one after another', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FadeIn(delay: Duration(milliseconds: 200), child: Text('later'))));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_opacity(tester, find.text('later')), 0);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(kFadeDuration);
      expect(_opacity(tester, find.text('later')), 1);
    });

    test('the delay grows for the first rows only', () {
      expect(stagger(0), Duration.zero);
      expect(stagger(3), const Duration(milliseconds: 105));
      expect(stagger(40), stagger(8));
    });
  });

  group('pages leave room at the bottom and refresh when pulled down', () {
    testWidgets('PageColumn leaves 15% of the screen under its last item', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: Scaffold(body: PageColumn(children: [for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('row $i'))]))));
      await tester.drag(find.byType(ListView), const Offset(0, -10000));
      await tester.pumpAndSettle();
      final bottom = tester.getBottomLeft(find.text('row 29')).dy;
      expect(1000 - bottom, greaterThanOrEqualTo(1000 * 0.15 - 1), reason: 'room under the last row once scrolled to the end');
    });

    testWidgets('pulling a page down calls its refresh, and once', (tester) async {
      var refreshed = 0;
      await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: Scaffold(body: PageColumn(onRefresh: () async => refreshed++, children: const [Text('top')]))));
      await tester.drag(find.text('top'), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(refreshed, 1);
    });

    testWidgets('a chat, whose list is upside down, refreshes when the oldest message is pulled down past its end', (tester) async {
      var refreshed = 0;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget chat() => MaterialApp(
            theme: buildTheme(Brightness.dark),
            home: Scaffold(
              body: EdgeRefresh(
                onRefresh: () async => refreshed++,
                child: ListView.builder(controller: controller, reverse: true, physics: const BouncingScrollPhysics(), itemCount: 40, itemBuilder: (_, i) => SizedBox(height: 60, child: Text('message $i'))),
              ),
            ),
          );
      await tester.pumpWidget(chat());
      // To the oldest message, then a pull past it.
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(refreshed, 0, reason: 'reaching the oldest message is not a pull');
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(refreshed, 1);
    });
  });

  group('the app', () {
    late FakeHubRepository repo;

    setUp(() async {
      await sl.reset();
      repo = FakeHubRepository(snapshotWith([session('s1')]).copyWith(status: ConnectionStatus.connected));
      sl
        ..registerSingleton<HubRepository>(repo)
        ..registerSingleton<TransferRepository>(FakeTransferRepository())
        ..registerSingleton<SettingsRepository>(FakeSettingsRepository()..saved = const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 't'))
        ..registerSingleton<UpdateRepository>(FakeUpdateRepository())
        ..registerSingleton<TailscaleRepository>(FakeTailscale())
        ..registerSingleton<HubProbe>(FakeHubProbe())
        ..registerSingleton<NotifyDevice>(FakeNotifyDevice())
        ..registerSingleton<DesktopUpdater>(FakeDesktopUpdater());
      configureDependencies(withData: false);
    });

    Future<void> open(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TetherApp());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('scrolls with a bounce, as on iOS', (tester) async {
      await open(tester, const Size(500, 900));
      expect(ScrollConfiguration.of(tester.element(find.byType(ListView).first)).getScrollPhysics(tester.element(find.byType(ListView).first)), isA<BouncingScrollPhysics>());
    });

    testWidgets('Home refreshes the hub when pulled down', (tester) async {
      await open(tester, const Size(500, 900));
      final before = repo.retries;
      await tester.drag(find.byType(ListView).first, const Offset(0, 400));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repo.retries, greaterThan(before));
    });

    testWidgets('Settings leaves 15% of the screen below its last section', (tester) async {
      await open(tester, const Size(1400, 800));
      await tester.tap(find.byTooltip('Settings'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.drag(find.byType(ListView).last, const Offset(0, -20000));
      await tester.pumpAndSettle();
      final bottom = tester.getBottomLeft(find.text('Check for updates')).dy;
      expect(800 - bottom, greaterThanOrEqualTo(800 * 0.15 - 1));
    });
  });
}
