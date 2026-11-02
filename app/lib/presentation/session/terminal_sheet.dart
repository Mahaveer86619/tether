import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../injection.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'terminal_cubit.dart';

/// Opens a session's terminal: what Claude Code shows on its machine, and
/// keys to press there. Nothing it shows can leave a session stuck.
Future<void> showTerminalSheet(BuildContext context, String sessionId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) => sl<TerminalCubit>(param1: sessionId)..refresh(),
        child: const _TerminalSheet(),
      ),
    );

class _TerminalSheet extends StatefulWidget {
  const _TerminalSheet();

  @override
  State<_TerminalSheet> createState() => _TerminalSheetState();
}

class _TerminalSheetState extends State<_TerminalSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  static const _keys = [
    ('Escape', 'Esc'),
    ('Enter', 'Enter'),
    ('Up', '↑'),
    ('Down', '↓'),
    ('Left', '←'),
    ('Right', '→'),
    ('Tab', 'Tab'),
    ('BTab', 'Shift+Tab'),
    ('Space', 'Space'),
    ('Backspace', '⌫'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<TerminalCubit>();
    return BlocConsumer<TerminalCubit, TerminalState>(
      listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
      listener: (context, s) => showFailure(context, s.failure!),
      builder: (context, s) {
        final screen = s.screen;
        final busy = s.sending || s.loading;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Expanded(child: Text('Terminal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                if (screen?.captured case final at?) Text('read ${ago(at)}', style: TextStyle(fontSize: 12, color: c.faint)),
                IconButton(key: const Key('terminal-refresh'), tooltip: 'Read the screen again', onPressed: busy ? null : cubit.refresh, icon: const Icon(Icons.refresh_rounded)),
              ]),
              Container(
                key: const Key('terminal-screen'),
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
                decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
                padding: const EdgeInsets.all(10),
                child: s.loading && screen == null
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
                    : SingleChildScrollView(
                        reverse: true,
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SelectableText(
                            screen == null ? '' : (screen.error.isNotEmpty ? screen.error : screen.text),
                            style: monoStyle(context, size: 11.5, color: screen?.error.isNotEmpty ?? false ? c.danger : null),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (key, label) in _keys)
                    ActionChip(
                      key: Key('key-$key'),
                      label: Text(label, style: const TextStyle(fontSize: 12.5)),
                      visualDensity: VisualDensity.compact,
                      onPressed: busy ? null : () => cubit.press([key]),
                    ),
                  for (final n in ['1', '2', '3', '4', '5', '0'])
                    ActionChip(
                      key: Key('key-$n'),
                      label: Text(n, style: const TextStyle(fontSize: 12.5)),
                      visualDensity: VisualDensity.compact,
                      onPressed: busy ? null : () => cubit.press([n]),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    key: const Key('terminal-text'),
                    controller: _text,
                    decoration: const InputDecoration(isDense: true, hintText: 'Type into the terminal'),
                    onSubmitted: (_) => _type(cubit, enter: true),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(key: const Key('terminal-type'), onPressed: busy ? null : () => _type(cubit, enter: false), child: const Text('Type')),
                const SizedBox(width: 6),
                FilledButton(key: const Key('terminal-type-enter'), onPressed: busy ? null : () => _type(cubit, enter: true), child: const Text('Type + Enter')),
              ]),
            ],
          ),
        );
      },
    );
  }

  Future<void> _type(TerminalCubit cubit, {required bool enter}) async {
    final text = _text.text;
    if (text.isEmpty && !enter) return;
    // Text first, then Enter: keys in one request go before its text.
    if (text.isNotEmpty) await cubit.press(const [], text: text);
    if (enter) await cubit.press(const ['Enter']);
    _text.clear();
  }
}
