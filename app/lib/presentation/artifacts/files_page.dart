import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'artifact_widgets.dart';
import 'artifacts_cubit.dart';
import 'attachments.dart';
import 'pages_view.dart';

enum _Kind { all, images, documents, data, media, attachments, pages }

enum _Size { any, small, medium, large }

enum _Sort { newest, oldest, largest, smallest, name }

const _mb = 1024 * 1024;

/// Everything in the hub's artifact store: what sessions read and made, and
/// what was attached. Filter, sort, search; download to this device and
/// upload from it, with progress.
class FilesPage extends StatefulWidget {
  const FilesPage({super.key, this.onSession, this.session = ''});

  final ValueChanged<String>? onSession;

  /// Show only this session's files; uploads are attached to it.
  final String session;

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  _Kind _kind = _Kind.all;
  _Size _size = _Size.any;
  _Sort _sort = _Sort.newest;
  late String _session = widget.session;
  final _search = TextEditingController();
  int _uploading = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // A page's files show as the page, under Pages.
  bool _matches(Artifact a, String query) =>
      a.origin != 'page' &&
      (_session.isEmpty || a.session == _session) &&
      (query.isEmpty || a.name.toLowerCase().contains(query) || a.note.toLowerCase().contains(query)) &&
      switch (_size) {
        _Size.any => true,
        _Size.small => a.size < _mb,
        _Size.medium => a.size >= _mb && a.size < 100 * _mb,
        _Size.large => a.size >= 100 * _mb,
      } &&
      switch (_kind) {
        _Kind.all => true,
        _Kind.images => a.isImage,
        _Kind.documents => !a.isImage && !a.isMedia && !a.isData,
        _Kind.data => a.isData,
        _Kind.media => a.isMedia,
        _Kind.attachments => a.origin == 'attachment',
        _Kind.pages => false,
      };

  List<Artifact> _sorted(Iterable<Artifact> files) {
    DateTime created(Artifact a) => a.created ?? DateTime(0);
    return files.toList()
      ..sort(switch (_sort) {
        _Sort.newest => (a, b) => created(b).compareTo(created(a)),
        _Sort.oldest => (a, b) => created(a).compareTo(created(b)),
        _Sort.largest => (a, b) => b.size.compareTo(a.size),
        _Sort.smallest => (a, b) => a.size.compareTo(b.size),
        _Sort.name => (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      });
  }

  Future<void> _upload() async {
    if (_session.isNotEmpty) {
      await attachToSession(context, _session);
      return;
    }
    final added = await pickAndUpload(context, onUploading: (n) => mounted ? setState(() => _uploading = n) : null);
    if (mounted && added.isNotEmpty) showToast(context, added.length == 1 ? 'Saved ${added.single.name}' : 'Saved ${added.length} files');
  }

  Future<void> _delete(Artifact a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${a.name}?'),
        content: const Text('Links to it stop working. Sessions that already read it keep their copy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('confirm-delete-file'),
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if ((ok ?? false) && mounted) await context.read<ArtifactsCubit>().delete(a.id);
  }

  Future<void> _copyLink(Artifact a) async {
    final url = await context.read<ArtifactsCubit>().link(a.id);
    if (url == null || !mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) showToast(context, 'Link copied · works for an hour', icon: Icons.link_rounded);
  }

  Widget _menu<T>({required String label, required T value, required List<(T, String)> options, required ValueChanged<T> onSelected, Key? key}) {
    final c = context.colors;
    final current = options.firstWhere((o) => o.$1 == value, orElse: () => options.first).$2;
    return PopupMenuButton<T>(
      key: key,
      tooltip: label,
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) => [for (final (v, text) in options) PopupMenuItem(value: v, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(current, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.muted)),
          ),
          Icon(Icons.expand_more_rounded, size: 16, color: c.faint),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final transfers = context.select<ArtifactsCubit, Map<String, Transfer>>((c) => c.state.transfers);
    final c = context.colors;
    final query = _search.text.trim().toLowerCase();
    final files = _sorted(hub.artifacts.values.where((a) => _matches(a, query)));
    final withFiles = {for (final a in hub.artifacts.values) if (a.session.isNotEmpty && a.origin != 'page') a.session};
    final sessionOptions = <(String, String)>[
      ('', 'Any session'),
      for (final id in withFiles) (id, hub.sessions[id]?.displayTitle ?? 'Session ${id.length > 8 ? id.substring(0, 8) : id}'),
    ];
    final inSession = _session.isEmpty ? null : hub.sessions[_session];
    final shown = [for (final t in transfers.values) if (_session.isEmpty || t.session == _session) t];
    final side = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 16.0;
    return BlocListener<ArtifactsCubit, ArtifactsState>(
      listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
      listener: (context, s) => showFailure(context, s.failure!),
      child: BlocListener<ArtifactsCubit, ArtifactsState>(
        listenWhen: (a, b) => b.transfers.values.any((t) => t.state == TransferState.done && a.transfers[t.id]?.state != TransferState.done),
        listener: (context, s) {
          for (final t in s.transfers.values) {
            if (t.kind == TransferKind.download && t.state == TransferState.done) {
              showToast(context, 'Saved ${t.name} · sha256 checked', icon: Icons.download_done_rounded);
            }
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 12, side, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('file-search'),
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          hintText: 'Search names and notes',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      key: const Key('upload-file'),
                      onPressed: _uploading > 0 ? null : _upload,
                      icon: _uploading > 0
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_session.isEmpty ? Icons.upload_rounded : Icons.attach_file_rounded, size: 18),
                      label: Text(_session.isEmpty ? 'Upload' : 'Attach'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 4, side, 4),
              sliver: SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final k in _Kind.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(switch (k) {
                              _Kind.all => 'All',
                              _Kind.images => 'Images',
                              _Kind.documents => 'Documents',
                              _Kind.data => 'Data',
                              _Kind.media => 'Media',
                              _Kind.attachments => 'Attached',
                              _Kind.pages => 'Pages',
                            }),
                            selected: _kind == k,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() => _kind = k),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_kind != _Kind.pages)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 4, side, 8),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _menu(
                        key: const Key('filter-session'),
                        label: 'Session',
                        value: _session,
                        options: [...sessionOptions, if (_session.isNotEmpty && !withFiles.contains(_session)) (_session, inSession?.displayTitle ?? 'This session')],
                        onSelected: (v) => setState(() => _session = v),
                      ),
                      _menu(
                        key: const Key('filter-size'),
                        label: 'Size',
                        value: _size,
                        options: const [(_Size.any, 'Any size'), (_Size.small, 'Under 1 MB'), (_Size.medium, '1–100 MB'), (_Size.large, 'Over 100 MB')],
                        onSelected: (v) => setState(() => _size = v),
                      ),
                      _menu(
                        key: const Key('sort-files'),
                        label: 'Sort',
                        value: _sort,
                        options: const [
                          (_Sort.newest, 'Newest first'),
                          (_Sort.oldest, 'Oldest first'),
                          (_Sort.largest, 'Largest first'),
                          (_Sort.smallest, 'Smallest first'),
                          (_Sort.name, 'Name'),
                        ],
                        onSelected: (v) => setState(() => _sort = v),
                      ),
                    ],
                  ),
                ),
              ),
            if (shown.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 0, side, 8),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    key: const Key('transfers'),
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final t in shown) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: TransferBar(transfer: t, showName: true)),
                      ],
                    ),
                  ),
                ),
              ),
            if (_kind == _Kind.pages)
              SliverFillRemaining(hasScrollBody: true, child: PagesList(onSession: widget.onSession))
            else if (files.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.folder_open_rounded,
                  title: hub.artifacts.isEmpty ? 'No files yet' : 'No files match',
                  body: hub.artifacts.isEmpty
                      ? 'Images and files your sessions read or make are kept here, along with anything you attach.'
                      : 'Try another filter or search.',
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 0, side, 12),
                sliver: SliverList.separated(
                  itemCount: files.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final a = files[i];
                    return _FileRow(
                      key: ValueKey('file-${a.id}'),
                      artifact: a,
                      from: hub.sessions[a.session],
                      transfer: transfers[a.id],
                      onDelete: () => _delete(a),
                      onCopyLink: () => _copyLink(a),
                      onSession: widget.onSession,
                    );
                  },
                ),
              ),
            if (files.isNotEmpty && _kind != _Kind.pages)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text('${files.length} ${files.length == 1 ? 'file' : 'files'} · ${fileSize(files.fold(0, (n, a) => n + a.size))}',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.faint)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    super.key,
    required this.artifact,
    required this.from,
    required this.transfer,
    required this.onDelete,
    required this.onCopyLink,
    this.onSession,
  });

  final Artifact artifact;
  final Session? from;
  final Transfer? transfer;
  final VoidCallback onDelete, onCopyLink;
  final ValueChanged<String>? onSession;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = artifact;
    final t = transfer;
    final busy = t?.active ?? false;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openArtifact(context, a),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: a.isImage && a.previewable
                        ? IgnorePointer(child: ArtifactImage(artifact: a, height: 44))
                        : Container(
                            decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(8)),
                            child: Icon(artifactIcon(a), size: 22, color: c.faint),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: fileSize(a.size), style: TextStyle(fontWeight: FontWeight.w600, color: c.muted)),
                            TextSpan(text: ' · ${[if (from != null) from!.displayTitle, if (a.origin.isNotEmpty) a.origin, ago(a.created)].join(' · ')}'),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: c.faint),
                        ),
                        if (a.note.isNotEmpty)
                          Text(a.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    key: Key('download-${a.id}'),
                    tooltip: 'Download to this device',
                    iconSize: 20,
                    icon: Icon(t?.state == TransferState.done ? Icons.download_done_rounded : Icons.download_rounded, color: c.muted),
                    onPressed: busy ? null : () => context.read<ArtifactsCubit>().download(a),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    iconSize: 18,
                    icon: Icon(Icons.more_vert_rounded, size: 18, color: c.faint),
                    onSelected: (v) => switch (v) {
                      'session' => onSession?.call(a.session),
                      'link' => onCopyLink(),
                      _ => onDelete(),
                    },
                    itemBuilder: (_) => [
                      if (from != null && onSession != null)
                        PopupMenuItem(value: 'session', child: Text('Open ${from!.displayTitle}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const PopupMenuItem(value: 'link', child: Text('Copy link')),
                      PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: c.danger))),
                    ],
                  ),
                ],
              ),
              if (t != null) Padding(padding: const EdgeInsets.only(top: 6, left: 54), child: TransferBar(transfer: t)),
            ],
          ),
        ),
      ),
    );
  }
}
