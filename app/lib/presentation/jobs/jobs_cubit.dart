import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/jobs.dart';

class JobsState extends Equatable {
  const JobsState({
    this.jobs = const {},
    this.loaded = false,
    this.selected,
    this.logs = const [],
    this.busy = const {},
    this.failure,
    this.failureId = 0,
  });

  final Map<String, Job> jobs;
  final bool loaded;
  final String? selected;

  /// The selected job's output, oldest line first.
  final List<String> logs;

  /// Jobs with an action on its way.
  final Set<String> busy;
  final Failure? failure;
  final int failureId;

  /// Live jobs first, then newest first.
  List<Job> get list => jobs.values.toList()
    ..sort((a, b) {
      if (a.state.isLive != b.state.isLive) return a.state.isLive ? -1 : 1;
      return (b.created ?? DateTime(0)).compareTo(a.created ?? DateTime(0));
    });

  Job? get selectedJob => selected == null ? null : jobs[selected];

  JobsState copyWith({
    Map<String, Job>? jobs,
    bool? loaded,
    String? Function()? selected,
    List<String>? logs,
    Set<String>? busy,
    Failure? failure,
    int? failureId,
  }) =>
      JobsState(
        jobs: jobs ?? this.jobs,
        loaded: loaded ?? this.loaded,
        selected: selected == null ? this.selected : selected(),
        logs: logs ?? this.logs,
        busy: busy ?? this.busy,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [jobs, loaded, selected, logs, busy, failure, failureId];
}

/// View model for the Jobs page: the list, kept live from the hub's pushes,
/// and the selected job's log, read again every few seconds while shown.
class JobsCubit extends Cubit<JobsState> {
  JobsCubit({required this._jobs, this.logEvery = const Duration(seconds: 2)}) : super(const JobsState());

  final Jobs _jobs;
  final Duration logEvery;
  StreamSubscription<Job>? _changes;
  Timer? _logTimer;

  Future<void> start() async {
    _changes ??= _jobs.changes.listen(_onChange);
    await load();
  }

  Future<void> load() async {
    final result = await _jobs.list();
    if (isClosed) return;
    result.fold(
      _fail,
      (list) => emit(state.copyWith(jobs: {for (final j in list) j.id: j}, loaded: true)),
    );
  }

  void _onChange(Job j) {
    if (isClosed) return;
    final jobs = {...state.jobs};
    if (j.removed) {
      jobs.remove(j.id);
    } else {
      jobs[j.id] = j;
    }
    emit(state.copyWith(jobs: jobs, selected: state.selected == j.id && j.removed ? () => null : null));
  }

  void _fail(Failure f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1, loaded: true));

  void select(String? id) {
    _logTimer?.cancel();
    emit(state.copyWith(selected: () => id, logs: const []));
    if (id == null) return;
    _readLogs();
    _logTimer = Timer.periodic(logEvery, (_) => _readLogs());
  }

  Future<void> _readLogs() async {
    final id = state.selected;
    if (id == null) return;
    final result = await _jobs.logs(id);
    if (isClosed || state.selected != id) return;
    if (result case Ok(:final value)) emit(state.copyWith(logs: value));
  }

  /// Returns the failure, or null when the job was started.
  Future<Failure?> startJob(NewJobRequest request) async {
    final result = await _jobs.start(request);
    if (isClosed) return null;
    return result.fold((f) => f, (job) {
      emit(state.copyWith(jobs: {...state.jobs, job.id: job}));
      select(job.id);
      return null;
    });
  }

  Future<void> act(String id, JobAction action) async {
    emit(state.copyWith(busy: {...state.busy, id}));
    final result = await _jobs.act(id, action);
    if (isClosed) return;
    emit(state.copyWith(busy: {...state.busy}..remove(id)));
    if (result case Err(:final failure)) _fail(failure);
  }

  Future<void> forget(String id) async {
    final result = await _jobs.forget(id);
    if (isClosed) return;
    result.fold(_fail, (_) {
      if (state.selected == id) select(null);
      emit(state.copyWith(jobs: {...state.jobs}..remove(id)));
    });
  }

  @override
  Future<void> close() {
    _logTimer?.cancel();
    _changes?.cancel();
    return super.close();
  }
}
