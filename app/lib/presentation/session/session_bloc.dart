import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../core/result.dart';
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
  const MessageSubmitted(this.text, {this.attachments = const []});
  final String text;

  /// Artifact ids sent with the message.
  final List<String> attachments;
  @override
  List<Object?> get props => [text, attachments];
}

/// Have the hub keep a copy of this session (or stop).
class GlobalToggled extends SessionEvent {
  const GlobalToggled(this.global);
  final bool global;
  @override
  List<Object?> get props => [global];
}

/// Continue this global session on the hub's machine with a first message.
class ContinueOnHubRequested extends SessionEvent {
  const ContinueOnHubRequested(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

/// The composer's text changed; it is kept as a draft until sent.
class DraftChanged extends SessionEvent {
  const DraftChanged(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

/// Text selected in the chat, to be quoted in the composer.
class QuoteRequested extends SessionEvent {
  const QuoteRequested(this.text);
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

/// Stops Claude's current turn; the session stays open.
class InterruptRequested extends SessionEvent {
  const InterruptRequested();
}

/// The interrupt has had time to land; still busy means it didn't.
class _InterruptTimedOut extends SessionEvent {
  const _InterruptTimedOut();
}

/// Ends the session's Claude Code process (tmux or headless only).
class EndRequested extends SessionEvent {
  const EndRequested();
}

/// Sends an outbox message again; the hub passes a repeat on only once.
class OutboxRetried extends SessionEvent {
  const OutboxRetried(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// Drops an outbox message without sending it.
class OutboxDiscarded extends SessionEvent {
  const OutboxDiscarded(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
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
    this.quote = '',
    this.quoteId = 0,
    this.forkedTo,
    this.draft,
    this.failure,
    this.failureId = 0,
    this.outbox = const [],
    this.interrupting = false,
    this.interruptSlow = false,
  });

  /// An interrupt is on its way; [interruptSlow] once it's taking too long,
  /// so the view can offer Esc again, the screen, or ending the session.
  final bool interrupting, interruptSlow;

  final String sessionId;

  /// Messages from this device the timeline doesn't show yet.
  final List<OutboxEntry> outbox;
  final Session? session;
  final bool nodeOnline;
  final TimelineSnapshot? timeline;
  final List<Approval> approvals;
  final bool forking, sending;

  /// Bumped after each successful send, so the composer knows to clear.
  final int sentId;

  /// The latest text to quote; [quoteId] is bumped so quoting the same text twice still lands.
  final String quote;
  final int quoteId;

  /// Set once a fork was created; the view navigates to it.
  final String? forkedTo;

  /// Unsent text from last time, once loaded; the composer starts with it.
  final String? draft;
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
    String? quote,
    int? quoteId,
    String? draft,
    String? Function()? forkedTo,
    Failure? failure,
    int? failureId,
    List<OutboxEntry>? outbox,
    bool? interrupting,
    bool? interruptSlow,
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
        quote: quote ?? this.quote,
        quoteId: quoteId ?? this.quoteId,
        draft: draft ?? this.draft,
        forkedTo: forkedTo != null ? forkedTo() : this.forkedTo,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
        outbox: outbox ?? this.outbox,
        interrupting: interrupting ?? this.interrupting,
        interruptSlow: interruptSlow ?? this.interruptSlow,
      );

  @override
  List<Object?> get props =>
      [sessionId, session, nodeOnline, timeline, approvals, forking, sending, sentId, quote, quoteId, forkedTo, draft, failure, failureId, outbox, interrupting, interruptSlow];
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
    required this._endSession,
    required this._drafts,
    required this._setGlobal,
    required this._continueOnHub,
    required this._outbox,
    this.interruptTimeout = const Duration(seconds: 8),
  })  : _send = sendMessage,
        super(SessionViewState(sessionId: sessionId)) {
    on<SessionOpened>(_onOpened);
    on<MessageSubmitted>(_onSubmitted);
    on<DraftChanged>(_onDraftChanged);
    on<ForkModeChanged>((e, emit) => emit(state.copyWith(forking: e.forking)));
    on<QuoteRequested>((e, emit) {
      final text = e.text.trim();
      if (text.isNotEmpty) emit(state.copyWith(quote: text, quoteId: state.quoteId + 1));
    });
    on<InterruptRequested>(_onInterrupt);
    on<EndRequested>(_onEnd);
    on<GlobalToggled>(_onGlobal);
    on<ContinueOnHubRequested>(_onContinue);
    on<OutboxRetried>(_onRetry);
    on<_InterruptTimedOut>((e, emit) {
      if (state.interrupting && (state.session?.isBusy ?? false)) emit(state.copyWith(interruptSlow: true));
    });
    on<OutboxDiscarded>((e, emit) => _setOutbox(emit, [for (final o in state.outbox) if (o.id != e.id) o]));
  }

  final Outbox _outbox;
  static final _rand = Random.secure();

  static String _newId() => List.generate(16, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  void _setOutbox(Emitter<SessionViewState> emit, List<OutboxEntry> entries) {
    emit(state.copyWith(outbox: entries));
    unawaited(_outbox.save(state.sessionId, entries));
  }

  void _updateEntry(Emitter<SessionViewState> emit, String id, OutboxEntry Function(OutboxEntry) change) =>
      _setOutbox(emit, [for (final o in state.outbox) o.id == id ? change(o) : o]);

  /// Sends an outbox entry, recording how it went on the entry itself.
  Future<void> _deliver(OutboxEntry entry, Emitter<SessionViewState> emit) async {
    final result = await _send(state.sessionId, entry.text, attachments: entry.attachments, clientId: entry.id);
    switch (result) {
      case Ok():
        _updateEntry(emit, entry.id, (o) => o.copyWith(state: OutboxState.sent, sentAt: DateTime.now(), error: ''));
        // The message can reach the timeline before the hub's answer does;
        // with no later timeline change it would otherwise stay shown twice.
        if (state.timeline case final t?) {
          final pending = Outbox.pending(state.outbox, t.items);
          if (pending.length != state.outbox.length) _setOutbox(emit, pending);
        }
      case Err(:final failure):
        _updateEntry(emit, entry.id, (o) => o.copyWith(state: OutboxState.failed, error: failure.userMessage));
        emit(state.copyWith(failure: failure, failureId: state.failureId + 1));
    }
  }

  Future<void> _onRetry(OutboxRetried e, Emitter<SessionViewState> emit) async {
    final entry = state.outbox.where((o) => o.id == e.id).firstOrNull;
    if (entry == null || entry.state == OutboxState.sending) return;
    _updateEntry(emit, entry.id, (o) => o.copyWith(state: OutboxState.sending, error: ''));
    await _deliver(entry, emit);
  }

  final SetSessionGlobal _setGlobal;
  final ContinueOnHub _continueOnHub;

  Future<void> _onGlobal(GlobalToggled e, Emitter<SessionViewState> emit) async {
    final result = await _setGlobal(state.sessionId, global: e.global);
    if (result.failureOrNull case final f?) emit(state.copyWith(failure: f, failureId: state.failureId + 1));
  }

  // The new session opens like a fork does.
  Future<void> _onContinue(ContinueOnHubRequested e, Emitter<SessionViewState> emit) async {
    final result = await _continueOnHub(state.sessionId, e.text);
    result.fold(
      (f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)),
      (id) => emit(state.copyWith(forkedTo: () => id)),
    );
  }

  final WatchHub _watchHub;
  final WatchTimeline _watchTimeline;
  final SendMessage _send;
  final InterruptSession _interrupt;
  final EndSession _endSession;
  final Drafts _drafts;
  Timer? _draftSave;
  String? _pendingDraft;

  Future<void> _onOpened(SessionOpened e, Emitter<SessionViewState> emit) async {
    emit(state.copyWith(draft: await _drafts.load(state.sessionId)));
    final saved = await _outbox.load(state.sessionId);
    if (saved.isNotEmpty) _setOutbox(emit, saved);
    await Future.wait([
      emit.forEach<HubSnapshot>(_watchHub(), onData: (hub) {
        final session = hub.sessions[state.sessionId];
        final stopped = !(session?.isBusy ?? false);
        if (stopped) _interruptTimer?.cancel();
        return state.copyWith(
          session: session,
          interrupting: stopped ? false : null,
          interruptSlow: stopped ? false : null,
          nodeOnline: session != null && (hub.nodes[session.node]?.online ?? false),
          approvals: hub.approvalsFor(state.sessionId),
        );
      }),
      emit.forEach<TimelineSnapshot>(_watchTimeline(state.sessionId), onData: (t) {
        final pending = Outbox.pending(state.outbox, t.items);
        if (pending.length == state.outbox.length) return state.copyWith(timeline: t);
        unawaited(_outbox.save(state.sessionId, pending));
        return state.copyWith(timeline: t, outbox: pending);
      }),
    ]);
  }

  Future<void> _onSubmitted(MessageSubmitted e, Emitter<SessionViewState> emit) async {
    if (state.sending) return;
    if (!state.forking) return _queue(e, emit);
    emit(state.copyWith(sending: true));
    final fork = state.forking;
    final result = await _send(state.sessionId, e.text, fork: fork, attachments: e.attachments);
    result.fold(
      (f) => emit(state.copyWith(sending: false, failure: f, failureId: state.failureId + 1)),
      (id) {
        _draftSave?.cancel();
        _pendingDraft = null;
        _drafts.save(state.sessionId, '');
        emit(state.copyWith(
          sending: false,
          sentId: state.sentId + 1,
          forking: false,
          forkedTo: fork ? () => id : null,
        ));
      },
    );
  }

  /// A message to this session goes into the outbox first, and the
  /// composer clears at once: the text is safe there whatever happens next.
  Future<void> _queue(MessageSubmitted e, Emitter<SessionViewState> emit) async {
    if (_send.check(state.sessionId, e.text, attachments: e.attachments) case final f?) {
      emit(state.copyWith(failure: f, failureId: state.failureId + 1));
      return;
    }
    final entry = OutboxEntry(id: _newId(), session: state.sessionId, text: e.text.trim(), attachments: e.attachments, created: DateTime.now());
    _draftSave?.cancel();
    _pendingDraft = null;
    unawaited(_drafts.save(state.sessionId, ''));
    emit(state.copyWith(sending: true, sentId: state.sentId + 1));
    _setOutbox(emit, [...state.outbox, entry]);
    await _deliver(entry, emit);
    emit(state.copyWith(sending: false));
  }

  // Written a moment after typing stops, not on every key.
  void _onDraftChanged(DraftChanged e, Emitter<SessionViewState> emit) {
    _pendingDraft = e.text;
    _draftSave?.cancel();
    _draftSave = Timer(const Duration(milliseconds: 500), _flushDraft);
  }

  void _flushDraft() {
    if (_pendingDraft case final text?) _drafts.save(state.sessionId, text);
    _pendingDraft = null;
  }

  // Events still queued are handled first, so the last edit is written.
  @override
  Future<void> close() async {
    _interruptTimer?.cancel();
    await super.close();
    _draftSave?.cancel();
    _flushDraft();
  }

  Future<void> _onEnd(EndRequested e, Emitter<SessionViewState> emit) async {
    final result = await _endSession(state.sessionId);
    if (result.failureOrNull case final f?) emit(state.copyWith(failure: f, failureId: state.failureId + 1));
  }

  Timer? _interruptTimer;

  /// How long an interrupt gets before the view offers other ways out.
  final Duration interruptTimeout;

  Future<void> _onInterrupt(InterruptRequested e, Emitter<SessionViewState> emit) async {
    emit(state.copyWith(interrupting: true, interruptSlow: false));
    final result = await _interrupt(state.sessionId);
    if (result.failureOrNull case final f?) {
      emit(state.copyWith(interrupting: false, failure: f, failureId: state.failureId + 1));
      return;
    }
    _interruptTimer?.cancel();
    _interruptTimer = Timer(interruptTimeout, () {
      if (!isClosed) add(const _InterruptTimedOut());
    });
  }
}
