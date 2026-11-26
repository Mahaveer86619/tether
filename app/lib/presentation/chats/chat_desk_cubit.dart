import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

/// How long a chat must have been quiet for the recap to be shown on opening it.
const recapGap = Duration(hours: 12);

class ChatDeskState extends Equatable {
  const ChatDeskState({
    this.desk,
    this.busy = false,
    this.showRecap = false,
    this.prefill = '',
    this.prefillFor = '',
    this.prefillId = 0,
    this.failure,
    this.failureId = 0,
    this.notice,
    this.noticeId = 0,
  });

  /// Null until loaded, and on a hub without the desk.
  final ChatDesk? desk;
  final bool busy;

  /// The chat was opened after [recapGap] or more without a turn.
  final bool showRecap;

  /// A prompt to put back in the composer of session [prefillFor] (after a
  /// rewind); [prefillId] is bumped for each one.
  final String prefill, prefillFor;
  final int prefillId;

  final Failure? failure;
  final int failureId;
  final String? notice;
  final int noticeId;

  ChatDeskState copyWith({
    ChatDesk? desk,
    bool? busy,
    bool? showRecap,
    String? prefill,
    String? prefillFor,
    int? prefillId,
    Failure? failure,
    int? failureId,
    String? notice,
    int? noticeId,
  }) =>
      ChatDeskState(
        desk: desk ?? this.desk,
        busy: busy ?? this.busy,
        showRecap: showRecap ?? this.showRecap,
        prefill: prefill ?? this.prefill,
        prefillFor: prefillFor ?? this.prefillFor,
        prefillId: prefillId ?? this.prefillId,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
        notice: notice ?? this.notice,
        noticeId: noticeId ?? this.noticeId,
      );

  @override
  List<Object?> get props => [desk, busy, showRecap, prefill, prefillFor, prefillId, failure, failureId, notice, noticeId];
}

/// View model for what a chat shows around its composer: the recap, the
/// context meter, the handoff, Remind, and rewinding to an earlier prompt.
class ChatDeskCubit extends Cubit<ChatDeskState> {
  ChatDeskCubit({required this.chatId, required this._chats}) : super(const ChatDeskState());

  final String chatId;
  final Chats _chats;

  /// Notes when the chat was last active, so the recap shows after a gap.
  void opened(DateTime? lastActive, {DateTime? now}) {
    final gap = lastActive != null && (now ?? DateTime.now()).difference(lastActive) >= recapGap;
    if (gap != state.showRecap) emit(state.copyWith(showRecap: gap));
  }

  void dismissRecap() => emit(state.copyWith(showRecap: false));

  Future<void> load() async {
    final r = await _chats.desk(chatId);
    if (isClosed) return;
    // A hub without the desk answers 404; the chat works as before.
    r.fold((_) {}, (d) => emit(state.copyWith(desk: d)));
  }

  /// The [back]th prompt from the end (1 is the last), if there is one.
  ChatPrompt? promptBack(int back) {
    final ps = state.desk?.prompts ?? const [];
    return back >= 1 && back <= ps.length ? ps[ps.length - back] : null;
  }

  /// The prompt a timeline message stands for. One older than the desk
  /// lists still rewinds; it just has no number.
  ChatPrompt promptFor(String itemId, String text, {String session = ''}) {
    for (final p in state.desk?.prompts ?? const <ChatPrompt>[]) {
      if (p.itemId == itemId && (session.isEmpty || p.session == session)) return p;
    }
    return ChatPrompt(itemId: itemId, n: 0, text: text, session: session);
  }

  /// Goes back to before [to]: the hub starts a session with the
  /// conversation up to it, and [to] comes back in the composer.
  Future<bool> rewind(ChatPrompt to) async {
    emit(state.copyWith(busy: true));
    final r = await _chats.rewind(chatId, to);
    if (isClosed) return false;
    return r.fold(
      (f) {
        emit(state.copyWith(busy: false, failure: f, failureId: state.failureId + 1));
        return false;
      },
      (res) {
        emit(state.copyWith(
          busy: false,
          showRecap: false,
          prefill: res.text,
          prefillFor: res.session,
          prefillId: state.prefillId + 1,
          notice: res.note.isNotEmpty ? res.note : 'Rewound to before prompt ${res.prompt > 0 ? res.prompt : to.n}. Edit it and send.',
          noticeId: state.noticeId + 1,
        ));
        load();
        return true;
      },
    );
  }

  /// Continues in a fresh session that starts from a summary of the chat.
  Future<bool> handoff() async {
    emit(state.copyWith(busy: true));
    final r = await _chats.handoff(chatId);
    if (isClosed) return false;
    return r.fold(
      (f) {
        emit(state.copyWith(busy: false, failure: f, failureId: state.failureId + 1));
        return false;
      },
      (_) {
        emit(state.copyWith(busy: false, notice: 'A fresh session carries on from a summary', noticeId: state.noticeId + 1));
        load();
        return true;
      },
    );
  }

  Future<void> setRemind(bool on) async {
    final r = await _chats.setRemind(chatId, on: on);
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)),
      (d) => emit(state.copyWith(desk: d)),
    );
  }
}
