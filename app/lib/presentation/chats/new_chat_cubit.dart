import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class NewChatState extends Equatable {
  const NewChatState({this.target, this.preview, this.submitting = false, this.failure, this.failureId = 0, this.chatId, this.sessionId, this.project = ''});

  /// The project the chat goes in; empty for a one-off.
  final String project;

  /// Where to start; null leaves it to the hub (auto).
  final ChatTarget? target;

  /// What auto would pick for the text so far, or null if Claude would
  /// work it out.
  final TargetCandidate? preview;
  final bool submitting;
  final Failure? failure;
  final int failureId;

  /// Set once started: the chat (null on a hub without chats) and its
  /// first session.
  final String? chatId, sessionId;

  NewChatState copyWith({
    ChatTarget? Function()? target,
    TargetCandidate? Function()? preview,
    bool? submitting,
    Failure? failure,
    int? failureId,
    String? chatId,
    String? sessionId,
    String? project,
  }) =>
      NewChatState(
        target: target != null ? target() : this.target,
        preview: preview != null ? preview() : this.preview,
        submitting: submitting ?? this.submitting,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
        chatId: chatId ?? this.chatId,
        sessionId: sessionId ?? this.sessionId,
        project: project ?? this.project,
      );

  @override
  List<Object?> get props => [target, preview, submitting, failure, failureId, chatId, sessionId, project];
}

/// View model for the new-chat screen: the draft, where it will run, and
/// starting it.
class NewChatCubit extends Cubit<NewChatState> {
  NewChatCubit({required this._chats, required this._drafts, required WatchHub watchHub, String node = ''}) : _hub = watchHub, super(const NewChatState()) {
    if (node.isNotEmpty) {
      final folders = watchHub.current.recentFolders(node);
      emit(NewChatState(target: ChatTarget(mode: TargetMode.manual, node: node, cwd: folders.firstOrNull ?? '')));
    } else {
      _preselectProject();
    }
  }

  final Chats _chats;
  final Drafts _drafts;
  final WatchHub _hub;
  Timer? _draftSave, _previewDebounce;
  static const _draftKey = 'new-chat';
  static const _projectKey = 'new-chat-project';
  static final _rand = Random.secure();

  Future<void> _preselectProject() async {
    final last = await _drafts.load(_projectKey);
    final p = _hub.current.projectInfos[last];
    if (isClosed || p == null || state.target != null || state.project.isNotEmpty) return;
    setProject(p);
  }

  /// Puts the chat in [project] and runs it in [folder], or in the project's
  /// folder on an online device; null makes it a one-off and leaves the target.
  void setProject(ProjectInfo? project, {ProjectFolder? folder}) {
    if (project == null) {
      emit(state.copyWith(project: ''));
      return;
    }
    final nodes = _hub.current.nodes;
    final f = folder ?? project.folders.where((f) => nodes[f.node]?.online ?? false).firstOrNull ?? project.folders.firstOrNull;
    emit(state.copyWith(project: project.id, target: f == null ? null : () => ChatTarget(mode: TargetMode.manual, node: f.node, cwd: f.cwd)));
  }

  Future<String> loadDraft() => _drafts.load(_draftKey);

  /// Saves the draft and, while the target is auto, refreshes what auto
  /// would pick for it.
  void textChanged(String text) {
    _draftSave?.cancel();
    _draftSave = Timer(const Duration(milliseconds: 500), () => _drafts.save(_draftKey, text));
    if (state.target != null || !_chats.supported) return;
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 450), () => _preview(text));
  }

  Future<void> _preview(String text) async {
    if (text.trim().isEmpty) {
      emit(state.copyWith(preview: () => null));
      return;
    }
    final r = await _chats.suggestions(text);
    if (isClosed || state.target != null) return;
    if (r.valueOrNull case final s?) emit(state.copyWith(preview: () => s.pick));
  }

  void setTarget(ChatTarget? target) => emit(state.copyWith(target: () => target));

  Future<void> submit(String text, {List<String> attachments = const [], String skill = ''}) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true));
    final id = List.generate(16, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final r = await _chats.start(NewChatRequest(prompt: text, target: state.target, attachments: attachments, clientId: id, skill: skill, project: state.project));
    r.fold(
      (f) => emit(state.copyWith(submitting: false, failure: f, failureId: state.failureId + 1)),
      (made) {
        _draftSave?.cancel();
        _drafts.save(_draftKey, '');
        _drafts.save(_projectKey, state.project);
        emit(NewChatState(target: state.target, project: state.project, chatId: made.$1?.id, sessionId: made.$2, failureId: state.failureId));
      },
    );
  }

  @override
  Future<void> close() {
    _draftSave?.cancel();
    _previewDebounce?.cancel();
    return super.close();
  }
}
