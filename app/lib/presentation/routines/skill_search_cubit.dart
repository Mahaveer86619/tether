import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class SkillSearchState extends Equatable {
  const SkillSearchState({this.query, this.results = const [], this.loading = false, this.failure});

  /// Null while nothing is being looked for.
  final String? query;
  final List<SkillMatch> results;
  final bool loading;
  final Failure? failure;

  bool get open => query != null;

  @override
  List<Object?> get props => [query, results, loading, failure];
}

/// View model for finding a skill: the search box on the Skills page and the
/// `/` list in the composer. Answers that arrive after a newer query are
/// dropped, so typing fast never shows stale results.
class SkillSearchCubit extends Cubit<SkillSearchState> {
  SkillSearchCubit(this._skills) : super(const SkillSearchState());

  final Skills _skills;

  Future<void> search(String query) async {
    if (state.query == query && !state.loading && state.failure == null && state.results.isNotEmpty) return;
    emit(SkillSearchState(query: query, results: state.results, loading: true));
    final r = await _skills.search(query);
    if (isClosed || state.query != query) return;
    emit(SkillSearchState(query: query, results: r.valueOrNull ?? const [], failure: r.failureOrNull));
  }

  void dismiss() => emit(const SkillSearchState());
}
