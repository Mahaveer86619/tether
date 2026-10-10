import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class NewSessionState extends Equatable {
  const NewSessionState({
    this.nodes = const [],
    this.node,
    this.folders = const [],
    this.cwd = '',
    this.model = '',
    this.permissionMode = '',
    this.submitting = false,
    this.createdId,
    this.failure,
    this.failureId = 0,
  });

  final List<Node> nodes;
  final String? node;
  final List<String> folders;
  final String cwd, model, permissionMode;
  final bool submitting;
  final String? createdId;
  final Failure? failure;
  final int failureId;

  NewSessionState copyWith({
    List<Node>? nodes,
    String? node,
    List<String>? folders,
    String? cwd,
    String? model,
    String? permissionMode,
    bool? submitting,
    String? createdId,
    Failure? failure,
    int? failureId,
  }) =>
      NewSessionState(
        nodes: nodes ?? this.nodes,
        node: node ?? this.node,
        folders: folders ?? this.folders,
        cwd: cwd ?? this.cwd,
        model: model ?? this.model,
        permissionMode: permissionMode ?? this.permissionMode,
        submitting: submitting ?? this.submitting,
        createdId: createdId ?? this.createdId,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [nodes, node, folders, cwd, model, permissionMode, submitting, createdId, failure, failureId];
}

/// View model for the new-session form.
class NewSessionCubit extends Cubit<NewSessionState> {
  NewSessionCubit({required HubSnapshot hub, required CreateSession createSession, String? preferredNode})
      : _hub = hub,
        _create = createSession,
        super(const NewSessionState()) {
    final online = hub.sortedNodes.where((n) => n.online).toList();
    final node = online.any((n) => n.name == preferredNode) ? preferredNode : online.firstOrNull?.name;
    emit(state.copyWith(nodes: online));
    if (node != null) selectNode(node);
  }

  final HubSnapshot _hub;
  final CreateSession _create;

  void selectNode(String node) {
    final folders = _hub.recentFolders(node);
    emit(state.copyWith(node: node, folders: folders, cwd: folders.firstOrNull ?? ''));
  }

  void setCwd(String cwd) => emit(state.copyWith(cwd: cwd));
  void setModel(String model) => emit(state.copyWith(model: model));
  void setPermissionMode(String mode) => emit(state.copyWith(permissionMode: mode));

  Future<void> submit(String prompt) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true));
    final result = await _create(NewSessionRequest(
      node: state.node ?? '',
      prompt: prompt,
      cwd: state.cwd,
      model: state.model,
      permissionMode: state.permissionMode,
    ));
    result.fold(
      (f) => emit(state.copyWith(submitting: false, failure: f, failureId: state.failureId + 1)),
      (id) => emit(state.copyWith(submitting: false, createdId: id)),
    );
  }
}
