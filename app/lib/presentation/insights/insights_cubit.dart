import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/prompt_desk.dart';
import '../../domain/usecases/prompt_desk_usecases.dart';

class InsightsState extends Equatable {
  const InsightsState({
    this.stats,
    this.reports = const [],
    this.allTime = false,
    this.loading = true,
    this.analyzing = false,
    this.busy = const {},
    this.done = const {},
    this.notice = '',
    this.noticeId = 0,
    this.openSession = '',
    this.openSessionId = 0,
    this.failure,
    this.failureId = 0,
  });

  /// Null until the first load.
  final InsightStats? stats;
  final List<InsightReport> reports;
  final bool allTime, loading, analyzing;

  /// Recommendations (by [recKey]) with a request under way, and those acted on.
  final Set<String> busy, done;

  /// A line to show once; [noticeId] counts them.
  final String notice;
  final int noticeId;

  /// A session to open once (a skill being drafted); [openSessionId] counts them.
  final String openSession;
  final int openSessionId;
  final Failure? failure;
  final int failureId;

  bool get running => reports.any((r) => r.running);

  InsightsState copyWith({
    InsightStats? stats,
    List<InsightReport>? reports,
    bool? allTime,
    bool? loading,
    bool? analyzing,
    Set<String>? busy,
    Set<String>? done,
    String? notice,
    int? noticeId,
    String? openSession,
    int? openSessionId,
    Failure? failure,
    int? failureId,
  }) =>
      InsightsState(
        stats: stats ?? this.stats,
        reports: reports ?? this.reports,
        allTime: allTime ?? this.allTime,
        loading: loading ?? this.loading,
        analyzing: analyzing ?? this.analyzing,
        busy: busy ?? this.busy,
        done: done ?? this.done,
        notice: notice ?? this.notice,
        noticeId: noticeId ?? this.noticeId,
        openSession: openSession ?? this.openSession,
        openSessionId: openSessionId ?? this.openSessionId,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [stats, reports, allTime, loading, analyzing, busy, done, notice, noticeId, openSession, openSessionId, failure, failureId];
}

String recKey(InsightReport report, Recommendation r) => '${report.id}/${r.kind.name}/${r.title}';

/// View model for the Insights page: what the hub measures, Claude's
/// analyses of it, and one-tap actions on what they recommend. While an
/// analysis runs, the reports are read again every few seconds.
class InsightsCubit extends Cubit<InsightsState> {
  InsightsCubit({required this._insights, this.poll = const Duration(seconds: 8)}) : super(const InsightsState());

  final Insights _insights;
  final Duration poll;
  Timer? _timer;

  int get _days => state.allTime ? 0 : 30;

  int _next(Result<Object?> r) => r.failureOrNull == null ? state.failureId : state.failureId + 1;

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final results = await Future.wait([_insights.stats(days: _days), _insights.reports()]);
    if (isClosed) return;
    final stats = results[0] as Result<InsightStats>;
    final reports = results[1] as Result<List<InsightReport>>;
    final failure = stats.failureOrNull ?? reports.failureOrNull;
    emit(state.copyWith(
      loading: false,
      stats: stats.valueOrNull,
      reports: reports.valueOrNull,
      failure: failure,
      failureId: failure == null ? state.failureId : state.failureId + 1,
    ));
    _keepPolling();
  }

  Future<void> setAllTime(bool v) {
    emit(state.copyWith(allTime: v));
    return load();
  }

  Future<void> refreshReports() async {
    final r = await _insights.reports();
    if (isClosed) return;
    final was = state.reports.where((x) => x.running).map((x) => x.id).toSet();
    final reports = r.valueOrNull;
    final finished = reports?.where((x) => was.contains(x.id) && !x.running).firstOrNull;
    emit(state.copyWith(
      reports: reports,
      notice: finished == null ? null : 'The analysis is ready: ${finished.title}',
      noticeId: finished == null ? null : state.noticeId + 1,
    ));
    _keepPolling();
  }

  void _keepPolling() {
    if (state.running) {
      _timer ??= Timer.periodic(poll, (_) => refreshReports());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> analyze() async {
    emit(state.copyWith(analyzing: true));
    final r = await _insights.analyze(days: _days);
    if (isClosed) return;
    final rep = r.valueOrNull;
    emit(state.copyWith(
      analyzing: false,
      reports: rep == null ? null : [rep, ...state.reports.where((x) => x.id != rep.id)],
      notice: rep == null ? null : 'Claude is analysing. The report shows here when it is saved.',
      noticeId: rep == null ? null : state.noticeId + 1,
      failure: r.failureOrNull,
      failureId: _next(r),
    ));
    _keepPolling();
  }

  Future<void> addRule(InsightReport report, Recommendation rec) => _act(report, rec, () async {
        final r = await _insights.addRule(rec);
        return (r, 'Added the rule "${rec.title}", switched off. Turn it on from Rules once it reads right.', '');
      });

  /// A repeated instruction made into a rule, switched off.
  Future<void> addPhraseRule(RepeatedPhrase p) =>
      addRule(const InsightReport(id: 'phrases'), Recommendation(kind: RecommendationKind.rule, title: p.label, text: p.rule));

  Future<void> draftSkill(InsightReport report, Recommendation rec) => _act(report, rec, () async {
        final r = await _insights.draftSkill(rec);
        return (r, 'Drafting the skill. It waits for your approval under Routines.', r.valueOrNull ?? '');
      });

  Future<void> _act(InsightReport report, Recommendation rec, Future<(Result<Object?>, String, String)> Function() call) async {
    final key = recKey(report, rec);
    emit(state.copyWith(busy: {...state.busy, key}));
    final (r, ok, session) = await call();
    if (isClosed) return;
    emit(state.copyWith(
      busy: {...state.busy}..remove(key),
      done: r.isOk ? {...state.done, key} : null,
      notice: r.isOk ? ok : null,
      noticeId: r.isOk ? state.noticeId + 1 : null,
      openSession: session.isEmpty ? null : session,
      openSessionId: session.isEmpty ? null : state.openSessionId + 1,
      failure: r.failureOrNull,
      failureId: _next(r),
    ));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
