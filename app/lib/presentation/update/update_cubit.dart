import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../core/version.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

enum UpdateStage {
  /// Up to date, skipped, or nothing this app can install.
  none,
  available,
  downloading,

  /// Downloaded and checked; on Windows it's applied when the app restarts.
  ready,
  installing,
  failed,
}

class UpdateState extends Equatable {
  const UpdateState({this.release, this.stage = UpdateStage.none, this.received = 0, this.total = 0, this.forced = false, this.path = '', this.failure});

  final Release? release;
  final UpdateStage stage;
  final int received, total;

  /// This version is below the release's minimum: nothing else until it updates.
  final bool forced;

  /// The downloaded file, once [stage] is ready.
  final String path;
  final Failure? failure;

  bool get visible => stage != UpdateStage.none;
  double? get progress => total > 0 ? received / total : null;

  UpdateState copyWith({UpdateStage? stage, int? received, int? total, String? path, Failure? Function()? failure}) => UpdateState(
        release: release,
        forced: forced,
        stage: stage ?? this.stage,
        received: received ?? this.received,
        total: total ?? this.total,
        path: path ?? this.path,
        failure: failure != null ? failure() : this.failure,
      );

  @override
  List<Object?> get props => [release, stage, received, total, forced, path, failure];
}

/// App-wide view model for updating the app: checks when it starts, every
/// few hours, and whenever the hub announces a release; downloads, checks
/// and installs it.
class UpdateCubit extends Cubit<UpdateState> {
  UpdateCubit({
    required this._updates,
    required this._watchHub,
    this.current = appVersion,
    this.every = const Duration(hours: 6),
    required this._exit,
  }) : super(const UpdateState());

  final AppUpdates _updates;
  final WatchHub _watchHub;
  final void Function() _exit;
  final String current;
  final Duration every;

  StreamSubscription<HubSnapshot>? _hubSub;
  Timer? _timer;
  bool _dismissed = false;

  void start() {
    if (_updates.platform == null) return;
    _hubSub = _watchHub().listen((hub) {
      final r = hub.update;
      if (r != null && r.version != state.release?.version) _consider(r);
      // A hub reached for the first time, or again, may know of a release.
      if (hub.connected && state.release == null && _timer == null) _schedule();
    });
  }

  void _schedule() {
    check();
    _timer = Timer.periodic(every, (_) => check());
  }

  Future<void> check() async {
    final r = await _updates.latest();
    if (isClosed) return;
    if (r.valueOrNull case final release?) await _consider(release);
  }

  Future<void> _consider(Release r) async {
    if (state.stage == UpdateStage.downloading || state.stage == UpdateStage.installing) return;
    if (!isOlderVersion(current, r.version) || _updates.assetFor(r) == null) {
      emit(const UpdateState());
      return;
    }
    final forced = r.minSupported.isNotEmpty && isOlderVersion(current, r.minSupported);
    final skipped = !forced && await _updates.skipped() == r.version;
    if (isClosed) return;
    final same = state.release?.version == r.version;
    emit(UpdateState(release: r, forced: forced, stage: skipped || (_dismissed && same && !forced) ? UpdateStage.none : UpdateStage.available));
    if (!skipped && await _updates.notified() != r.version) {
      await _updates.setNotified(r.version);
      await _updates.notify('Tether ${r.version} is available', _summary(r.notes));
    }
  }

  static String _summary(String notes) {
    final line = notes.split('\n').map((l) => l.replaceAll(RegExp(r'^[-*#\s]+|\*\*'), '').trim()).firstWhere((l) => l.isNotEmpty, orElse: () => 'Open Tether to update.');
    return line.length > 120 ? '${line.substring(0, 117)}…' : line;
  }

  /// Downloads and checks the release, then on Android opens the installer.
  /// On Windows it waits for [restart].
  Future<void> update() async {
    final r = state.release;
    final asset = r == null ? null : _updates.assetFor(r);
    if (asset == null || state.stage == UpdateStage.downloading) return;
    emit(state.copyWith(stage: UpdateStage.downloading, received: 0, total: asset.size, failure: () => null));
    final got = await _updates.download(asset, onProgress: (received, total) {
      if (!isClosed) emit(state.copyWith(received: received, total: total));
    });
    if (isClosed) return;
    switch (got) {
      case Err(:final failure):
        emit(state.copyWith(stage: UpdateStage.failed, failure: () => failure));
      case Ok(:final value):
        emit(state.copyWith(stage: UpdateStage.ready, path: value));
        if (_updates.platform == 'android') await install();
    }
  }

  /// Hands the download to the installer; on Windows the app then exits
  /// and comes back updated.
  Future<void> install() async {
    if (state.path.isEmpty) return;
    emit(state.copyWith(stage: UpdateStage.installing));
    final r = await _updates.install(state.path);
    if (isClosed) return;
    switch (r) {
      case Err(:final failure):
        emit(state.copyWith(stage: UpdateStage.failed, failure: () => failure));
      case Ok():
        if (_updates.platform == 'windows') {
          _exit();
        } else {
          // The installer is on screen; if it's cancelled, Install stays offered.
          emit(state.copyWith(stage: UpdateStage.ready));
        }
    }
  }

  /// Hides the release for good, unless it's required.
  Future<void> skip() async {
    final r = state.release;
    if (r == null || state.forced) return;
    await _updates.skip(r.version);
    emit(state.copyWith(stage: UpdateStage.none));
  }

  /// Hides the banner until the app next starts.
  void later() {
    if (state.forced) return;
    _dismissed = true;
    emit(state.copyWith(stage: UpdateStage.none));
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _hubSub?.cancel();
    return super.close();
  }
}
