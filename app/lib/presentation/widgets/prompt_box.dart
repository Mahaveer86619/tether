import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import 'common.dart';

const double _row = 40;

/// The app's message box. It grows with its text up to a few lines, keeps
/// the hint, the text and the buttons on one centred row, and opens a full
/// editor when the text gets long.
class PromptBox extends StatefulWidget {
  const PromptBox({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSubmit,
    this.fieldKey,
    this.enabled = true,
    this.canSubmit = true,
    this.autofocus = false,
    this.onEscape,
    this.actions = const [],
    this.header,
    this.footer,
    this.highlight = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final VoidCallback onSubmit;
  final Key? fieldKey;
  final bool enabled, canSubmit, autofocus;
  final VoidCallback? onEscape;

  /// Buttons at the end of the row, usually stop and send. [PromptButton]
  /// sizes them to the row.
  final List<Widget> actions;

  /// Shown above the text (e.g. a fork banner) and below it (e.g. hints).
  final Widget? header, footer;

  /// Draws the border in the accent colour.
  final bool highlight;

  @override
  State<PromptBox> createState() => _PromptBoxState();
}

class _PromptBoxState extends State<PromptBox> {
  bool _long = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_measure);
    _measure();
  }

  @override
  void didUpdateWidget(PromptBox old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_measure);
      widget.controller.addListener(_measure);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_measure);
    super.dispose();
  }

  // Long enough that the full editor helps.
  void _measure() {
    final t = widget.controller.text;
    final long = '\n'.allMatches(t).length >= 2 || t.length > 180;
    if (long != _long) setState(() => _long = long);
  }

  Future<void> _openEditor() async {
    final send = await (isDesktop
        ? showDialog<bool>(
            context: context,
            builder: (_) => Dialog(
              insetPadding: const EdgeInsets.all(40),
              child: SizedBox(
                width: 820,
                height: MediaQuery.sizeOf(context).height * 0.75,
                child: _Editor(controller: widget.controller, hint: widget.hint, canSubmit: widget.canSubmit),
              ),
            ),
          )
        : Navigator.of(context).push<bool>(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => Scaffold(
              body: SafeArea(child: _Editor(controller: widget.controller, hint: widget.hint, canSubmit: widget.canSubmit)),
            ),
          )));
    if (send ?? false) widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final compact = !isDesktop;
    final field = CallbackShortcuts(
      bindings: {
        if (isDesktop) const SingleActivator(LogicalKeyboardKey.enter): widget.onSubmit,
        if (widget.onEscape != null) const SingleActivator(LogicalKeyboardKey.escape): widget.onEscape!,
      },
      child: TextField(
        key: widget.fieldKey,
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        minLines: 1,
        maxLines: compact ? 5 : 8,
        textInputAction: TextInputAction.newline,
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: widget.hint,
          filled: false,
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          // At least as tall as the buttons, so one line sits on their centre.
          constraints: const BoxConstraints(minHeight: _row),
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(compact ? 24 : 18),
        border: Border.all(color: widget.highlight ? c.accent.withValues(alpha: 0.6) : c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      padding: EdgeInsets.fromLTRB(compact ? 16 : 14, 6, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?widget.header,
          Row(
            // Buttons stay on the last line as the text grows.
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: field),
              if (_long)
                PromptButton(
                  tooltip: 'Expand',
                  icon: Icons.open_in_full_rounded,
                  onPressed: widget.enabled ? _openEditor : null,
                  plain: true,
                ),
              for (final a in widget.actions) Padding(padding: const EdgeInsets.only(left: 4), child: a),
            ],
          ),
          ?widget.footer,
        ],
      ),
    );
  }
}

/// A round button sized to the prompt row.
class PromptButton extends StatelessWidget {
  const PromptButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.filled = false, this.plain = false, this.busy = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// The accent-coloured main action (send).
  final bool filled;

  /// No border: a quiet helper button.
  final bool plain;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = IconButton.styleFrom(
      fixedSize: const Size.square(_row),
      minimumSize: const Size.square(_row),
      padding: EdgeInsets.zero,
      backgroundColor: filled ? c.accent : null,
      disabledBackgroundColor: filled ? c.raised : null,
      foregroundColor: filled ? Colors.white : c.muted,
      side: filled || plain ? null : BorderSide(color: c.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final child = busy
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(icon, size: filled ? 20 : 18);
    return IconButton(tooltip: tooltip, onPressed: onPressed, style: style, icon: child);
  }
}

/// The full editor for long messages; pops true to send.
class _Editor extends StatelessWidget {
  const _Editor({required this.controller, required this.hint, required this.canSubmit});

  final TextEditingController controller;
  final String hint;
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    void send() {
      if (canSubmit && controller.text.trim().isNotEmpty) Navigator.pop(context, true);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              IconButton(tooltip: 'Collapse', icon: const Icon(Icons.close_fullscreen_rounded), onPressed: () => Navigator.pop(context, false)),
            ],
          ),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter, control: true): send,
                const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context, false),
              },
              child: TextField(
                key: const Key('editor'),
                controller: controller,
                autofocus: true,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(hintText: hint, filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(isDesktop ? 'Ctrl+Enter to send · Esc to go back' : '', style: TextStyle(fontSize: 11.5, color: c.faint)),
              ),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => FilledButton.icon(
                  key: const Key('editor-send'),
                  onPressed: canSubmit && controller.text.trim().isNotEmpty ? send : null,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  label: const Text('Send'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
