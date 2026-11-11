import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../ui/tokens.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'artifact_widgets.dart';
import 'artifacts_cubit.dart';

/// Programs a person should know are programs before they open one.
bool isProgram(Artifact a) {
  final n = a.name.toLowerCase();
  return n.endsWith('.apk') || n.endsWith('.exe') || n.endsWith('.msi') || n.endsWith('.dmg') || n.endsWith('.sh') || n.endsWith('.bat') || n.endsWith('.ps1');
}

/// What a session made for you: the file, where it came from, and what you
/// can do with it. A program says so and never opens by itself.
class FileCard extends StatelessWidget {
  const FileCard({super.key, required this.artifact});

  final Artifact artifact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = artifact;
    final transfer = context.select<ArtifactsCubit, Transfer?>((x) => x.state.transfers[a.id]);
    final busy = transfer != null && !transfer.finished;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: context.round(10)),
      child: InkWell(
        key: Key('file-card-${a.id}'),
        borderRadius: context.round(10),
        onTap: () => openArtifact(context, a),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: c.raised, borderRadius: context.round(8)),
                    child: Icon(artifactIcon(a), size: 18, color: c.accent),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Type.title(context).copyWith(fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          [fileSize(a.size), if (a.node.isNotEmpty) a.node, ago(a.created)].join('  ·  '),
                          style: Type.meta(context, color: c.faint, size: 11.5),
                        ),
                      ],
                    ),
                  ),
                  if (isProgram(a)) Padding(padding: const EdgeInsets.only(right: Gap.sm), child: Pill('a program', color: c.warning)),
                  IconButton(
                    key: Key('file-card-download-${a.id}'),
                    tooltip: 'Download',
                    onPressed: busy ? null : () => context.read<ArtifactsCubit>().download(a),
                    icon: const Icon(Icons.download_rounded, size: 20),
                  ),
                ],
              ),
              if (a.note.isNotEmpty) ...[
                const SizedBox(height: Gap.sm),
                Text(a.note, style: TextStyle(fontSize: 13, color: c.muted)),
              ],
              if (transfer != null) ...[
                const SizedBox(height: Gap.sm),
                TransferBar(transfer: transfer),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The files a session handed over, newest first, above the composer.
class DeliveredFiles extends StatelessWidget {
  const DeliveredFiles({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final files = context.select<HubCubit, List<Artifact>>((h) => [
          for (final a in h.state.hub.sortedArtifacts)
            if (a.session == sessionId && a.origin == 'result') a,
        ]);
    if (files.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 14, color: c.accent),
                const SizedBox(width: Gap.sm),
                Text('DELIVERED', style: Type.label(context, color: c.accent)),
                const Spacer(),
                Text('${files.length}', style: Type.meta(context, color: c.accent)),
              ],
            ),
          ),
          for (final a in files.take(3))
            Padding(padding: const EdgeInsets.only(bottom: Gap.xs), child: FileCard(artifact: a)),
          if (files.length > 3) Text('and ${files.length - 3} more under Files', style: Type.meta(context, color: c.faint, size: 11.5)),
        ],
      ),
    );
  }
}
