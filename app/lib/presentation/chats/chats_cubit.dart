import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class ChatsState extends Equatable {
  const ChatsState({this.busy = const {}, this.failure, this.failureId = 0, this.notice, this.noticeId = 0});

  /// Chats with a change in flight.
  final Set<String> busy;
  final Failure? failure;
  final int failureId;

  /// Something to tell the user once, e.g. "Moved to tether".
  final String? notice;
  final int noticeId;

  @override
  List<Object?> get props => [busy, failure, failureId, notice, noticeId];
}

/// App-wide view model for acting on chats: rename, archive, move them to
/// another folder, unlink a session, copy what was said.
class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({required this._chats}) : super(const ChatsState());

  final Chats _chats;

  bool get supported => _chats.supported;

  Future<T?> _run<T>(String chatId, Future<Result<T>> Function() body, {String? done}) async {
    emit(ChatsState(busy: {...state.busy, chatId}, failureId: state.failureId, noticeId: state.noticeId));
    final r = await body();
    final busy = {...state.busy}..remove(chatId);
    return r.fold(
      (f) {
        emit(ChatsState(busy: busy, failure: f, failureId: state.failureId + 1, noticeId: state.noticeId));
        return null;
      },
      (v) {
        emit(ChatsState(
          busy: busy,
          failureId: state.failureId,
          notice: done,
          noticeId: done == null ? state.noticeId : state.noticeId + 1,
        ));
        return v;
      },
    );
  }

  Future<void> rename(String chatId, String title) => _run(chatId, () => _chats.rename(chatId, title));

  Future<void> archive(String chatId, {bool archived = true}) =>
      _run(chatId, () => _chats.archive(chatId, archived: archived), done: archived ? 'Chat archived' : 'Chat restored');

  /// Moves the chat to [target], carrying the conversation, or with
  /// [move] false only records it for the next session.
  Future<Chat?> retarget(String chatId, ChatTarget target, {bool move = true}) =>
      _run(chatId, () => _chats.retarget(chatId, target, move: move), done: move ? 'The chat carries on there' : 'Target saved');

  /// Sends through the chat, which starts a new session if its own is gone.
  Future<bool> send(String chatId, String text, {List<String> attachments = const []}) async =>
      await _run(chatId, () => _chats.send(chatId, text, attachments: attachments)) != null;

  Future<void> unlink(String chatId, String sessionId) => _run(chatId, () => _chats.unlink(chatId, sessionId), done: 'Session unlinked');

  /// Makes a chat of a session that has none; returns its id.
  Future<String?> adopt(String sessionId) async => (await _run(sessionId, () => _chats.forSession(sessionId)))?.id;

  /// The conversation as Markdown, or null if it couldn't be read.
  Future<String?> transcript(String chatId) async => (await _run(chatId, () => _chats.context(chatId)))?.markdown;
}
