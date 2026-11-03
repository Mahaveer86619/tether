import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class RoutinesState extends Equatable {
  const RoutinesState({this.report, this.loading = true, this.allTime = false, this.twoRuns = false, this.failure, this.failureId = 0});

  /// Null until the first load.
  final RoutineReport? report;
  final bool loading, allTime, twoRuns;
  final Failure? failure;
  final int failureId;

  RoutinesState copyWith({RoutineReport? report, bool? loading, bool? allTime, bool? twoRuns, Failure? failure, int? failureId}) => RoutinesState(
        report: report ?? this.report,
        loading: loading ?? this.loading,
        allTime: allTime ?? this.allTime,
        twoRuns: twoRuns ?? this.twoRuns,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [report, loading, allTime, twoRuns, failure, failureId];
}

/// View model for the routines page: what keeps being asked, read from the
/// hub's history. It only reads.
class RoutinesCubit extends Cubit<RoutinesState> {
  RoutinesCubit({required this._load}) : super(const RoutinesState());

  final LoadRoutines _load;

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final result = await _load(days: state.allTime ? 0 : 30, runs: state.twoRuns ? 2 : 3);
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(loading: false, failure: f, failureId: state.failureId + 1)),
      (report) => emit(state.copyWith(loading: false, report: report)),
    );
  }

  Future<void> setAllTime(bool v) {
    emit(state.copyWith(allTime: v));
    return load();
  }

  Future<void> setTwoRuns(bool v) {
    emit(state.copyWith(twoRuns: v));
    return load();
  }
}
