import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class UsageState extends Equatable {
  const UsageState({this.summary, this.failure, this.failureId = 0});

  /// Null until the first load.
  final UsageSummary? summary;
  final Failure? failure;
  final int failureId;

  @override
  List<Object?> get props => [summary, failure, failureId];
}

/// View model for the usage page. Refreshes while open, since sessions keep
/// using tokens.
class UsageCubit extends Cubit<UsageState> {
  UsageCubit({required this._load}) : super(const UsageState());

  final LoadUsage _load;
  Timer? _refresh;

  Future<void> start() async {
    await load();
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => load());
  }

  Future<void> load() async {
    final result = await _load();
    if (isClosed) return;
    result.fold(
      (f) => emit(UsageState(summary: state.summary, failure: f, failureId: state.failureId + 1)),
      (summary) => emit(UsageState(summary: summary, failureId: state.failureId)),
    );
  }

  @override
  Future<void> close() {
    _refresh?.cancel();
    return super.close();
  }
}
