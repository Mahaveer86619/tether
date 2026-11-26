import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/prompt_desk.dart';
import '../../injection.dart';
import '../theme/theme.dart';
import '../ui/motion.dart';
import '../ui/refresh.dart';
import '../widgets/common.dart';
import 'rules_cubit.dart';

/// Standing rules: instructions every session they cover is given, kept on
/// the hub. See docs/plans/prompt-desk.md#rules.
class RulesPage extends StatelessWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<RulesCubit>()..load(),
        child: const RulesView(),
      );
}

class RulesView extends StatelessWidget {
  const RulesView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return BlocListener<RulesCubit, RulesState>(
      listenWhen: (a, b) => a.addedId != b.addedId,
      listener: (context, s) {
        final r = s.rules.where((r) => r.name == s.added).lastOrNull;
        showToast(context, r == null || r.on ? 'Added "${s.added}".' : 'Added "${s.added}", switched off. Switch it on when it reads right.');
      },
      child: BlocConsumer<RulesCubit, RulesState>(
      listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
      listener: (context, s) => showFailure(context, s.failure!),
      builder: (context, s) {
        final cubit = context.read<RulesCubit>();
        final side = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 16.0;
        final suggestions = s.suggestions;
        return PullRefresh(
          onRefresh: cubit.load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(side, 8, side, bottomRoom(context)),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Text(
                                'Instructions Claude is given in every session they cover, so you stop repeating them. A device or project rule wins over an everywhere one.',
                                style: TextStyle(fontSize: 13, color: c.muted),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            key: const Key('add-rule'),
                            onPressed: () => editRule(context),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add rule'),
                          ),
                        ],
                      ),
                      if (suggestions.isNotEmpty) ...[
                        const SectionLabel('Suggested'),
                        Text('From the instructions repeated most in chats. A tap adds one switched off.', style: TextStyle(fontSize: 12, color: c.faint)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final sug in suggestions)
                              Tooltip(
                                message: sug.text,
                                child: ActionChip(
                                  key: Key('suggest-${sug.name}'),
                                  avatar: Icon(Icons.add_rounded, size: 16, color: c.accent),
                                  label: Text(sug.name),
                                  onPressed: s.busy.contains(sug.text) ? null : () => cubit.addSuggested(sug),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      SectionLabel('Rules', trailing: s.rules.isEmpty ? null : Pill('${s.rules.where((r) => r.on).length} on', color: c.accent)),
                      if (s.loading && s.rules.isEmpty)
                        const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))
                      else if (s.rules.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: EmptyState(
                            icon: Icons.rule_rounded,
                            title: 'No rules yet',
                            body: 'Add one, or start from a suggestion above.',
                          ),
                        )
                      else
                        for (final r in s.rules) _RuleCard(rule: r, busy: s.busy.contains(r.id)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.busy});

  final Rule rule;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<RulesCubit>();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(side: BorderSide(color: rule.on ? c.accent.withValues(alpha: 0.5) : c.border), borderRadius: context.round(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('rule-${rule.id}'),
          onTap: () => editRule(context, rule: rule),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(rule.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    if (busy) const Padding(padding: EdgeInsets.only(right: 8), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
                    IconButton(
                      key: Key('rule-delete-${rule.id}'),
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.faint),
                      onPressed: busy ? null : () => _confirmDelete(context, cubit),
                    ),
                    Switch(key: Key('rule-on-${rule.id}'), value: rule.on, onChanged: busy ? null : (v) => cubit.setOn(rule, v)),
                  ],
                ),
                if (rule.text != rule.name)
                  Padding(padding: const EdgeInsets.only(top: 2, right: 8), child: Text(rule.text, style: TextStyle(fontSize: 13, color: c.muted))),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  Pill(rule.where),
                  Pill(rule.on ? 'On' : 'Off', color: rule.on ? c.success : null),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, RulesCubit cubit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this rule?'),
        content: Text(rule.text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(key: const Key('rule-delete-confirm'), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await cubit.delete(rule);
  }
}

/// Opens the editor for a new rule, or for [rule].
Future<void> editRule(BuildContext context, {Rule? rule}) {
  final cubit = context.read<RulesCubit>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(value: cubit, child: _RuleEditor(rule: rule)),
  );
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({this.rule});

  final Rule? rule;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final _name = TextEditingController(text: widget.rule?.name ?? '');
  late final _text = TextEditingController(text: widget.rule?.text ?? '');
  late final _cwd = TextEditingController(text: widget.rule?.cwd ?? '');
  late RuleScope _scope = widget.rule?.scope ?? RuleScope.everywhere;
  late String _node = widget.rule?.node ?? '';
  late bool _on = widget.rule?.on ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    _cwd.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final base = widget.rule ?? const Rule(text: '');
    final ok = await context.read<RulesCubit>().save(base.copyWith(name: _name.text, text: _text.text, scope: _scope, node: _node, cwd: _cwd.text, on: _on));
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<RulesCubit>().state;
    final devices = {...s.devices, if (_node.isNotEmpty) _node}.toList();
    final folders = s.folders[_node] ?? const <String>[];
    return AlertDialog(
      key: const Key('rule-editor'),
      title: Text(widget.rule == null ? 'New rule' : 'Edit rule'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('rule-text'),
                controller: _text,
                autofocus: widget.rule == null,
                minLines: 2,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Rule', hintText: 'Never write comments in code.'),
              ),
              TextField(
                key: const Key('rule-name'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'Shown in the list'),
              ),
              const SizedBox(height: 16),
              Text('Applies to', style: TextStyle(fontSize: 12, color: c.muted)),
              const SizedBox(height: 6),
              SegmentedButton<RuleScope>(
                key: const Key('rule-scope'),
                segments: const [
                  ButtonSegment(value: RuleScope.everywhere, label: Text('Everywhere'), icon: Icon(Icons.public_rounded)),
                  ButtonSegment(value: RuleScope.device, label: Text('A device'), icon: Icon(Icons.computer_rounded)),
                  ButtonSegment(value: RuleScope.project, label: Text('A project'), icon: Icon(Icons.folder_outlined)),
                ],
                selected: {_scope},
                onSelectionChanged: (v) => setState(() => _scope = v.first),
              ),
              if (_scope != RuleScope.everywhere) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('rule-device'),
                  initialValue: _node.isEmpty ? null : _node,
                  decoration: const InputDecoration(labelText: 'Device'),
                  items: [for (final d in devices) DropdownMenuItem(value: d, child: Text(d))],
                  onChanged: (v) => setState(() {
                    _node = v ?? '';
                    _cwd.clear();
                  }),
                ),
              ],
              if (_scope == RuleScope.project) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('rule-folder'),
                  controller: _cwd,
                  style: monoStyle(context, size: 13),
                  decoration: const InputDecoration(labelText: 'Project folder', hintText: 'Pick one below or type its path'),
                ),
                if (folders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final f in folders)
                          ChoiceChip(
                            key: Key('rule-folder-$f'),
                            label: Text(f, style: monoStyle(context, size: 12)),
                            selected: _cwd.text == f,
                            onSelected: (_) => setState(() => _cwd.text = f),
                          ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('rule-editor-on'),
                contentPadding: EdgeInsets.zero,
                title: const Text('On'),
                subtitle: const Text('Sessions started from now on get it'),
                value: _on,
                onChanged: (v) => setState(() => _on = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('rule-save'), onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
