import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

class WorkspacesState extends Equatable {
  const WorkspacesState({this.roots = const [], this.failure, this.failureId = 0});

  final List<WorkspaceRoot> roots;
  final Failure? failure;
  final int failureId;

  @override
  List<Object?> get props => [roots, failure, failureId];
}

/// View model for workspace roots: the folders new projects are made in.
class WorkspacesCubit extends Cubit<WorkspacesState> {
  WorkspacesCubit({required this._load, required this._set}) : super(const WorkspacesState());

  final LoadWorkspaces _load;
  final SetWorkspaceRoot _set;

  Future<void> load() async => _apply(await _load());

  Future<void> add(String node, String path) async => _apply(await _set(node, path));

  Future<void> remove(WorkspaceRoot r) async => _apply(await _set(r.node, r.path, remove: true));

  void _apply(Result<List<WorkspaceRoot>> result) {
    if (isClosed) return;
    result.fold(
      (f) => emit(WorkspacesState(roots: state.roots, failure: f, failureId: state.failureId + 1)),
      (roots) => emit(WorkspacesState(roots: roots, failureId: state.failureId)),
    );
  }
}

/// Settings section: each device's workspace roots, with suggestions taken
/// from where its sessions ran.
class WorkspacesSection extends StatelessWidget {
  const WorkspacesSection({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<WorkspacesCubit>()..load(),
        child: const _WorkspacesBody(),
      );
}

class _WorkspacesBody extends StatelessWidget {
  const _WorkspacesBody();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hub = context.select<HubCubit, HubSnapshot>((h) => h.state.hub);
    final cubit = context.read<WorkspacesCubit>();
    return BlocConsumer<WorkspacesCubit, WorkspacesState>(
      listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
      listener: (context, s) => showFailure(context, s.failure!),
      builder: (context, s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Workspaces', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Folders on each device where new projects are created. Projects you worked in are remembered on their own.',
              style: TextStyle(color: c.muted, fontSize: 13)),
          for (final n in hub.sortedNodes) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(osIcon(n.os), size: 16, color: c.muted),
                const SizedBox(width: 8),
                Text(n.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                OnlineDot(online: n.online),
              ],
            ),
            for (final r in s.roots.where((r) => r.node == n.name))
              Row(
                children: [
                  const SizedBox(width: 24),
                  Expanded(child: Text(r.path, style: monoStyle(context, size: 13))),
                  IconButton(
                    tooltip: 'Remove',
                    iconSize: 18,
                    icon: Icon(Icons.close_rounded, color: c.faint),
                    onPressed: () => cubit.remove(r),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final sug in hub.suggestedRoots(n.name).where((p) => !s.roots.contains(WorkspaceRoot(node: n.name, path: p))))
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: Text(sug, style: monoStyle(context, size: 12)),
                      onPressed: () => cubit.add(n.name, sug),
                    ),
                  ActionChip(
                    key: Key('add-root-${n.name}'),
                    avatar: const Icon(Icons.create_new_folder_outlined, size: 16),
                    label: const Text('Add a folder…'),
                    onPressed: () async {
                      final path = await _askPath(context, n.name);
                      if (path != null) cubit.add(n.name, path);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<String?> _askPath(BuildContext context, String node) => showDialog<String>(context: context, builder: (_) => _PathDialog(node: node));
}

class _PathDialog extends StatefulWidget {
  const _PathDialog({required this.node});

  final String node;

  @override
  State<_PathDialog> createState() => _PathDialogState();
}

class _PathDialogState extends State<_PathDialog> {
  final _path = TextEditingController();

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Workspace on ${widget.node}'),
        content: TextField(
          key: const Key('root-path'),
          controller: _path,
          autofocus: true,
          style: monoStyle(context, size: 13),
          decoration: const InputDecoration(labelText: 'Folder', hintText: r'~/projects or C:\Users\me\projects'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(key: const Key('save-root'), onPressed: () => Navigator.pop(context, _path.text), child: const Text('Add')),
        ],
      );
}
