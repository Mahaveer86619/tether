import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import '../../injection.dart';
import '../artifacts/artifact_widgets.dart' show fileSize;
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

class CodebasesState extends Equatable {
  const CodebasesState({this.codebases = const [], this.loading = true, this.requested = const {}, this.failure, this.failureId = 0});

  final List<Codebase> codebases;
  final bool loading;

  /// Codebases a snapshot was just asked for.
  final Set<String> requested;
  final Failure? failure;
  final int failureId;

  CodebasesState copyWith({List<Codebase>? codebases, bool? loading, Set<String>? requested, Failure? failure, int? failureId}) => CodebasesState(
        codebases: codebases ?? this.codebases,
        loading: loading ?? this.loading,
        requested: requested ?? this.requested,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [codebases, loading, requested, failure, failureId];
}

/// View model for the codebases the hub keeps copies of.
class CodebasesCubit extends Cubit<CodebasesState> {
  CodebasesCubit({required this._codebases}) : super(const CodebasesState());

  final Codebases _codebases;

  Future<void> load() async {
    final result = await _codebases.list();
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(loading: false, failure: f, failureId: state.failureId + 1)),
      (list) => emit(state.copyWith(codebases: list, loading: false)),
    );
  }

  Future<void> snapshot(String id) async {
    final result = await _codebases.snapshot(id);
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)),
      (_) => emit(state.copyWith(requested: {...state.requested, id})),
    );
  }
}

/// Settings section: each device's codebases, their last copy on the hub,
/// and the .env files in the vault (key names only).
class CodebasesSection extends StatelessWidget {
  const CodebasesSection({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<CodebasesCubit>()..load(),
        child: BlocConsumer<CodebasesCubit, CodebasesState>(
          listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
          listener: (context, s) => showFailure(context, s.failure!),
          builder: (context, s) {
            final c = context.colors;
            final byNode = <String, List<Codebase>>{};
            for (final cb in s.codebases) {
              byNode.putIfAbsent(cb.node, () => []).add(cb);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Codebases', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                    IconButton(tooltip: 'Refresh', onPressed: context.read<CodebasesCubit>().load, icon: const Icon(Icons.refresh_rounded, size: 20)),
                  ],
                ),
                Text(
                  'Each folder directly in a workspace root is a codebase. The hub keeps a copy whenever a session in it is forked, '
                  'so work can carry on with the device off. .env files are kept encrypted on the hub and only written back there; '
                  'their values are never shown.',
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
                if (s.loading && s.codebases.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
                else if (s.codebases.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text('None yet. Add a workspace root above; the folders in it show here.', style: TextStyle(color: c.faint, fontSize: 13)),
                  ),
                for (final entry in byNode.entries) ...[
                  const SizedBox(height: 14),
                  Text(entry.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
                  for (final cb in entry.value) _CodebaseTile(codebase: cb, requested: s.requested.contains(cb.id)),
                ],
              ],
            );
          },
        ),
      );
}

class _CodebaseTile extends StatelessWidget {
  const _CodebaseTile({required this.codebase, required this.requested});

  final Codebase codebase;
  final bool requested;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cb = codebase;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('codebase-${cb.id}'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 40, bottom: 8),
        leading: Icon(Icons.folder_copy_outlined, color: cb.error.isNotEmpty ? c.danger : c.muted),
        title: Text(cb.name),
        subtitle: Text(
          [
            if (cb.lastSnapshot != null) 'copied ${ago(cb.lastSnapshot)} · ${cb.files} files · ${fileSize(cb.bytes)}' else 'no copy on the hub yet',
            if (cb.gitBranch.isNotEmpty) cb.gitBranch,
            if (cb.env.isNotEmpty) '${cb.env.length} .env ${cb.env.length == 1 ? 'file' : 'files'}',
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: c.faint),
        ),
        trailing: TextButton(
          key: Key('snapshot-${cb.name}'),
          onPressed: requested ? null : () => context.read<CodebasesCubit>().snapshot(cb.id),
          child: Text(requested ? 'Copying…' : 'Snapshot now'),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(cb.path, style: monoStyle(context, size: 12, color: c.muted)),
          if (cb.gitRemote.isNotEmpty) Text(cb.gitRemote, style: TextStyle(fontSize: 12, color: c.faint)),
          if (cb.error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(cb.error, style: TextStyle(fontSize: 12.5, color: c.danger))),
          for (final e in cb.env)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: c.faint),
                  Text(e.path, style: monoStyle(context, size: 12)),
                  for (final k in e.keys) Pill(k),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
