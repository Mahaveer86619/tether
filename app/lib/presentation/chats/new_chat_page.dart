import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../artifacts/attachments.dart';
import '../hub/hub_cubit.dart';
import '../nav/nav_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/prompt_box.dart';
import 'new_chat_cubit.dart';
import 'target_picker.dart';

/// A blank chat: say what you want, optionally say where, and go.
class NewChatPage extends StatelessWidget {
  const NewChatPage({super.key, this.node = '', this.leading});

  /// Start on this device, when opened from its page.
  final String node;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<NewChatCubit>(param1: node),
        child: _NewChat(leading: leading),
      );
}

class _NewChat extends StatefulWidget {
  const _NewChat({this.leading});

  final Widget? leading;

  @override
  State<_NewChat> createState() => _NewChatState();
}

class _NewChatState extends State<_NewChat> {
  final _text = TextEditingController();
  final _files = <Artifact>[];
  int _uploading = 0;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<NewChatCubit>();
    cubit.loadDraft().then((draft) {
      if (mounted && _text.text.isEmpty && draft.isNotEmpty) _text.text = draft;
    });
    _text.addListener(() {
      setState(() {});
      cubit.textChanged(_text.text);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    final added = await pickAndUpload(context, forMessage: true, onUploading: (n) => mounted ? setState(() => _uploading = n) : null);
    if (mounted && added.isNotEmpty) setState(() => _files.addAll(added));
  }

  Future<void> _pickTarget(NewChatState s) async {
    final cubit = context.read<NewChatCubit>();
    final choice = await showTargetPicker(context, prompt: _text.text, current: s.target);
    if (choice != null) cubit.setTarget(choice.target);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final connected = context.select<HubCubit, bool>((h) => h.state.hub.connected);
    return BlocConsumer<NewChatCubit, NewChatState>(
      listenWhen: (a, b) => a.failureId != b.failureId || a.sessionId != b.sessionId,
      listener: (context, s) {
        if (s.sessionId != null) {
          final nav = context.read<NavCubit>();
          nav.replaceTop(s.chatId != null ? ChatEntry(s.chatId!) : SessionEntry(s.sessionId!));
        } else if (s.failure != null) {
          showFailure(context, s.failure!);
        }
      },
      builder: (context, s) {
        final cubit = context.read<NewChatCubit>();
        final canSend = connected && !s.submitting && _uploading == 0 && (_text.text.trim().isNotEmpty || _files.isNotEmpty);
        void send() {
          if (canSend) cubit.submit(_text.text, attachments: [for (final f in _files) f.id]);
        }

        final (label, hint) = _targetText(s);
        return Column(
          children: [
            if (widget.leading != null) Align(alignment: Alignment.centerLeft, child: widget.leading!),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: narrow ? 14 : 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.hub_rounded, size: 30, color: c.accent),
                        const SizedBox(height: 12),
                        Text('What should Claude work on?',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: narrow ? 21 : 25, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 22),
                        PromptBox(
                          controller: _text,
                          fieldKey: const Key('new-chat-input'),
                          hint: 'Ask anything, or describe a task',
                          autofocus: !narrow,
                          canSubmit: canSend,
                          onSubmit: send,
                          header: _files.isEmpty && _uploading == 0
                              ? null
                              : AttachmentChips(files: _files, uploading: _uploading, onRemove: (f) => setState(() => _files.remove(f))),
                          actions: [
                            PromptButton(tooltip: 'Attach files', icon: Icons.attach_file_rounded, plain: true, onPressed: connected ? _attach : null),
                            PromptButton(
                              key: const Key('new-chat-send'),
                              tooltip: 'Start chat',
                              icon: Icons.arrow_upward_rounded,
                              filled: true,
                              busy: s.submitting,
                              onPressed: canSend ? send : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              key: const Key('target-chip'),
                              avatar: Icon(_targetIcon(s), size: 16, color: c.accent),
                              label: Text(label, overflow: TextOverflow.ellipsis),
                              onPressed: connected ? () => _pickTarget(s) : null,
                            ),
                            if (hint.isNotEmpty) Text(hint, style: TextStyle(fontSize: 12, color: c.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _targetIcon(NewChatState s) => switch (s.target) {
        null => Icons.auto_awesome_outlined,
        ChatTarget(mode: TargetMode.claude) => Icons.travel_explore_rounded,
        ChatTarget(scratch: true) => Icons.hub_outlined,
        _ => Icons.folder_outlined,
      };

  (String, String) _targetText(NewChatState s) => switch (s.target) {
        null when s.preview != null => ('Auto · ${s.preview!.label} on ${s.preview!.node}', s.preview!.reason),
        null => ('Auto', _text.text.trim().isEmpty ? 'Tether picks the folder from what you write' : 'Nothing points at a folder yet; Claude will work it out'),
        ChatTarget(mode: TargetMode.claude) => ('Claude works out where', ''),
        ChatTarget(scratch: true) => ('No project · scratch folder', ''),
        final t => ('${t.node} · ${t.cwd.isEmpty ? 'home folder' : baseName(t.cwd)}', ''),
      };
}
