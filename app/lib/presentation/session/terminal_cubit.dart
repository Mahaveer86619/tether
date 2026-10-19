import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class TerminalState extends Equatable {
  const TerminalState({this.screen, this.loading = false, this.sending = false, this.failure, this.failureId = 0});

  final ScreenSnapshot? screen;
  final bool loading, sending;
  final Failure? failure;
  final int failureId;

  TerminalState copyWith({ScreenSnapshot? screen, bool? loading, bool? sending, Failure? failure, int? failureId}) => TerminalState(
        screen: screen ?? this.screen,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [screen, loading, sending, failure, failureId];
}

/// View model for one session's terminal: its screen, and keys to press in
/// it when a dialog doesn't come through as a card.
class TerminalCubit extends Cubit<TerminalState> {
  TerminalCubit({required this.sessionId, required this._terminal}) : super(const TerminalState());

  final String sessionId;
  final TerminalControl _terminal;

  Future<void> refresh() async {
    emit(state.copyWith(loading: true));
    final r = await _terminal.screen(sessionId);
    r.fold(
      (f) => emit(state.copyWith(loading: false, failure: f, failureId: state.failureId + 1)),
      (s) => emit(state.copyWith(loading: false, screen: s)),
    );
  }

  /// Presses keys, then shows the screen they led to.
  Future<void> press(List<String> keys, {String text = ''}) async {
    emit(state.copyWith(sending: true));
    final r = await _terminal.press(sessionId, keys, text: text);
    emit(state.copyWith(sending: false));
    if (r.failureOrNull case final f?) {
      emit(state.copyWith(failure: f, failureId: state.failureId + 1));
      return;
    }
    await refresh();
  }
}
