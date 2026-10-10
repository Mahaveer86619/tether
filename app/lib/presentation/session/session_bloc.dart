import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

// ---- events ----

sealed class SessionEvent extends Equatable {
  const SessionEvent();
  @override
  List<Object?> get props => [];
}

/// Starts watching the session and the hub.
class SessionOpened extends SessionEvent {
  const SessionOpened();
}

class MessageSubmitted extends SessionEvent {
  const MessageSubmitted(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

class ForkModeChanged extends SessionEvent {
  const ForkModeChanged(this.forking);
  final bool forking;
  @override
  List<Object?> get props => [forking];
}

class InterruptRequested extends SessionEvent {
  const InterruptRequested();
}

// ---- state ----

class SessionViewState extends Equatable {
  const SessionViewState({
    required this.sessionId,
    this.session,
    this.nodeOnline = false,
    this.timeline,
    this.approvals = const [],
    this.forking = false,
    this.sending = false,
    this.sentId = 0,
    this.forkedTo,
    this.failure,
    this.failureId = 0,
  });

  final String sessionId;
  final Session? session;
  final bool nodeOnline;
  final TimelineSnapshot? timeline;
  final List<Approval> approvals;
  final bool forking, sending;

  /// Bumped after each successful send, so the composer knows to clear.
  final int sentId;

  /// Set once a fork was created; the view navigates to it.
  final String? forkedTo;
  final Failure? failure;
  final int failureId;

  List<TimelineItem> get items => timeline?.items ?? const [];
  bool get loading => timeline?.loading ?? true;
  bool get canType => nodeOnline && (forking || (session?.acceptsInput ?? false));

  SessionViewState copyWith({
    Session? session,
    bool? nodeOnline,
    TimelineSnapshot? timeline,
    List<Approval>? approvals,
    bool? forking,
    bool? sending,
    int? sentId,
    String? Function()? forkedTo,
    Failure? failure,
    int? failureId,
  }) =>
      SessionViewState(
        sessionId: sessionId,
        session: session ?? this.session,
        nodeOnline: nodeOnline ?? this.nodeOnline,
        timeline: timeline ?? this.timeline,
        approvals: approvals ?? this.approvals,
        forking: forking ?? this.forking,
        sending: sending ?? this.sending,
        sentId: sentId ?? this.sentId,
        forkedTo: forkedTo != null ? forkedTo() : this.forkedTo,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props =>
      [sessionId, session, nodeOnline, timeline, approvals, forking, sending, sentId, forkedTo, failure, failureId];
}

// ---- bloc ----

/// View model for one session screen.
class SessionBloc extends Bloc<SessionEvent, SessionViewState> {
  SessionBloc({
    required String sessionId,
    required this._watchHub,
    required this._watchTimeline,
    required SendMessage sendMessage,
    required this._interrupt,
  })  : _send = sendMessage,
        super(SessionViewState(sessionId: sessionId)) {
    on<SessionOpened>(_onOpened);
    on<MessageSubmitted>(_onSubmitted);
    on<ForkModeChanged>((e, emit) => emit(state.copyWith(forking: e.forking)));
    on<InterruptRequested>(_onInterrupt);
  }

  final WatchHub _watchHub;
  final WatchTimeline _watchTimeline;
  final SendMessage _send;
  final InterruptSession _interrupt;

  Future<void> _onOpened(SessionOpened e, Emitter<SessionViewState> emit) async {
    await Future.wait([
      emit.forEach<HubSnapshot>(_watchHub(), onData: (hub) {
        final session = hub.sessions[state.sessionId];
        return state.copyWith(
          session: session,
          nodeOnline: session != null && (hub.nodes[session.node]?.online ?? false),
          approvals: hub.approvalsFor(state.sessionId),
        );
      }),
      emit.forEach<TimelineSnapshot>(_watchTimeline(state.sessionId), onData: (t) => state.copyWith(timeline: t)),
    ]);
  }

  Future<void> _onSubmitted(MessageSubmitted e, Emitter<SessionViewState> emit) async {
    if (state.sending) return;
    emit(state.copyWith(sending: true));
    final fork = state.forking;
    final result = await _send(state.sessionId, e.text, fork: fork);
    result.fold(
      (f) => emit(state.copyWith(sending: false, failure: f, failureId: state.failureId + 1)),
      (id) => emit(state.copyWith(
        sending: false,
        sentId: state.sentId + 1,
        forking: false,
        forkedTo: fork ? () => id : null,
      )),
    );
  }

  Future<void> _onInterrupt(InterruptRequested e, Emitter<SessionViewState> emit) async {
    final result = await _interrupt(state.sessionId);
    if (result.failureOrNull case final f?) emit(state.copyWith(failure: f, failureId: state.failureId + 1));
  }
}
