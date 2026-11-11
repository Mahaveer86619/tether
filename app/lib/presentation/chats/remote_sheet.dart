import 'dart:async';

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
import '../ui/tokens.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

class RemoteState extends Equatable {
  const RemoteState({this.remote = const ChatRemote(), this.files = const [], this.loading = true, this.busy = false, this.failure, this.failureId = 0});

  final ChatRemote remote;
  final List<ProjectFile> files;
  final bool loading, busy;
  final Failure? failure;
  final int failureId;

  RemoteState copyWith({ChatRemote? remote, List<ProjectFile>? files, bool? loading, bool? busy, Failure? failure, int? failureId}) => RemoteState(
        remote: remote ?? this.remote,
        files: files ?? this.files,
        loading: loading ?? this.loading,
        busy: busy ?? this.busy,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [remote, files, loading, busy, failure, failureId];
}

/// A chat's remote setup: whether its project is kept in step on another
/// device, how that is going, and the setup files the hub keeps for it.
class RemoteCubit extends Cubit<RemoteState> {
  RemoteCubit(this._remote, this.chatId) : super(const RemoteState()) {
    load();
  }

  final RemoteProjects _remote;
  final String chatId;
  Timer? _poll;

  Future<void> load() async {
    final r = await _remote.status(chatId);
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(loading: false, failure: f, failureId: state.failureId + 1)),
      (remote) {
        emit(state.copyWith(remote: remote, loading: false));
        _watch(remote);
        if (remote.repo.isNotEmpty) _loadFiles(remote.repo);
      },
    );
  }

  /// While a sync is going, look again every few seconds.
  void _watch(ChatRemote r) {
    _poll?.cancel();
    if (!r.working) return;
    _poll = Timer(const Duration(seconds: 3), () async {
      final next = await _remote.status(chatId);
      if (isClosed) return;
      next.fold((_) => _watch(r), (n) {
        emit(state.copyWith(remote: n));
        _watch(n);
      });
    });
  }

  Future<void> _loadFiles(String repo) async {
    final r = await _remote.files(repo);
    if (isClosed) return;
    r.fold((_) {}, (files) => emit(state.copyWith(files: files)));
  }

  Future<void> start(String node, {required bool allowSecrets}) => _run(() async {
        final r = await _remote.start(chatId, node: node, allowSecrets: allowSecrets);
        if (r.failureOrNull != null) return r;
        await load();
        return r;
      });

  Future<void> stop() => _run(() async {
        final r = await _remote.stop(chatId);
        if (r.failureOrNull == null) await load();
        return r;
      });

  Future<void> saveFile(String path, String content) => _run(() async {
        final r = await _remote.saveFile(state.remote.repo, path, content);
        if (r.failureOrNull == null) await _loadFiles(state.remote.repo);
        return r;
      });

  Future<void> removeFile(String path) => _run(() async {
        final r = await _remote.removeFile(state.remote.repo, path);
        if (r.failureOrNull == null) await _loadFiles(state.remote.repo);
        return r;
      });

  Future<void> _run(Future<Result<void>> Function() action) async {
    emit(state.copyWith(busy: true));
    final r = await action();
    if (isClosed) return;
    final f = r.failureOrNull;
    emit(f == null ? state.copyWith(busy: false) : state.copyWith(busy: false, failure: f, failureId: state.failureId + 1));
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}

/// Opens the remote setup for a chat.
Future<void> showRemoteSheet(BuildContext context, Chat chat) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => BlocProvider(
        create: (_) => RemoteCubit(sl(), chat.id),
        child: _RemoteSheet(chat: chat, hub: context.read<HubCubit>()),
      ),
    );

class _RemoteSheet extends StatefulWidget {
  const _RemoteSheet({required this.chat, required this.hub});

  final Chat chat;
  final HubCubit hub;

  @override
  State<_RemoteSheet> createState() => _RemoteSheetState();
}

class _RemoteSheetState extends State<_RemoteSheet> {
  String? _node;
  bool _allow = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return BlocConsumer<RemoteCubit, RemoteState>(
      listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
      listener: (context, s) => showFailure(context, s.failure!),
      builder: (context, s) {
        final hub = widget.hub.state.hub;
        final here = hub.sessions[widget.chat.activeSession]?.node ?? widget.chat.target.node;
        final devices = [for (final n in hub.sortedNodes) if (n.online && n.name != here) n.name];
        final r = s.remote;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(Icons.cloud_sync_outlined, color: c.accent, size: 20),
                  const SizedBox(width: 10),
                  const Text('Remote project', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Keeps this project\'s folder in step on another device through git on the hub, and moves the chat there. Secrets never go through git: they come from the setup files below.',
                  style: TextStyle(fontSize: 13, color: c.muted),
                ),
                const SizedBox(height: 16),
                if (s.loading)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
                else if (r.on)
                  _On(remote: r, busy: s.busy)
                else if (r.repo.isEmpty)
                  Text('Only a chat that works in a project folder can be made remote. This one has none.', style: TextStyle(color: c.muted))
                else ...[
                  if (devices.isEmpty)
                    Text('No other device is online.', key: const Key('remote-no-devices'), style: TextStyle(color: c.muted))
                  else ...[
                    Text('Move it to', style: Type.meta(context, color: c.muted)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final d in devices)
                        ChoiceChip(
                          key: Key('remote-device-$d'),
                          label: Text(d),
                          selected: _node == d,
                          onSelected: (_) => setState(() => _node = d),
                        ),
                    ]),
                    CheckboxListTile(
                      key: const Key('remote-allow'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _allow,
                      onChanged: (v) => setState(() => _allow = v ?? false),
                      title: const Text('Send this project\'s setup files there', style: TextStyle(fontSize: 14)),
                      subtitle: Text('The .env and config files below, written to that device only.', style: TextStyle(fontSize: 12, color: c.muted)),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('remote-start'),
                      onPressed: _node == null || s.busy ? null : () => context.read<RemoteCubit>().start(_node!, allowSecrets: _allow),
                      icon: s.busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Make remote'),
                    ),
                  ],
                ],
                if (!s.loading && r.repo.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _Files(files: s.files),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _On extends StatelessWidget {
  const _On({required this.remote, required this.busy});

  final ChatRemote remote;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = switch (remote.state) {
      'synced' => ('In step', c.success),
      'failed' => ('Failed', c.danger),
      _ => ('Syncing…', c.accent),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.surface, borderRadius: context.round(10), border: Border.all(color: c.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label, key: const Key('remote-state'), style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (remote.synced != null) Text(ago(remote.synced), style: Type.meta(context, color: c.faint)),
              ]),
              const SizedBox(height: 8),
              Text('Works on  ${remote.sourceNode}', style: TextStyle(fontSize: 13, color: c.text)),
              Text('Follows  ${remote.mirrorNode}', style: TextStyle(fontSize: 13, color: c.muted)),
              if (remote.failed && remote.error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(remote.error, key: const Key('remote-error'), style: TextStyle(fontSize: 12.5, color: c.danger)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(key: const Key('remote-stop'), onPressed: busy ? null : () => context.read<RemoteCubit>().stop(), child: const Text('Stop keeping in step')),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Both folders stay where they are.', style: TextStyle(fontSize: 12, color: c.faint)),
        ),
      ],
    );
  }
}

class _Files extends StatelessWidget {
  const _Files({required this.files});

  final List<ProjectFile> files;

  Future<void> _edit(BuildContext context, {String path = '.env'}) async {
    final cubit = context.read<RemoteCubit>();
    final result = await showDialog<(String, String)>(context: context, builder: (_) => _FileDialog(path: path));
    if (result != null) await cubit.saveFile(result.$1, result.$2);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(child: Text('Setup files', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          TextButton.icon(key: const Key('add-project-file'), onPressed: () => _edit(context), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add')),
        ]),
        Text('Kept sealed on the hub and written to an allowed device, never into git. Values are not shown here.', style: TextStyle(fontSize: 12, color: c.muted)),
        const SizedBox(height: 8),
        if (files.isEmpty)
          Text('None yet.', key: const Key('no-project-files'), style: TextStyle(color: c.faint, fontSize: 13))
        else
          for (final f in files)
            ListTile(
              key: Key('project-file-${f.path}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_outline_rounded, size: 18, color: c.muted),
              title: Text(f.path, style: monoStyle(context, size: 13)),
              subtitle: f.keys.isEmpty ? null : Text(f.keys.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Replace', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _edit(context, path: f.path)),
                IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded, size: 18), onPressed: () => context.read<RemoteCubit>().removeFile(f.path)),
              ]),
            ),
      ],
    );
  }
}

class _FileDialog extends StatefulWidget {
  const _FileDialog({required this.path});

  final String path;

  @override
  State<_FileDialog> createState() => _FileDialogState();
}

class _FileDialogState extends State<_FileDialog> {
  late final _path = TextEditingController(text: widget.path);
  final _content = TextEditingController();

  @override
  void dispose() {
    _path.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Setup file'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              key: const Key('project-file-path'),
              controller: _path,
              autocorrect: false,
              style: monoStyle(context, size: 13.5),
              decoration: const InputDecoration(labelText: 'Path in the project', hintText: '.env or config/local.json'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('project-file-content'),
              controller: _content,
              autocorrect: false,
              enableSuggestions: false,
              minLines: 6,
              maxLines: 12,
              style: monoStyle(context, size: 13),
              decoration: const InputDecoration(labelText: 'Contents', alignLabelWithHint: true),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const Key('save-project-file'),
            onPressed: () => Navigator.pop(context, (_path.text.trim(), _content.text)),
            child: const Text('Save'),
          ),
        ],
      );
}
