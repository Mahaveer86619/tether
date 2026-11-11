import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class OnboardingState extends Equatable {
  const OnboardingState({
    this.tailscale,
    this.hubs = const [],
    this.scanning = false,
    this.searched = false,
    this.starting = false,
    this.connecting = '',
    this.needsCodeFor = '',
    this.failure,
    this.failureId = 0,
  });

  /// Null until Tailscale has been asked.
  final TailscaleStatus? tailscale;
  final List<FoundHub> hubs;
  final bool scanning, searched, starting;

  /// The address being connected to.
  final String connecting;

  /// A hub that was picked but wants a pairing code first.
  final String needsCodeFor;
  final Failure? failure;
  final int failureId;

  OnboardingState copyWith({
    TailscaleStatus? tailscale,
    List<FoundHub>? hubs,
    bool? scanning,
    bool? searched,
    bool? starting,
    String? connecting,
    String? needsCodeFor,
    Failure? failure,
    int? failureId,
  }) =>
      OnboardingState(
        tailscale: tailscale ?? this.tailscale,
        hubs: hubs ?? this.hubs,
        scanning: scanning ?? this.scanning,
        searched: searched ?? this.searched,
        starting: starting ?? this.starting,
        connecting: connecting ?? this.connecting,
        needsCodeFor: needsCodeFor ?? this.needsCodeFor,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [tailscale, hubs, scanning, searched, starting, connecting, needsCodeFor, failure, failureId];
}

/// First-run connecting: the hubs this device used before, and the Tether
/// hubs found among the devices on the tailnet.
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required this._find, required this._tailscale, required this._viaTailnet}) : super(const OnboardingState());

  final FindHubs _find;
  final EnsureTailscale _tailscale;
  final ConnectOverTailnet _viaTailnet;

  bool get canSearch => _find.canSearch;

  Future<void> start() async {
    emit(state.copyWith(hubs: await _find.known()));
    if (isClosed || !canSearch) return;
    final s = await _tailscale.check();
    if (isClosed) return;
    emit(state.copyWith(tailscale: s));
    if (s.running) await scan();
  }

  /// Asks every online device on the tailnet whether a hub answers there.
  Future<void> scan() async {
    if (state.scanning) return;
    emit(state.copyWith(scanning: true));
    final found = await _find();
    if (isClosed) return;
    emit(state.copyWith(scanning: false, searched: true, hubs: found));
  }

  /// Brings Tailscale up (signing in if it must), then searches.
  Future<void> turnOnTailscale() async {
    if (state.starting) return;
    emit(state.copyWith(starting: true));
    TailscaleStatus? last;
    await for (final s in _tailscale.start()) {
      if (isClosed) return;
      last = s;
      emit(state.copyWith(tailscale: s));
    }
    if (isClosed) return;
    emit(state.copyWith(starting: false));
    if (last?.running ?? false) await scan();
  }

  /// A hub that lets this device in connects at once; any other asks for a
  /// pairing code first.
  Future<void> choose(FoundHub hub) async {
    if (!hub.trusted) {
      emit(state.copyWith(needsCodeFor: hub.url));
      return;
    }
    emit(state.copyWith(connecting: hub.url, needsCodeFor: ''));
    final r = await _viaTailnet(hub.url, name: hub.name);
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(connecting: '', failure: f, failureId: state.failureId + 1)),
      (_) => emit(state.copyWith(connecting: '')),
    );
  }

  Future<void> openTailscale() => _tailscale.openApp();
}
