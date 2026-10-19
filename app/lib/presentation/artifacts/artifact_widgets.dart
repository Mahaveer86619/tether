import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'artifacts_cubit.dart';

String fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// "120.4 MB of 1.20 GB · 3.1 MB/s", or what the transfer is doing.
String transferLabel(Transfer t) => switch (t.state) {
      TransferState.queued => t.bytes > 0 ? 'Waiting to resume · ${fileSize(t.bytes)} of ${fileSize(t.total)}' : 'Waiting',
      TransferState.preparing => 'Checking the file…',
      TransferState.running => [
          '${fileSize(t.bytes)} of ${fileSize(t.total)}',
          if (t.speed > 0) '${fileSize(t.speed.round())}/s',
        ].join(' · '),
      TransferState.paused => 'Paused · ${fileSize(t.bytes)} of ${fileSize(t.total)}',
      TransferState.verifying => 'Checking sha256…',
      TransferState.done => t.kind == TransferKind.download ? 'Saved to ${t.savedTo}' : 'Uploaded · ${fileSize(t.total)}',
      TransferState.failed => t.error.isEmpty ? 'Failed' : t.error,
      TransferState.canceled => 'Canceled',
    };

/// A transfer's progress with its controls: pause and resume (downloads),
/// cancel, and dismiss once it's over.
class TransferBar extends StatelessWidget {
  const TransferBar({super.key, required this.transfer, this.showName = false});

  final Transfer transfer;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = transfer;
    final cubit = context.read<ArtifactsCubit>();
    final download = t.kind == TransferKind.download;
    Widget button(String tip, IconData icon, VoidCallback onPressed, String key) => IconButton(
          key: Key('$key-${t.id}'),
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          icon: Icon(icon, color: c.muted),
          onPressed: onPressed,
        );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showName)
                Row(children: [
                  Icon(download ? Icons.download_rounded : Icons.upload_rounded, size: 14, color: c.faint),
                  const SizedBox(width: 4),
                  Expanded(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                ]),
              if (!t.finished) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: t.state == TransferState.preparing || t.state == TransferState.verifying ? null : t.progress,
                    backgroundColor: c.raised,
                  ),
                ),
              ],
              const SizedBox(height: 3),
              Text(
                transferLabel(t),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: t.state == TransferState.failed ? c.danger : c.faint),
              ),
            ],
          ),
        ),
        if (download && t.state == TransferState.running) button('Pause', Icons.pause_rounded, () => cubit.pause(t.id), 'pause'),
        if (download && t.state == TransferState.paused) button('Resume', Icons.play_arrow_rounded, () => cubit.resume(t.id), 'resume'),
        if (!t.finished && t.state != TransferState.verifying) button('Cancel', Icons.close_rounded, () => cubit.cancel(t.id), 'cancel'),
        if (t.finished) button('Dismiss', Icons.close_rounded, () => cubit.dismiss(t.id), 'dismiss'),
      ],
    );
  }
}

IconData artifactIcon(Artifact a) {
  if (a.isImage) return Icons.image_outlined;
  if (a.mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (a.mime.startsWith('audio/')) return Icons.audiotrack_rounded;
  if (a.mime.startsWith('video/')) return Icons.movie_outlined;
  if (a.isText) return Icons.description_outlined;
  return Icons.insert_drive_file_outlined;
}

/// Files linked to a tool call or message: images as thumbnails, the rest
/// as small tiles.
class ArtifactStrip extends StatelessWidget {
  const ArtifactStrip({super.key, required this.artifacts, this.alignEnd = false});

  final List<Artifact> artifacts;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final a in artifacts)
            a.isImage && a.previewable ? ArtifactImage(artifact: a, height: 140) : ArtifactTile(artifact: a),
        ],
      );
}

/// An image from the store, fetched through the app's own client (so it
/// works with a pinned hub certificate). Tap to open.
class ArtifactImage extends StatelessWidget {
  const ArtifactImage({super.key, required this.artifact, this.height = 140, this.fit = BoxFit.cover});

  final Artifact artifact;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => openArtifact(context, artifact),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: height.isFinite ? height : null,
          // An infinite height fills whatever space it's given.
          constraints: height.isFinite ? BoxConstraints(minWidth: height * 0.8, maxWidth: height * 2.2) : null,
          color: c.raised,
          child: FutureBuilder<Uint8List?>(
            future: context.read<ArtifactsCubit>().bytes(artifact.id),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final data = snap.data;
              if (data == null) return Center(child: Icon(Icons.broken_image_outlined, color: c.faint));
              return Image.memory(data,
                  height: height.isFinite ? height : null,
                  width: height.isFinite ? null : double.infinity,
                  fit: fit,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => Center(child: Icon(Icons.broken_image_outlined, color: c.faint)));
            },
          ),
        ),
      ),
    );
  }
}

class ArtifactTile extends StatelessWidget {
  const ArtifactTile({super.key, required this.artifact});

  final Artifact artifact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.raised,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => openArtifact(context, artifact),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(artifactIcon(artifact), size: 18, color: c.muted),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(artifact.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    Text(fileSize(artifact.size), style: TextStyle(fontSize: 11.5, color: c.faint)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens an artifact full screen: images zoomable, text readable, anything
/// else with a link to open it elsewhere.
Future<void> openArtifact(BuildContext context, Artifact a) {
  final cubit = context.read<ArtifactsCubit>();
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => BlocProvider.value(value: cubit, child: _ArtifactViewer(artifact: a)),
  ));
}

class _ArtifactViewer extends StatelessWidget {
  const _ArtifactViewer({required this.artifact});

  final Artifact artifact;

  Future<void> _share(BuildContext context, {required bool open}) async {
    final url = await context.read<ArtifactsCubit>().link(artifact.id);
    if (url == null || !context.mounted) return;
    if (open) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) showToast(context, 'Link copied · works for an hour', icon: Icons.link_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = artifact;
    final transfer = context.select<ArtifactsCubit, Transfer?>((x) => x.state.transfers[a.id]);
    return Scaffold(
      appBar: AppBar(
        title: Text(a.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const Key('download-artifact'),
            tooltip: 'Download to this device',
            icon: const Icon(Icons.download_rounded),
            onPressed: transfer?.active ?? false ? null : () => context.read<ArtifactsCubit>().download(a),
          ),
          IconButton(tooltip: 'Copy link', icon: const Icon(Icons.link_rounded), onPressed: () => _share(context, open: false)),
          IconButton(tooltip: 'Open in browser', icon: const Icon(Icons.open_in_new_rounded), onPressed: () => _share(context, open: true)),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              [a.mime, fileSize(a.size), if (a.node.isNotEmpty) a.node, if (a.origin.isNotEmpty) a.origin, ago(a.created)].join(' · '),
              style: TextStyle(fontSize: 12, color: c.faint),
            ),
          ),
          if (a.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(a.note, style: TextStyle(fontSize: 13, color: c.muted)),
            ),
          if (transfer != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 8, 8), child: TransferBar(transfer: transfer)),
          Expanded(
            child: (a.isImage || a.isText) && a.previewable
                ? FutureBuilder<Uint8List?>(
                    future: context.read<ArtifactsCubit>().bytes(a.id),
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      final data = snap.data;
                      if (data == null) return const EmptyState(icon: Icons.broken_image_outlined, title: "Couldn't load the file");
                      if (a.isImage) return InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(data)));
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(utf8.decode(data, allowMalformed: true), style: monoStyle(context, size: 13)),
                      );
                    },
                  )
                : EmptyState(
                    icon: artifactIcon(a),
                    title: a.name,
                    body: a.previewable ? 'Download it, or open it in your browser.' : '${fileSize(a.size)} is too big to show here. Download it to this device.',
                    action: FilledButton.icon(
                      key: const Key('download-artifact-big'),
                      onPressed: transfer?.active ?? false ? null : () => context.read<ArtifactsCubit>().download(a),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Files in the store linked to a tool call or message. Rebuilds only when
/// that set changes; empty where there is no hub (e.g. widget previews).
List<Artifact> linkedArtifacts(BuildContext context, String ref) {
  if (ref.isEmpty) return const [];
  try {
    final key = context.select<HubCubit, String>((h) => h.state.hub.artifactsFor(ref).map((a) => a.id).join(','));
    if (key.isEmpty) return const [];
    return context.read<HubCubit>().state.hub.artifactsFor(ref);
  } on ProviderNotFoundException {
    return const [];
  }
}
