import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'new_session_cubit.dart';

const _models = {'': 'Default', 'opus': 'Opus', 'sonnet': 'Sonnet', 'haiku': 'Haiku'};
const _modes = {'': 'Default', 'acceptEdits': 'Accept edits', 'plan': 'Plan', 'auto': 'Auto'};

/// Shows the new-session form; returns the created session's id.
Future<String?> showNewSession(BuildContext context, {String? node}) {
  final form = BlocProvider(
    create: (_) => sl<NewSessionCubit>(param1: context.read<HubCubit>().state.hub, param2: node),
    child: const NewSessionForm(),
  );
  if (isDesktop) {
    return showDialog<String>(
      context: context,
      builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: form)),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom), child: form),
  );
}

class NewSessionForm extends StatefulWidget {
  const NewSessionForm({super.key});

  @override
  State<NewSessionForm> createState() => _NewSessionFormState();
}

class _NewSessionFormState extends State<NewSessionForm> {
  final _prompt = TextEditingController();

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<NewSessionCubit>();
    return BlocConsumer<NewSessionCubit, NewSessionState>(
      listenWhen: (a, b) => a.failureId != b.failureId || a.createdId != b.createdId,
      listener: (context, s) {
        if (s.createdId != null) {
          Navigator.of(context).pop(s.createdId);
        } else if (s.failure != null) {
          showFailure(context, s.failure!);
        }
      },
      builder: (context, s) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('New session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Starts Claude Code on the device you pick. On Linux it runs in tmux so you can attach to it later.',
                style: TextStyle(color: c.muted, fontSize: 13)),
            const SizedBox(height: 18),
            if (s.nodes.isEmpty)
              Text('No devices are online.', style: TextStyle(color: c.danger))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in s.nodes)
                    ChoiceChip(
                      label: Text(n.name),
                      avatar: Icon(osIcon(n.os), size: 16),
                      selected: s.node == n.name,
                      onSelected: (_) => cubit.selectNode(n.name),
                    ),
                ],
              ),
            const SizedBox(height: 14),
            _label(context, 'Folder on ${s.node ?? 'the device'}'),
            Autocomplete<String>(
              key: ValueKey('cwd-${s.node}'),
              initialValue: TextEditingValue(text: s.cwd),
              optionsBuilder: (v) => s.folders.where((d) => d.toLowerCase().contains(v.text.toLowerCase())).take(8),
              onSelected: cubit.setCwd,
              fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                controller: controller,
                focusNode: focus,
                onChanged: cubit.setCwd,
                style: monoStyle(context, size: 13),
                decoration: const InputDecoration(hintText: 'Home folder if empty'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _dropdown(context, 'Model', _models, s.model, cubit.setModel)),
                const SizedBox(width: 12),
                Expanded(child: _dropdown(context, 'Permissions', _modes, s.permissionMode, cubit.setPermissionMode)),
              ],
            ),
            const SizedBox(height: 14),
            _label(context, 'Prompt'),
            TextField(
              key: const Key('new-session-prompt'),
              controller: _prompt,
              minLines: 3,
              maxLines: 8,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'What should Claude do?'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: s.submitting ? null : () => cubit.submit(_prompt.text),
                  child: s.submitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Start session'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.colors.muted)),
      );

  Widget _dropdown(BuildContext context, String label, Map<String, String> options, String value, ValueChanged<String> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(context, label),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => onChanged(v ?? ''),
          ),
        ],
      );
}
