import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class RoutinesState extends Equatable {
  const RoutinesState({
    this.report,
    this.skills = const [],
    this.busy = const {},
    this.loading = true,
    this.allTime = false,
    this.twoRuns = false,
    this.drafted = '',
    this.draftedId = 0,
    this.failure,
    this.failureId = 0,
  });

  /// Null until the first load.
  final RoutineReport? report;

  /// Proposals waiting for approval and approved skills.
  final List<SkillInfo> skills;

  /// Names of skills, and examples of routines, with a request under way.
  final Set<String> busy;
  final bool loading, allTime, twoRuns;

  /// The session that is drafting a skill, once asked for; [draftedId] counts them.
  final String drafted;
  final int draftedId;
  final Failure? failure;
  final int failureId;

  RoutinesState copyWith({
    RoutineReport? report,
    List<SkillInfo>? skills,
    Set<String>? busy,
    bool? loading,
    bool? allTime,
    bool? twoRuns,
    String? drafted,
    int? draftedId,
    Failure? failure,
    int? failureId,
  }) =>
      RoutinesState(
        report: report ?? this.report,
        skills: skills ?? this.skills,
        busy: busy ?? this.busy,
        loading: loading ?? this.loading,
        allTime: allTime ?? this.allTime,
        twoRuns: twoRuns ?? this.twoRuns,
        drafted: drafted ?? this.drafted,
        draftedId: draftedId ?? this.draftedId,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [report, skills, busy, loading, allTime, twoRuns, drafted, draftedId, failure, failureId];
}

/// View model for the routines page: what keeps being asked, read from the
/// hub's history, and the skills made from it: drafting, approving and going
/// back a version.
class RoutinesCubit extends Cubit<RoutinesState> {
  RoutinesCubit({required this._load, required this._skills}) : super(const RoutinesState());

  final LoadRoutines _load;
  final Skills _skills;

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final results = await Future.wait([_load(days: state.allTime ? 0 : 30, runs: state.twoRuns ? 2 : 3), _skills.list()]);
    if (isClosed) return;
    final report = results[0] as Result<RoutineReport>;
    final skills = results[1] as Result<List<SkillInfo>>;
    final failure = report.failureOrNull ?? skills.failureOrNull;
    emit(state.copyWith(
      loading: false,
      report: report.valueOrNull,
      skills: skills.valueOrNull,
      failure: failure,
      failureId: failure == null ? state.failureId : state.failureId + 1,
    ));
  }

  Future<void> refreshSkills() async {
    final r = await _skills.list();
    if (isClosed) return;
    emit(state.copyWith(skills: r.valueOrNull, failure: r.failureOrNull, failureId: r.failureOrNull == null ? state.failureId : state.failureId + 1));
  }

  Future<void> setAllTime(bool v) {
    emit(state.copyWith(allTime: v));
    return load();
  }

  Future<void> setTwoRuns(bool v) {
    emit(state.copyWith(twoRuns: v));
    return load();
  }

  /// One skill with the text of every version, or null.
  Future<SkillDetail?> detail(String name) async {
    final r = await _skills.detail(name);
    if (isClosed) return null;
    if (r.failureOrNull case final f?) emit(state.copyWith(failure: f, failureId: state.failureId + 1));
    return r.valueOrNull;
  }

  Future<void> approve(String name) => _decide(name, () => _skills.approve(name));
  Future<void> dismiss(String name) => _decide(name, () => _skills.dismiss(name));
  Future<void> rollback(String name, int version) => _decide(name, () => _skills.rollback(name, version));

  Future<void> _decide(String name, Future<Result<SkillInfo>> Function() call) async {
    emit(state.copyWith(busy: {...state.busy, name}));
    final r = await call();
    if (isClosed) return;
    emit(state.copyWith(busy: {...state.busy}..remove(name), failure: r.failureOrNull, failureId: r.failureOrNull == null ? state.failureId : state.failureId + 1));
    await refreshSkills();
  }

  /// Starts a session that drafts a skill for the routine.
  Future<void> draft(String example) async {
    emit(state.copyWith(busy: {...state.busy, example}));
    final r = await _skills.draft(example);
    if (isClosed) return;
    emit(state.copyWith(
      busy: {...state.busy}..remove(example),
      drafted: r.valueOrNull,
      draftedId: r.valueOrNull == null ? state.draftedId : state.draftedId + 1,
      failure: r.failureOrNull,
      failureId: r.failureOrNull == null ? state.failureId : state.failureId + 1,
    ));
  }
}
