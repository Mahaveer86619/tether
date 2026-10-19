import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

/// Pass as the preferred node to start on the hub, in a scratch folder.
const hubScratch = '\u0000hub';

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
    this.newProject = false,
    this.roots = const [],
    this.suggestedRoots = const [],
    this.root = '',
    this.projectName = '',
    this.scratch = false,
    this.hubNode = '',
  });

  final List<Node> nodes;
  final String? node;
  final List<String> folders;
  final String cwd, model, permissionMode;

  /// Start in a new folder made in a workspace root, rather than an
  /// existing project.
  final bool newProject;

  /// The selected node's declared roots, and likely ones (parents of its
  /// recent projects) not declared yet.
  final List<String> roots, suggestedRoots;
  final String root, projectName;

  /// Run on the hub's machine in a scratch folder; [node] is then [hubNode].
  final bool scratch;

  /// The machine hub sessions run on, or empty if it isn't online.
  final String hubNode;
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
    bool? newProject,
    List<String>? roots,
    List<String>? suggestedRoots,
    String? root,
    String? projectName,
    bool? scratch,
    String? hubNode,
  }) =>
      NewSessionState(
        scratch: scratch ?? this.scratch,
        hubNode: hubNode ?? this.hubNode,
        newProject: newProject ?? this.newProject,
        roots: roots ?? this.roots,
        suggestedRoots: suggestedRoots ?? this.suggestedRoots,
        root: root ?? this.root,
        projectName: projectName ?? this.projectName,
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
  List<Object?> get props =>
      [nodes, node, folders, cwd, model, permissionMode, submitting, createdId, failure, failureId, newProject, roots, suggestedRoots, root, projectName, scratch, hubNode];
}

/// View model for the new-session form.
class NewSessionCubit extends Cubit<NewSessionState> {
  NewSessionCubit({
    required HubSnapshot hub,
    required CreateSession createSession,
    required this._drafts,
    required this._loadWorkspaces,
    required this._setRoot,
    String? preferredNode,
  })  : _hub = hub,
        _create = createSession,
        super(const NewSessionState()) {
    final online = hub.sortedNodes.where((n) => n.online).toList();
    final hubNode = online.any((n) => n.name == hub.hubNode) ? hub.hubNode : '';
    emit(state.copyWith(nodes: online, hubNode: hubNode));
    if (preferredNode == hubScratch && hubNode.isNotEmpty) {
      selectScratch();
    } else {
      final node = online.any((n) => n.name == preferredNode) ? preferredNode : online.firstOrNull?.name;
      if (node != null) selectNode(node);
    }
    _loadRoots();
  }

  final LoadWorkspaces _loadWorkspaces;
  final SetWorkspaceRoot _setRoot;
  List<WorkspaceRoot> _allRoots = const [];

  Future<void> _loadRoots() async {
    final result = await _loadWorkspaces();
    if (isClosed) return;
    if (result.valueOrNull case final roots?) {
      _allRoots = roots;
      _applyRoots();
    }
  }

  void _applyRoots() {
    final node = state.node;
    if (node == null) return;
    final roots = [for (final r in _allRoots) if (r.node == node) r.path];
    final suggested = [for (final s in _hub.suggestedRoots(node)) if (!roots.contains(s)) s];
    final root = [...roots, ...suggested].contains(state.root) ? state.root : (roots.firstOrNull ?? suggested.firstOrNull ?? '');
    emit(state.copyWith(roots: roots, suggestedRoots: suggested, root: root));
  }

  void setNewProject(bool on) => emit(state.copyWith(newProject: on));
  void setRoot(String root) => emit(state.copyWith(root: root));
  void setProjectName(String name) => emit(state.copyWith(projectName: name));

  bool get _windows => state.nodes.firstWhere((n) => n.name == state.node, orElse: () => const Node(name: '', online: false)).os == 'windows';

  /// The folder a new project would be created as, or null if not valid yet.
  String? get newProjectPath => state.root.isEmpty ? null : projectPath(state.root, state.projectName, windows: _windows);

  final HubSnapshot _hub;
  final CreateSession _create;
  final Drafts _drafts;
  Timer? _draftSave;

  static const _draftKey = 'quick-start';

  // Only the quick-start box keeps a draft; the full form starts empty.
  bool _keepsDraft = false;

  /// The prompt typed last time and never sent.
  Future<String> loadDraft() {
    _keepsDraft = true;
    return _drafts.load(_draftKey);
  }

  void saveDraft(String text) {
    _draftSave?.cancel();
    _draftSave = Timer(const Duration(milliseconds: 500), () => _drafts.save(_draftKey, text));
  }

  @override
  Future<void> close() {
    _draftSave?.cancel();
    return super.close();
  }

  void selectNode(String node) {
    final folders = _hub.recentFolders(node);
    emit(state.copyWith(node: node, folders: folders, cwd: folders.firstOrNull ?? '', root: '', scratch: false));
    _applyRoots();
  }

  void selectScratch() {
    if (state.hubNode.isEmpty) return;
    emit(state.copyWith(node: state.hubNode, folders: const [], cwd: '', root: '', scratch: true, newProject: false));
  }

  void setCwd(String cwd) => emit(state.copyWith(cwd: cwd));
  void setModel(String model) => emit(state.copyWith(model: model));
  void setPermissionMode(String mode) => emit(state.copyWith(permissionMode: mode));

  Future<void> submit(String prompt, {List<String> attachments = const []}) async {
    if (state.submitting) return;
    var cwd = state.cwd;
    if (state.newProject && !state.scratch) {
      final path = newProjectPath;
      if (path == null) {
        emit(state.copyWith(
          failure: ValidationFailure(state.root.isEmpty ? 'Add a workspace root for this device first.' : 'Name the project with a plain folder name.'),
          failureId: state.failureId + 1,
        ));
        return;
      }
      cwd = path;
    }
    emit(state.copyWith(submitting: true));
    // A suggested root that gets used is remembered as a workspace.
    if (state.newProject && !state.roots.contains(state.root)) await _setRoot(state.node ?? '', state.root);
    final result = await _create(NewSessionRequest(
      node: state.scratch ? '' : state.node ?? '',
      prompt: prompt,
      cwd: state.scratch ? '' : cwd,
      model: state.model,
      permissionMode: state.permissionMode,
      createCwd: state.newProject && !state.scratch,
      scratch: state.scratch,
      attachments: attachments,
    ));
    result.fold(
      (f) => emit(state.copyWith(submitting: false, failure: f, failureId: state.failureId + 1)),
      (id) {
        if (_keepsDraft) {
          _draftSave?.cancel();
          _drafts.save(_draftKey, '');
        }
        emit(state.copyWith(submitting: false, createdId: id));
      },
    );
  }
}
