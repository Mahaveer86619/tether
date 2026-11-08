import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/data/datasources/tailscale_desktop.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/injection.dart';
import 'package:tether/presentation/app.dart';

import '../helpers/fakes.dart';

String _status() => jsonEncode({
      'BackendState': 'Running',
      'Self': {'HostName': 'this-pc', 'TailscaleIPs': ['100.64.0.1']},
      'Peer': {
        'a': {'HostName': 'minipc', 'TailscaleIPs': ['100.64.0.2', 'fd7a::2'], 'Online': true, 'OS': 'linux'},
        'b': {'HostName': 'old-laptop', 'DNSName': 'old-laptop.tail.ts.net.', 'TailscaleIPs': ['100.64.0.3'], 'Online': false, 'OS': 'windows'},
        'c': {'DNSName': 'phone.tail.ts.net.', 'TailscaleIPs': ['fd7a::4'], 'Online': true},
        'd': {'DNSName': 'nas.tail.ts.net.', 'TailscaleIPs': ['100.64.0.5'], 'Online': true, 'OS': 'linux'},
      },
    });

void main() {
  test('the tailnet peers are the other devices, each with an IPv4 address, online ones first', () {
    final peers = parseTailnetPeers(_status());
    expect([for (final p in peers) (p.name, p.ip, p.online)], [
      ('minipc', '100.64.0.2', true),
      ('nas', '100.64.0.5', true),
      ('old-laptop', '100.64.0.3', false),
    ]);
    expect(parseTailnetPeers('not json'), isEmpty);
    expect(parseTailnetPeers('{}'), isEmpty);
  });

  group('FindHubs', () {
    test('lists only the devices that answer as a hub, remembered ones first, and keeps a silent remembered one marked', () async {
      final settings = FakeSettingsRepository()..knownHubs.add(const KnownHub(url: 'ws://100.64.0.9:7420/ws', name: 'work-hub'));
      final tailscale = FakeTailscale()
        ..peerList = const [
          TailnetPeer(name: 'minipc', ip: '100.64.0.2'),
          TailnetPeer(name: 'nas', ip: '100.64.0.5'),
          TailnetPeer(name: 'asleep', ip: '100.64.0.3', online: false),
        ];
      final probe = FakeHubProbe({'100.64.0.2': const HubHello(version: '0.17.4', trusted: true)});
      final hubs = await FindHubs(tailscale, probe, settings)();
      expect([for (final h in hubs) (h.name, h.known, h.reachable, h.trusted)], [
        ('work-hub', true, false, false),
        ('minipc', false, true, true),
      ]);
      expect(probe.asked, isNot(contains('100.64.0.3')), reason: 'a device that is off is not asked');
    });

    test('a remembered hub that answers is shown with what it says', () async {
      final settings = FakeSettingsRepository()..knownHubs.add(const KnownHub(url: 'ws://100.64.0.2:7420/ws', name: 'minipc'));
      final tailscale = FakeTailscale()..peerList = const [TailnetPeer(name: 'minipc', ip: '100.64.0.2')];
      final probe = FakeHubProbe({'100.64.0.2': const HubHello(version: '0.17.4', trusted: false)});
      final hubs = await FindHubs(tailscale, probe, settings)();
      expect(hubs, [const FoundHub(name: 'minipc', url: 'ws://100.64.0.2:7420/ws', version: '0.17.4', trusted: false, known: true)]);
    });
  });

  group('first run', () {
    late FakeHubRepository repo;
    late FakeSettingsRepository settings;
    late FakeTailscale tailscale;
    late FakeHubProbe probe;

    setUp(() async {
      await sl.reset();
      repo = FakeHubRepository(snapshotWith([]));
      settings = FakeSettingsRepository();
      tailscale = FakeTailscale()
        ..peerList = const [TailnetPeer(name: 'minipc', ip: '100.64.0.2'), TailnetPeer(name: 'nas', ip: '100.64.0.5')];
      probe = FakeHubProbe({'100.64.0.2': const HubHello(version: '0.17.4', trusted: true)});
      sl
        ..registerSingleton<HubRepository>(repo)
        ..registerSingleton<TransferRepository>(FakeTransferRepository())
        ..registerSingleton<SettingsRepository>(settings)
        ..registerSingleton<UpdateRepository>(FakeUpdateRepository())
        ..registerSingleton<TailscaleRepository>(tailscale)
        ..registerSingleton<HubProbe>(probe)
        ..registerSingleton<NotifyDevice>(FakeNotifyDevice());
      configureDependencies(withData: false);
    });

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TetherApp());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('finds the hub among the tailnet devices, and connects to one that trusts this device with a tap', (tester) async {
      await open(tester);
      expect(find.text('Connect to your hub'), findsOneWidget);
      expect(find.text('minipc'), findsOneWidget);
      expect(find.text('nas'), findsNothing, reason: 'a device with no hub is not listed');
      expect(find.textContaining('connects directly'), findsOneWidget);

      await tester.tap(find.byKey(const Key('hub-ws://100.64.0.2:7420/ws')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(settings.saved.url, 'ws://100.64.0.2:7420/ws');
      expect(settings.saved.viaTailnet, isTrue);
      expect(settings.knownHubs.single.name, 'minipc', reason: 'the hub is remembered for next time');
    });

    testWidgets('a hub that wants a code asks for it, then pairs', (tester) async {
      probe.hubs['100.64.0.2'] = const HubHello(version: '0.17.4', trusted: false);
      await open(tester);
      expect(find.textContaining('needs a pairing code'), findsOneWidget);
      await tester.tap(find.byKey(const Key('hub-ws://100.64.0.2:7420/ws')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byKey(const Key('found-code')), 'ABCDE-FGHJK');
      await tester.tap(find.byKey(const Key('found-pair')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repo.paired.single.$1, 'ws://100.64.0.2:7420/ws');
      expect(repo.paired.single.$2, 'ABCDE-FGHJK');
    });

    testWidgets('with Tailscale off it offers to turn it on, and then looks', (tester) async {
      tailscale
        ..current = const TailscaleStatus(TailscaleState.stopped)
        ..steps = const [TailscaleStatus(TailscaleState.starting), TailscaleStatus(TailscaleState.running)];
      await open(tester);
      expect(find.text('minipc'), findsNothing);
      await tester.tap(find.byKey(const Key('onboarding-tailscale-on')));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tailscale.starts, 1);
      expect(find.text('minipc'), findsOneWidget);
    });

    testWidgets('remembered hubs show first, even before any search', (tester) async {
      settings.knownHubs.add(const KnownHub(url: 'ws://100.64.0.9:7420/ws', name: 'work-hub'));
      tailscale.current = const TailscaleStatus(TailscaleState.stopped);
      await open(tester);
      expect(find.text('work-hub'), findsOneWidget);
      expect(find.text('used before'), findsOneWidget);
    });
  });
}
