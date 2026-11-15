import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import '../tailscale/tailscale_cubit.dart';

enum DoctorPhase { idle, checking, mending, failed }

/// What the doctor could not put right, and so what the owner has to do.
enum ProblemKind { noInternet, tailscaleMissing, tailscaleOff, tailscaleLogin, tailscaleStuck, hubDown, hubRefuses }

class ConnectionProblem extends Equatable {
  const ConnectionProblem(this.kind, {this.detail = ''});

  final ProblemKind kind;
  final String detail;

  String get title => switch (kind) {
        ProblemKind.noInternet => 'No internet connection',
        ProblemKind.tailscaleMissing => 'Tailscale is not installed',
        ProblemKind.tailscaleOff => 'Tailscale is off',
        ProblemKind.tailscaleLogin => 'Tailscale needs you to sign in',
        ProblemKind.tailscaleStuck => 'Tailscale is on but not getting through',
        ProblemKind.hubDown => "The hub's machine isn't answering",
        ProblemKind.hubRefuses => "The hub answers, but this app can't connect",
      };

  /// What to do, in order.
  List<String> get steps => switch (kind) {
        ProblemKind.noInternet => const ['Turn on Wi-Fi or mobile data.', 'Come back to Tether; it connects by itself.'],
        ProblemKind.tailscaleMissing => const ['Install Tailscale from the Play Store or tailscale.com and sign in to your tailnet.', 'Come back to Tether.'],
        ProblemKind.tailscaleOff => const ['Open Tailscale and switch it on.', 'Come back to Tether; it connects by itself.'],
        ProblemKind.tailscaleLogin => const ['Open Tailscale and sign in.', 'Come back to Tether; it connects by itself.'],
        ProblemKind.tailscaleStuck => const [
            'Open Tailscale, switch it off, wait a few seconds and switch it on.',
            'Check that the hub\'s machine shows as connected in Tailscale.',
            'Come back to Tether and press Try again.',
          ],
        ProblemKind.hubDown => const [
            'Check that the hub\'s machine is on and connected to the internet.',
            'Check that it shows as connected in Tailscale.',
            'On that machine, check the hub is running: `systemctl --user status tether-hub`.',
            'Then press Try again.',
          ],
        ProblemKind.hubRefuses => const [
            'The hub is running but turned this app away. Open Settings and save the hub address and token again, or pair this device with a new code.',
          ],
      };

  @override
  List<Object?> get props => [kind, detail];
}

class DoctorState extends Equatable {
  const DoctorState({this.phase = DoctorPhase.idle, this.problem});

  final DoctorPhase phase;
  final ConnectionProblem? problem;

  /// The doctor is putting something right, which nobody needs to see.
  bool get quiet => phase == DoctorPhase.checking || phase == DoctorPhase.mending;

  @override
  List<Object?> get props => [phase, problem];
}

/// A small doctor for the connection. When the app comes back to the screen
/// (from the recents, or after the system cleared it from memory) it checks
/// that the hub answers, and if not it works down a list of fixes without
/// showing anything: reconnect, check the network, bring Tailscale up, switch
/// it off and on for a tunnel that went stale in the background. Only when
/// every fix has failed does it say what is wrong and what the owner can do.
class ConnectionDoctor extends Cubit<DoctorState> {
  ConnectionDoctor({
    required this._health,
    this.probeTimeout = const Duration(seconds: 3),
    this.reconnectWait = const Duration(seconds: 6),
    this.tunnelWait = const Duration(seconds: 12),
    this.settle = const Duration(milliseconds: 200),
  }) : super(const DoctorState());

  final ConnectionHealth _health;
  final Duration probeTimeout, reconnectWait, tunnelWait, settle;
  bool _running = false;

  /// Checks, and puts right what it can. Safe to call at any time; one run at a time.
  Future<void> run() async {
    if (_running || isClosed) return;
    final hub = _health.hub;
    if (hub.endpoint.isEmpty) return;
    _running = true;
    try {
      emit(const DoctorState(phase: DoctorPhase.checking));
      // A connection that was just made gets a moment to finish, before it is judged.
      if (hub.status == ConnectionStatus.connecting && await _connected(reconnectWait)) return _healthy();
      if (_health.hub.connected && await _health.alive(probeTimeout)) return _healthy();
      if (_health.hub.status == ConnectionStatus.unauthorized) return _fail(const ConnectionProblem(ProblemKind.hubRefuses));

      emit(const DoctorState(phase: DoctorPhase.mending));
      // 1. A fresh connection fixes a socket that went quiet.
      _health.reconnectSocket();
      if (await _connected(reconnectWait)) return _healthy();
      if (isClosed) return;

      // 2. Without a network nothing else will help.
      if (!await _health.online()) {
        // It may be coming back (the phone just woke): give it a moment.
        await Future<void>.delayed(settle * 5);
        if (!await _health.online()) return _fail(const ConnectionProblem(ProblemKind.noInternet));
        _health.reconnectSocket();
        if (await _connected(reconnectWait)) return _healthy();
      }

      // 3. Tailscale: bring it up, or switch a stale tunnel off and on.
      final endpoint = _health.hub.endpoint;
      if (isTailnetEndpoint(endpoint)) {
        var status = await _health.tailscale();
        if (!status.running) {
          await for (final s in _health.startTailscale()) {
            status = s;
          }
          if (!status.running) {
            return _fail(ConnectionProblem(switch (status.state) {
              TailscaleState.notInstalled => ProblemKind.tailscaleMissing,
              TailscaleState.needsLogin => ProblemKind.tailscaleLogin,
              _ => ProblemKind.tailscaleOff,
            }, detail: status.message));
          }
          _health.reconnectSocket();
          if (await _connected(tunnelWait)) return _healthy();
        }
        if (await _health.reconnectTailscale()) {
          _health.reconnectSocket();
          if (await _connected(tunnelWait)) return _healthy();
          // Once more: Tailscale takes a few seconds to bring its routes back.
          _health.reconnectSocket();
          if (await _connected(reconnectWait)) return _healthy();
        }
      }

      // 4. Nothing worked: say what is wrong.
      final uri = Uri.tryParse(endpoint.contains('://') ? endpoint : 'ws://$endpoint');
      final reachable = uri != null && uri.host.isNotEmpty && await _health.hubAnswers(uri.host, uri.hasPort ? uri.port : 7420);
      _fail(ConnectionProblem(reachable ? ProblemKind.hubRefuses : (isTailnetEndpoint(endpoint) ? ProblemKind.tailscaleStuck : ProblemKind.hubDown)));
    } finally {
      _running = false;
    }
  }

  /// Opens Tailscale from the failure card.
  Future<void> openTailscale() => _health.openTailscale();

  void dismiss() {
    if (state.phase == DoctorPhase.failed) emit(const DoctorState());
  }

  void _healthy() {
    if (!isClosed) emit(const DoctorState());
  }

  void _fail(ConnectionProblem p) {
    if (!isClosed) emit(DoctorState(phase: DoctorPhase.failed, problem: p));
  }

  /// Waits up to [within] for the hub connection, in steps of [settle]. It
  /// counts steps rather than reading the clock, so it behaves the same under
  /// a test's fake time.
  Future<bool> _connected(Duration within) async {
    for (var waited = Duration.zero;; waited += settle) {
      if (isClosed) return false;
      if (_health.hub.connected) return true;
      if (waited >= within) return false;
      await Future<void>.delayed(settle);
    }
  }
}
