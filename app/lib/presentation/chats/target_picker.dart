import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

class TargetPickerState extends Equatable {
  const TargetPickerState({this.suggestions = const TargetSuggestions(), this.loading = true, this.node = '', this.failure});

  final TargetSuggestions suggestions;
  final bool loading;

  /// The device whose folders are listed.
  final String node;
  final Failure? failure;

  @override
  List<Object?> get props => [suggestions, loading, node, failure];
}

/// View model for the target picker: the hub's ranked folders, per device.
class TargetPickerCubit extends Cubit<TargetPickerState> {
  TargetPickerCubit({required this._chats, required String prompt, required String node}) : super(TargetPickerState(node: node)) {
    _load(prompt);
  }

  final Chats _chats;

  Future<void> _load(String prompt) async {
    if (!_chats.supported) {
      emit(TargetPickerState(loading: false, node: state.node));
      return;
    }
    final r = await _chats.suggestions(prompt);
    if (isClosed) return;
    r.fold(
      (f) => emit(TargetPickerState(loading: false, node: state.node, failure: f)),
      (s) => emit(TargetPickerState(
        suggestions: s,
        loading: false,
        node: state.node.isNotEmpty ? state.node : (s.pick?.node ?? s.candidates.where((c) => c.online).firstOrNull?.node ?? ''),
      )),
    );
  }

  void showNode(String node) => emit(TargetPickerState(suggestions: state.suggestions, loading: state.loading, node: node, failure: state.failure));
}

/// What the picker returns: a target, or null for auto.
class TargetChoice {
  const TargetChoice(this.target, {this.move = true});

  /// Null: let Tether decide (auto).
  final ChatTarget? target;

  /// For a chat already going: carry the conversation over now.
  final bool move;
}

/// Lets the user say where a chat works: Tether's pick, a device and folder,
/// or Claude working it out. [forChat] adds the choice of moving now.
Future<TargetChoice?> showTargetPicker(BuildContext context, {String prompt = '', ChatTarget? current, bool forChat = false}) {
  final hub = context.read<HubCubit>().state.hub;
  final body = BlocProvider(
    create: (_) => sl<TargetPickerCubit>(param1: prompt, param2: current == null || current.scratch ? '' : current.node),
    child: _TargetPicker(hub: hub, current: current, forChat: forChat),
  );
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<TargetChoice>(
      context: context,
      builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640), child: body)),
    );
  }
  return showModalBottomSheet<TargetChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.8, child: body),
  );
}

class _TargetPicker extends StatefulWidget {
  const _TargetPicker({required this.hub, required this.current, required this.forChat});

  final HubSnapshot hub;
  final ChatTarget? current;
  final bool forChat;

  @override
  State<_TargetPicker> createState() => _TargetPickerState();
}

class _TargetPickerState extends State<_TargetPicker> {
  bool _move = true;

  void _done(ChatTarget? t) => Navigator.pop(context, TargetChoice(t, move: _move));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hub = widget.hub;
    final online = [for (final n in hub.sortedNodes) if (n.online) n];
    return BlocBuilder<TargetPickerCubit, TargetPickerState>(
      builder: (context, s) {
        final cubit = context.read<TargetPickerCubit>();
        final folders = [for (final f in s.suggestions.candidates) if (f.node == s.node) f];
        final pick = s.suggestions.pick;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.forChat ? 'Where should this chat work?' : 'Where should Claude work?',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            if (widget.forChat)
              SwitchListTile(
                key: const Key('move-now'),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                value: _move,
                onChanged: (v) => setState(() => _move = v),
                title: const Text('Carry the conversation over now'),
                subtitle: Text(_move ? 'A new session starts there with everything said so far.' : 'Only used when the chat next needs a new session.'),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                children: [
                  if (!widget.forChat)
                    _Option(
                      key: const Key('target-auto'),
                      icon: Icons.auto_awesome_outlined,
                      title: 'Let Tether decide',
                      subtitle: pick != null
                          ? 'From what you wrote: ${pick.label} on ${pick.node} (${pick.reason})'
                          : 'Matches what you write to the folders you work in; if nothing fits, Claude works it out.',
                      selected: widget.current == null,
                      onTap: () => _done(null),
                    ),
                  if (hub.hubNode.isNotEmpty) ...[
                    _Option(
                      key: const Key('target-claude'),
                      icon: Icons.travel_explore_rounded,
                      title: 'Let Claude work it out',
                      subtitle: 'Claude starts in a scratch folder, finds the project, checks with you, then moves there.',
                      selected: widget.current?.mode == TargetMode.claude && widget.current!.detecting,
                      onTap: () => _done(const ChatTarget(mode: TargetMode.claude)),
                    ),
                    _Option(
                      key: const Key('target-scratch'),
                      icon: Icons.hub_outlined,
                      title: 'No project',
                      subtitle: 'A fresh scratch folder on ${hub.hubNode}, for questions and one-offs.',
                      selected: widget.current?.scratch ?? false,
                      onTap: () => _done(const ChatTarget.scratch()),
                    ),
                  ],
                  const SectionLabel('A folder on a device'),
                  if (online.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text('No devices are online.', style: TextStyle(color: c.danger, fontSize: 13)),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final n in online)
                          ChoiceChip(
                            key: Key('target-node-${n.name}'),
                            avatar: Icon(osIcon(n.os), size: 16),
                            label: Text(n.name),
                            selected: s.node == n.name,
                            onSelected: (_) => cubit.showNode(n.name),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  if (s.loading)
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  else if (s.node.isNotEmpty) ...[
                    for (final f in folders.take(25))
                      _Option(
                        key: Key('target-folder-${f.label}'),
                        icon: Icons.folder_outlined,
                        title: f.label,
                        subtitle: [f.cwd, if (f.reason.isNotEmpty) f.reason else if (f.lastUsed != null) 'used ${ago(f.lastUsed)} ago'].join('\n'),
                        badge: f == pick ? 'best match' : null,
                        selected: widget.current?.node == f.node && widget.current?.cwd == f.cwd && !(widget.current?.detecting ?? false),
                        onTap: () => _done(ChatTarget(mode: TargetMode.manual, node: f.node, cwd: f.cwd)),
                      ),
                    _Option(
                      key: const Key('target-home'),
                      icon: Icons.home_outlined,
                      title: 'Home folder',
                      subtitle: 'On ${s.node}',
                      selected: false,
                      onTap: () => _done(ChatTarget(mode: TargetMode.manual, node: s.node)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({super.key, required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap, this.badge});

  final IconData icon;
  final String title, subtitle;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? c.accent.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: selected ? c.accent : c.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
                          if (badge != null) ...[const SizedBox(width: 8), Pill(badge!, color: c.accent)],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: c.muted, height: 1.35)),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_rounded, size: 18, color: c.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
