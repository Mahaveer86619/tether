import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/presentation/health/connection_banners.dart';
import 'package:tether/presentation/health/connection_doctor.dart';
import 'package:tether/presentation/tailscale/tailscale_cubit.dart';
import 'package:tether/presentation/theme/theme.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeHubRepository repo;
  late FakeTailscale ts;
  late FakeHubProbe probe;
  var online = true;

  HubSnapshot snap(ConnectionStatus status) => snapshotWith([]).copyWith(status: status, endpoint: 'ws://100.64.0.1:7420/ws');

  ConnectionDoctor doctor() => ConnectionDoctor(
        health: ConnectionHealth(repo, ts, probe, () async => online),
        reconnectWait: const Duration(milliseconds: 300),
        tunnelWait: const Duration(milliseconds: 300),
        settle: const Duration(milliseconds: 20),
      );

  setUp(() {
    online = true;
    repo = FakeHubRepository(snap(ConnectionStatus.connected));
    ts = FakeTailscale();
    probe = FakeHubProbe();
  });

  test('a connection that answers is left alone', () async {
    final d = doctor();
    await d.run();
    expect(repo.retries, 0);
    expect(d.state.phase, DoctorPhase.idle);
  });

  test('a connection gone quiet is made again without anything showing', () async {
    repo.alive = false;
    repo.onRetry = () {
      repo.alive = true;
      repo.emitHub(snap(ConnectionStatus.connected));
    };
    final d = doctor();
    final seen = <DoctorPhase>[];
    d.stream.listen((s) => seen.add(s.phase));
    await d.run();
    expect(repo.retries, 1);
    expect(seen, isNot(contains(DoctorPhase.failed)));
    expect(d.state.phase, DoctorPhase.idle);
    expect(ts.reconnects, 0, reason: 'Tailscale was not touched for that');
  });

  test('a tunnel that is up but carries nothing is switched off and on', () async {
    repo.emitHub(snap(ConnectionStatus.offline));
    repo.onRetry = () {
      if (ts.reconnects > 0) repo.emitHub(snap(ConnectionStatus.connected));
    };
    final d = doctor();
    await d.run();
    expect(ts.reconnects, 1);
    expect(d.state.phase, DoctorPhase.idle);
    expect(d.state.problem, isNull);
  });

  test('with no network it says so, and what to do', () async {
    repo.emitHub(snap(ConnectionStatus.offline));
    online = false;
    final d = doctor();
    await d.run();
    expect(d.state.phase, DoctorPhase.failed);
    expect(d.state.problem!.kind, ProblemKind.noInternet);
    expect(d.state.problem!.steps, isNotEmpty);
    expect(ts.reconnects, 0);
  });

  test('Tailscale that is off and cannot be started is reported with its own steps', () async {
    repo.emitHub(snap(ConnectionStatus.offline));
    ts.current = const TailscaleStatus(TailscaleState.stopped);
    ts.steps = const [TailscaleStatus(TailscaleState.stopped)];
    final d = doctor();
    await d.run();
    expect(ts.starts, 1);
    expect(d.state.problem!.kind, ProblemKind.tailscaleOff);
  });

  test('Tailscale that needs a sign-in says so', () async {
    repo.emitHub(snap(ConnectionStatus.offline));
    ts.current = const TailscaleStatus(TailscaleState.needsLogin);
    ts.steps = const [TailscaleStatus(TailscaleState.needsLogin)];
    final d = doctor();
    await d.run();
    expect(d.state.problem!.kind, ProblemKind.tailscaleLogin);
  });

  test('when every fix fails, a tailnet hub that does not answer is a stuck tunnel; one that answers refuses the app', () async {
    repo.emitHub(snap(ConnectionStatus.offline));
    var d = doctor();
    await d.run();
    expect(d.state.problem!.kind, ProblemKind.tailscaleStuck);
    expect(ts.reconnects, 1, reason: 'it tried switching Tailscale first');

    probe.hubs['100.64.0.1'] = const HubHello(version: '0.17.8', trusted: false);
    d = doctor();
    await d.run();
    expect(d.state.problem!.kind, ProblemKind.hubRefuses);
  });

  test('a rejected token goes straight to what to do about it', () async {
    repo.emitHub(snap(ConnectionStatus.unauthorized));
    final d = doctor();
    await d.run();
    expect(d.state.problem!.kind, ProblemKind.hubRefuses);
    expect(repo.retries, 0);
  });

  test('a hub with no address configured is not the doctor\'s business', () async {
    repo.emitHub(snapshotWith([]));
    final d = doctor();
    await d.run();
    expect(d.state.phase, DoctorPhase.idle);
    expect(repo.retries, 0);
  });

  test('dismissing the failure card clears it', () async {
    repo.emitHub(snap(ConnectionStatus.offline));
    online = false;
    final d = doctor();
    await d.run();
    d.dismiss();
    expect(d.state.phase, DoctorPhase.idle);
  });

  testWidgets('a failure is shown with what to do, and nothing shows while the doctor is still working', (tester) async {
    // A hub on the local network, so Tailscale's own banner has no timer running.
    repo.emitHub(snapshotWith([]).copyWith(status: ConnectionStatus.offline, endpoint: 'ws://192.168.1.5:7420/ws'));
    online = false;
    final d = doctor();
    final tailscale = TailscaleCubit(ensure: EnsureTailscale(ts), watchHub: WatchHub(repo), retryHub: RetryConnection(repo));
    Widget app() => MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: MultiBlocProvider(providers: [BlocProvider.value(value: d), BlocProvider.value(value: tailscale)], child: const Scaffold(body: ConnectionBanners())),
        );
    await tester.pumpWidget(app());
    expect(find.byKey(const Key('connection-problem')), findsNothing);

    await tester.runAsync(d.run);
    await tester.pump();
    expect(find.byKey(const Key('connection-problem')), findsOneWidget);
    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.textContaining('Turn on Wi-Fi or mobile data'), findsOneWidget);
    expect(find.byKey(const Key('connection-try-again')), findsOneWidget);
    expect(find.byKey(const Key('connection-open-tailscale')), findsNothing, reason: 'not a Tailscale problem');

  });
}
