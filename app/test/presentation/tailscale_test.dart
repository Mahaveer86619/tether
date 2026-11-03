import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/presentation/tailscale/tailscale_banner.dart';
import 'package:tether/presentation/tailscale/tailscale_cubit.dart';
import 'package:tether/presentation/theme/theme.dart';

import '../helpers/fakes.dart';

HubSnapshot hubAt(String endpoint, {ConnectionStatus status = ConnectionStatus.connecting}) => HubSnapshot(status: status, endpoint: endpoint);

TailscaleCubit cubitFor(FakeHubRepository repo, FakeTailscale ts) => TailscaleCubit(
      ensure: EnsureTailscale(ts),
      watchHub: WatchHub(repo),
      retryHub: RetryConnection(repo),
      grace: const Duration(milliseconds: 20),
      minGap: const Duration(milliseconds: 100),
    );

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 80));

void main() {
  group('isTailnetEndpoint', () {
    test('tailnet addresses and names are, the rest is not', () {
      for (final yes in ['ws://100.118.241.124:7420/ws', 'ws://100.64.0.1:7420/ws', 'ws://100.127.255.1:1/ws', 'wss://hub.tail1234.ts.net/ws', 'ws://minipc:7420/ws', 'minipc:7420']) {
        expect(isTailnetEndpoint(yes), isTrue, reason: yes);
      }
      for (final no in ['', 'ws://192.168.1.5:7420/ws', 'ws://100.63.0.1:7420/ws', 'ws://100.128.0.1:7420/ws', 'ws://localhost:7420/ws', 'wss://hub.example.com/ws', 'ws://[::1]:7420/ws']) {
        expect(isTailnetEndpoint(no), isFalse, reason: no);
      }
    });
  });

  group('TailscaleCubit', () {
    late FakeHubRepository repo;
    late FakeTailscale ts;

    setUp(() {
      repo = FakeHubRepository(hubAt('ws://100.118.241.124:7420/ws'));
      ts = FakeTailscale();
    });

    test('a tailnet hub that cannot be reached gets Tailscale started in the background, then a retry', () async {
      ts
        ..current = const TailscaleStatus(TailscaleState.stopped)
        ..steps = const [
          TailscaleStatus(TailscaleState.stopped),
          TailscaleStatus(TailscaleState.starting),
          TailscaleStatus(TailscaleState.running),
        ];
      final c = cubitFor(repo, ts);
      final seen = <TailscaleViewState>[];
      final sub = c.stream.listen(seen.add);
      await settle();
      expect(ts.starts, 1);
      expect(seen.any((s) => s.busy && s.visible), isTrue, reason: 'the banner shows while it works');
      expect(c.state.status.running, isTrue);
      expect(c.state.busy, isFalse);
      expect(repo.retries, 1, reason: 'the hub connection is told to try again once Tailscale is up');
      await sub.cancel();
      await c.close();
    });

    test('a hub that is not on the tailnet, or already connected, leaves Tailscale alone', () async {
      repo.emitHub(hubAt('ws://192.168.1.5:7420/ws'));
      final c = cubitFor(repo, ts..current = const TailscaleStatus(TailscaleState.stopped));
      await settle();
      expect((ts.checks, ts.starts), (0, 0));
      repo.emitHub(hubAt('ws://100.118.241.124:7420/ws', status: ConnectionStatus.connected));
      await settle();
      expect((ts.checks, ts.starts), (0, 0), reason: 'connected means Tailscale is fine');
      await c.close();
    });

    test('Tailscale that is already running is not started, and the hub is nudged', () async {
      final c = cubitFor(repo, ts);
      await settle();
      expect((ts.checks, ts.starts), (1, 0));
      expect(repo.retries, 1);
      await c.close();
    });

    test('a sign-in is kept for the banner, with where to go', () async {
      ts
        ..current = const TailscaleStatus(TailscaleState.needsLogin)
        ..steps = const [TailscaleStatus(TailscaleState.needsLogin, loginUrl: 'https://login.tailscale.com/a/xyz')];
      final c = cubitFor(repo, ts);
      await settle();
      expect(c.state.status.loginUrl, 'https://login.tailscale.com/a/xyz');
      expect(c.state.visible, isTrue);
      expect(repo.retries, 0, reason: 'nothing to retry until Tailscale is up');
      await c.close();
    });

    test('it does not loop: a second attempt waits out the gap, and Try again goes at once', () async {
      ts
        ..current = const TailscaleStatus(TailscaleState.stopped)
        ..steps = const [TailscaleStatus(TailscaleState.stopped, message: 'Tailscale is off.')];
      final c = TailscaleCubit(
        ensure: EnsureTailscale(ts),
        watchHub: WatchHub(repo),
        retryHub: RetryConnection(repo),
        grace: const Duration(milliseconds: 20),
        minGap: const Duration(seconds: 5),
      );
      await settle();
      expect(ts.starts, 1);
      repo.emitHub(hubAt('ws://100.118.241.124:7420/ws'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(ts.starts, 1, reason: 'inside the gap');
      await c.retry();
      expect(ts.starts, 2);
      await c.close();
    });

    test('a device that is not supported shows nothing', () async {
      ts.current = const TailscaleStatus(TailscaleState.unsupported);
      final c = cubitFor(repo, ts);
      await settle();
      expect(c.state.visible, isFalse);
      expect(ts.starts, 0);
      await c.close();
    });
  });

  group('TailscaleBanner', () {
    Future<(FakeHubRepository, FakeTailscale, TailscaleCubit)> pump(WidgetTester tester, FakeTailscale ts, {bool startable = true}) async {
      final repo = FakeHubRepository(hubAt('ws://100.118.241.124:7420/ws'));
      final cubit = cubitFor(repo, ts);
      // Not closed: closing waits for a stream cancel that never finishes on a widget test's fake clock.
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: BlocProvider.value(value: cubit, child: const Column(children: [TailscaleBanner()]))),
      ));
      return (repo, ts, cubit);
    }

    testWidgets('it says it is starting Tailscale, then goes away once the hub answers', (tester) async {
      final gate = Completer<void>();
      final ts = _SlowTailscale(gate.future);
      final (repo, _, cubit) = await pump(tester, ts);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const Key('tailscale-banner')), findsOneWidget);
      expect(find.text('Starting Tailscale so the hub can be reached…'), findsOneWidget);

      gate.complete();
      await tester.pump(const Duration(milliseconds: 60));
      repo.emitHub(hubAt('ws://100.118.241.124:7420/ws', status: ConnectionStatus.connected));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const Key('tailscale-banner')), findsNothing);
    });

    testWidgets('a sign-in shows its button, and a stopped phone shows Try again and Open Tailscale', (tester) async {
      final ts = FakeTailscale()
        ..current = const TailscaleStatus(TailscaleState.needsLogin)
        ..steps = const [TailscaleStatus(TailscaleState.needsLogin, loginUrl: 'https://login.tailscale.com/a/xyz')];
      await pump(tester, ts);
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Tailscale needs you to sign in before it can reach your hub.'), findsOneWidget);
      expect(find.byKey(const Key('tailscale-signin')), findsOneWidget);

      final phone = FakeTailscale(startable: false)
        ..current = const TailscaleStatus(TailscaleState.stopped, message: 'Tailscale is off. Turn it on, then come back.')
        ..steps = const [TailscaleStatus(TailscaleState.stopped, message: 'Tailscale is off. Turn it on, then come back.')];
      await pump(tester, phone);
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Tailscale is off. Turn it on, then come back.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tailscale-open')));
      expect(phone.opened, 1);
      await tester.tap(find.byKey(const Key('tailscale-retry')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(phone.starts, 2);
    });

    testWidgets('no Tailscale on the device says so, with a way to get it', (tester) async {
      final ts = FakeTailscale()..current = const TailscaleStatus(TailscaleState.notInstalled);
      await pump(tester, ts);
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.textContaining("Tailscale isn't installed"), findsOneWidget);
      expect(find.byKey(const Key('tailscale-get')), findsOneWidget);
    });
  });
}

/// Starting waits for the test to let it finish.
class _SlowTailscale extends FakeTailscale {
  _SlowTailscale(this.gate) {
    current = const TailscaleStatus(TailscaleState.stopped);
  }

  final Future<void> gate;

  @override
  Stream<TailscaleStatus> start() async* {
    starts++;
    yield const TailscaleStatus(TailscaleState.starting);
    await gate;
    yield const TailscaleStatus(TailscaleState.running);
  }
}
