import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/core/error/failures.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/injection.dart';
import 'package:tether/presentation/app.dart';
import 'package:tether/presentation/notifications/notifications_cubit.dart';

import '../helpers/fakes.dart';

void main() {
  test('the hub address for notifications is its HTTP one', () {
    expect(httpBaseOf('ws://100.64.0.2:7420/ws'), 'http://100.64.0.2:7420');
    expect(httpBaseOf('wss://hub.example.com/ws'), 'https://hub.example.com');
    expect(httpBaseOf('nonsense'), isNull);
  });

  group('NotificationsCubit', () {
    late FakeHubRepository repo;
    late FakeSettingsRepository settings;
    late FakeNotifyDevice device;
    late NotificationsCubit cubit;

    HubSnapshot connected({String tunnel = ''}) => snapshotWith([]).copyWith(
          status: ConnectionStatus.connected,
          endpoint: 'ws://100.64.0.2:7420/ws',
          notifyUrl: tunnel,
        );

    setUp(() {
      repo = FakeHubRepository(connected());
      settings = FakeSettingsRepository();
      device = FakeNotifyDevice();
      cubit = NotificationsCubit(notifications: Notifications(repo, settings, device), watchHub: WatchHub(repo));
    });
    tearDown(() => cubit.close());

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

    test('is off until switched on, and has an install id of its own', () async {
      await cubit.load();
      await settle();
      expect(cubit.state.settings.enabled, isFalse);
      expect(cubit.state.settings.installId, hasLength(24));
      expect(device.enabled, isFalse);
    });

    test('switching it on asks for permission, gets a token once, and points the service at the hub then the tunnel', () async {
      repo.emitHub(connected(tunnel: 'https://quiet-lake.trycloudflare.com'));
      await cubit.load();
      await cubit.setEnabled(true);
      await settle();
      expect(device.asked, 1);
      expect((device.enabled, device.token), (true, 'token-1'));
      expect(device.urls, ['http://100.64.0.2:7420', 'https://quiet-lake.trycloudflare.com']);
      expect(device.kinds, {NotifyKind.finished, NotifyKind.approval, NotifyKind.failed});
      expect(repo.notifyTokens, 1);
    });

    test('a new tunnel address reaches the service without a new token', () async {
      await cubit.load();
      await cubit.setEnabled(true);
      await settle();
      expect(device.urls, ['http://100.64.0.2:7420']);

      repo.emitHub(connected(tunnel: 'https://new-name.trycloudflare.com'));
      await settle();
      expect(device.urls, ['http://100.64.0.2:7420', 'https://new-name.trycloudflare.com']);
      expect(device.token, 'token-1');
      expect(repo.notifyTokens, 1, reason: 'the token is kept, so the service keeps its place');
    });

    test('the kinds can be changed, and switching off stops the service and drops the token', () async {
      await cubit.load();
      await cubit.setEnabled(true);
      await cubit.setKind(NotifyKind.failed, false);
      await settle();
      expect(device.kinds, {NotifyKind.finished, NotifyKind.approval});

      await cubit.setEnabled(false);
      await settle();
      expect(device.enabled, isFalse);
      expect(cubit.state.settings.token, isEmpty);
      await cubit.setEnabled(true);
      await settle();
      expect(device.token, 'token-2', reason: 'a fresh one after being off');
    });

    test('what was chosen survives a restart', () async {
      await cubit.load();
      await cubit.setEnabled(true);
      await cubit.setKind(NotifyKind.finished, false);
      await settle();
      final again = NotificationsCubit(notifications: Notifications(repo, settings, FakeNotifyDevice()), watchHub: WatchHub(repo));
      await again.load();
      expect(again.state.settings.enabled, isTrue);
      expect(again.state.settings.kinds, {NotifyKind.approval, NotifyKind.failed});
      expect(again.state.settings.installId, cubit.state.settings.installId);
      await again.close();
    });

    test('a hub that refuses the token says so and leaves the service off', () async {
      repo.notifyFailure = const UnauthorizedFailure();
      await cubit.load();
      await cubit.setEnabled(true);
      await settle();
      expect(cubit.state.failure, isA<UnauthorizedFailure>());
      expect(device.enabled, isFalse);
    });

    test('the service is told when the app is on screen', () async {
      cubit.appActive(true);
      expect(device.active, isTrue);
      cubit.appActive(false);
      expect(device.active, isFalse);
    });

    test('a test notification is asked of the hub', () async {
      await cubit.load();
      await cubit.sendTest();
      expect(repo.testNotifications, 1);
      expect(cubit.state.notice, contains('Test sent'));
    });
  });

  group('Settings', () {
    late FakeNotifyDevice device;
    late FakeHubRepository repo;

    setUp(() async {
      await sl.reset();
      repo = FakeHubRepository(snapshotWith([]).copyWith(status: ConnectionStatus.connected, endpoint: 'ws://100.64.0.2:7420/ws', notifyUrl: 'https://quiet-lake.trycloudflare.com'));
      device = FakeNotifyDevice();
      sl
        ..registerSingleton<HubRepository>(repo)
        ..registerSingleton<TransferRepository>(FakeTransferRepository())
        ..registerSingleton<SettingsRepository>(FakeSettingsRepository()..saved = const HubConnection(url: 'ws://100.64.0.2:7420/ws', token: 't'))
        ..registerSingleton<UpdateRepository>(FakeUpdateRepository())
        ..registerSingleton<TailscaleRepository>(FakeTailscale())
        ..registerSingleton<HubProbe>(FakeHubProbe())
        ..registerSingleton<NotifyDevice>(device)
        ..registerSingleton<DesktopUpdater>(FakeDesktopUpdater());
      configureDependencies(withData: false);
    });

    testWidgets('the section turns notifications on, shows how they reach you, and sends a test', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TetherApp());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byTooltip('Settings'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.scrollUntilVisible(find.byKey(const Key('section-notifications')), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('section-notifications')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('notify-enabled')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(device.enabled, isTrue);
      expect(find.byKey(const Key('notify-reach')), findsOneWidget);
      expect(find.textContaining('without Tailscale through the hub'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('notify-test')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('notify-test')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repo.testNotifications, 1);
    });
  });
}
