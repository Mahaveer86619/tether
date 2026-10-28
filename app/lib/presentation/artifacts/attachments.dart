import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/upload_id.dart';
import '../../domain/entities/entities.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import 'artifact_widgets.dart';
import 'artifacts_cubit.dart';

/// Lets the user pick files and uploads each from disk, so size doesn't
/// matter. With a [session] they're attached to it; [forMessage] holds them
/// for the message being written instead of putting them in the session's
/// folder now. [onUploading] reports how many are still on their way.
Future<List<Artifact>> pickAndUpload(
  BuildContext context, {
  String session = '',
  String note = '',
  bool forMessage = false,
  ValueChanged<int>? onUploading,
}) async {
  final cubit = context.read<ArtifactsCubit>();
  final picked = await FilePicker.pickFiles();
  if (picked.isEmpty) return const [];
  final files = <LocalFile>[];
  for (final f in picked) {
    final path = f.path;
    final size = await f.length();
    if (path == null || size == null) {
      if (context.mounted) showToast(context, "Couldn't read ${f.name}", icon: Icons.error_outline_rounded);
      continue;
    }
    files.add(LocalFile(path: path, name: f.name, size: size));
  }
  var left = files.length;
  onUploading?.call(left);
  final out = <Artifact>[];
  for (final f in files) {
    final a = await cubit.upload(f, session: session, note: note, forMessage: forMessage);
    if (a != null) out.add(a);
    onUploading?.call(--left);
  }
  // Android hands over a copy in the app's cache; a GB file shouldn't linger.
  if (Platform.isAndroid && !cubit.state.uploads.any((t) => t.active)) await FilePicker.clearTemporaryFiles();
  return out;
}

/// Lets the user pick files without sending them anywhere yet: each keeps
/// its path on this device and gets the id its upload will use, so the
/// message can go now and the file follow in the background.
Future<List<LocalFile>> pickLocalFiles(BuildContext context) async {
  final picked = await FilePicker.pickFiles();
  final files = <LocalFile>[];
  for (final f in picked) {
    final path = f.path;
    final size = await f.length();
    if (path == null || size == null) {
      if (context.mounted) showToast(context, "Couldn't read ${f.name}", icon: Icons.error_outline_rounded);
      continue;
    }
    files.add(LocalFile(path: path, name: f.name, size: size, uploadId: newUploadId()));
  }
  return files;
}

/// Asks for a note to go with files attached to a session; null if the
/// user backs out.
Future<String?> askAttachNote(BuildContext context) {
  final note = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Attach files to this session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("They go into the session's folder, under .tether/attachments, for Claude to read."),
          const SizedBox(height: 12),
          TextField(
            key: const Key('attach-note'),
            controller: note,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'What these files are for'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(key: const Key('attach-pick'), onPressed: () => Navigator.pop(ctx, note.text), child: const Text('Choose files')),
      ],
    ),
  );
}

/// Picks files and attaches them to [session], with a note.
Future<void> attachToSession(BuildContext context, String session) async {
  final note = await askAttachNote(context);
  if (note == null || !context.mounted) return;
  final added = await pickAndUpload(context, session: session, note: note);
  if (context.mounted && added.isNotEmpty) {
    showToast(context, added.length == 1 ? 'Attached ${added.single.name}' : 'Attached ${added.length} files', icon: Icons.attach_file_rounded);
  }
}

/// Files chosen for a message that haven't gone up yet, each removable.
class PendingFileChips extends StatelessWidget {
  const PendingFileChips({super.key, required this.files, required this.onRemove});

  final List<LocalFile> files;
  final ValueChanged<LocalFile> onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4, right: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in files)
              InputChip(
                key: ValueKey('pending-${f.uploadId}'),
                avatar: const Icon(Icons.attach_file_rounded, size: 16),
                label: Text('${f.name} · ${fileSize(f.size)}', style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                onDeleted: () => onRemove(f),
              ),
          ],
        ),
      );
}

/// Files waiting to go with a message, each removable.
class AttachmentChips extends StatelessWidget {
  const AttachmentChips({super.key, required this.files, required this.onRemove, this.uploading = 0});

  final List<Artifact> files;
  final ValueChanged<Artifact> onRemove;
  final int uploading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = uploading > 0 ? context.select<ArtifactsCubit, List<Transfer>>((a) => [for (final t in a.state.uploads) if (t.active) t]) : const <Transfer>[];
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4, right: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final f in files)
            InputChip(
              key: ValueKey('attachment-${f.id}'),
              avatar: Icon(artifactIcon(f), size: 16),
              label: Text('${f.name} · ${fileSize(f.size)}', style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              onPressed: () => openArtifact(context, f),
              onDeleted: () => onRemove(f),
            ),
          for (final t in active)
            Chip(
              key: ValueKey('uploading-${t.id}'),
              avatar: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, value: t.progress)),
              label: Text('${t.name} · ${transferLabel(t)}', style: TextStyle(fontSize: 12, color: c.muted)),
              visualDensity: VisualDensity.compact,
            ),
          if (uploading > 0 && active.isEmpty)
            Chip(
              avatar: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              label: Text(uploading == 1 ? 'Uploading…' : 'Uploading $uploading…', style: TextStyle(fontSize: 12, color: c.muted)),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
