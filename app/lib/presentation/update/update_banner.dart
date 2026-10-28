import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/version.dart';
import '../theme/theme.dart';
import '../artifacts/artifact_widgets.dart';
import 'update_cubit.dart';

/// Says a newer release is out, with its notes, Update and Skip; then its
/// download progress, and Install (Android) or Restart to update (Windows).
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<UpdateCubit>().state;
    final r = s.release;
    if (!s.visible || r == null || s.forced) return const SizedBox.shrink();
    final c = context.colors;
    final cubit = context.read<UpdateCubit>();
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final (text, actions) = _content(context, s, cubit);
    return Material(
      key: const Key('update-banner'),
      color: c.accent.withValues(alpha: 0.10),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
        padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(s.stage == UpdateStage.failed ? Icons.error_outline_rounded : Icons.system_update_alt_rounded, size: 18, color: s.stage == UpdateStage.failed ? c.danger : c.accent),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
                if (!narrow) ...actions,
              ],
            ),
            if (narrow) Wrap(alignment: WrapAlignment.end, children: actions),
            if (s.stage == UpdateStage.downloading)
              Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: s.progress, minHeight: 3)),
          ],
        ),
      ),
    );
  }

  (String, List<Widget>) _content(BuildContext context, UpdateState s, UpdateCubit cubit) {
    final r = s.release!;
    final notes = TextButton(key: const Key('update-notes'), onPressed: () => showReleaseNotes(context, r.version, r.notes), child: const Text("What's new"));
    return switch (s.stage) {
      UpdateStage.available => (
          'Tether ${r.version} is available (you have $appVersion).',
          [
            notes,
            TextButton(key: const Key('update-skip'), onPressed: cubit.skip, child: const Text('Skip this version')),
            FilledButton(key: const Key('update-now'), onPressed: cubit.update, child: const Text('Update')),
          ],
        ),
      UpdateStage.downloading => ('Downloading Tether ${r.version}… ${s.total > 0 ? '${fileSize(s.received)} of ${fileSize(s.total)}' : fileSize(s.received)}', const []),
      UpdateStage.ready || UpdateStage.installing => (
          s.stage == UpdateStage.installing ? 'Installing Tether ${r.version}…' : 'Tether ${r.version} is downloaded and checked.',
          [
            notes,
            FilledButton(
              key: const Key('update-install'),
              onPressed: s.stage == UpdateStage.installing ? null : cubit.install,
              child: Text(Theme.of(context).platform == TargetPlatform.android ? 'Install' : 'Restart to update'),
            ),
          ],
        ),
      UpdateStage.failed => (
          'The update to ${r.version} failed: ${s.failure?.userMessage ?? 'unknown error'}',
          [
            TextButton(onPressed: cubit.later, child: const Text('Later')),
            FilledButton(key: const Key('update-retry'), onPressed: cubit.update, child: const Text('Try again')),
          ],
        ),
      UpdateStage.none => ('', const []),
    };
  }
}

/// The release's notes, as plain text.
Future<void> showReleaseNotes(BuildContext context, String version, String notes) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("What's new in $version"),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(child: SelectableText(notes.isEmpty ? 'No notes for this release.' : notes.replaceAll('**', ''))),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );

/// Shown instead of the app when this version is older than the release's
/// minimum: the hub may no longer understand it.
class ForcedUpdatePage extends StatelessWidget {
  const ForcedUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<UpdateCubit>().state;
    final cubit = context.read<UpdateCubit>();
    final c = context.colors;
    final r = s.release!;
    final busy = s.stage == UpdateStage.downloading || s.stage == UpdateStage.installing;
    final ready = s.stage == UpdateStage.ready;
    return Scaffold(
      key: const Key('forced-update'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.system_update_alt_rounded, size: 40, color: c.accent),
                const SizedBox(height: 16),
                Text('Update Tether to carry on', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'This app is $appVersion; the hub needs ${r.minSupported} or newer. Tether ${r.version} is ready to install.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted),
                ),
                const SizedBox(height: 20),
                if (r.notes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(10)),
                    child: SelectableText(r.notes.replaceAll('**', ''), style: const TextStyle(fontSize: 13.5)),
                  ),
                const SizedBox(height: 20),
                if (s.stage == UpdateStage.downloading) ...[
                  LinearProgressIndicator(value: s.progress),
                  const SizedBox(height: 12),
                ],
                if (s.stage == UpdateStage.failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(s.failure?.userMessage ?? 'The update failed.', textAlign: TextAlign.center, style: TextStyle(color: c.danger)),
                  ),
                FilledButton.icon(
                  key: const Key('forced-update-now'),
                  onPressed: busy ? null : (ready ? cubit.install : cubit.update),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(ready ? (Theme.of(context).platform == TargetPlatform.android ? 'Install' : 'Restart to update') : 'Update now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
