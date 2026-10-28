import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../theme/theme.dart';
import 'format.dart';

bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Runs [change] (usually a setState that opens or closes something) so the
/// widget at [context] keeps its place on screen. In the chat list, which is
/// anchored at the bottom, growing content would otherwise push it upwards.
void keepInPlace(BuildContext context, VoidCallback change) {
  final box = context.findRenderObject();
  final scroll = Scrollable.maybeOf(context);
  if (box is! RenderBox || !box.attached || scroll == null) return change();
  final before = box.localToGlobal(Offset.zero).dy;
  change();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!box.attached || !scroll.position.hasPixels) return;
    final moved = box.localToGlobal(Offset.zero).dy - before;
    final p = scroll.position;
    final delta = scroll.axisDirection == AxisDirection.up ? -moved : moved;
    p.jumpTo((p.pixels + delta).clamp(p.minScrollExtent, p.maxScrollExtent));
  });
}

void showFailure(BuildContext context, Failure failure) =>
    showToast(context, failure.userMessage, icon: Icons.error_outline_rounded, error: true);

/// A small floating message, centred above the content instead of a
/// full-width bar.
void showToast(BuildContext context, String message, {IconData icon = Icons.check_rounded, bool error = false}) {
  final c = context.colors;
  // Centre on the pane that shows it (its own Scaffold), above the composer.
  final width = context.findAncestorStateOfType<ScaffoldState>()?.context.size?.width ?? MediaQuery.sizeOf(context).width;
  final side = width > 520 ? (width - 400) / 2 : 16.0;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(side, 0, side, 132),
        backgroundColor: c.raised,
        elevation: 8,
        duration: Duration(seconds: error ? 4 : 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: error ? c.danger.withValues(alpha: 0.5) : c.border),
        ),
        content: Row(
          children: [
            Icon(icon, size: 18, color: error ? c.danger : c.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.text, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
}

/// A session's state as a small dot that pulses while Claude is working.
class StateDot extends StatefulWidget {
  const StateDot({super.key, required this.state, this.size = 8});

  final SessionState state;
  final double size;

  @override
  State<StateDot> createState() => _StateDotState();
}

class _StateDotState extends State<StateDot> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  bool get _busy => widget.state == SessionState.running || widget.state == SessionState.awaitingApproval;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(StateDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_busy) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(color: stateColor(context, widget.state), shape: BoxShape.circle),
        ),
      );
}

/// Shows the first [maxLines] of [lines] lines with a button for the rest.
/// Long output stays inside the chat's one scroll instead of a nested one.
class LineClamp extends StatefulWidget {
  const LineClamp({super.key, required this.lines, required this.maxLines, required this.builder});

  final int lines;
  final int maxLines;

  /// Builds the content showing at most `limit` lines, or all when null.
  final Widget Function(int? limit) builder;

  @override
  State<LineClamp> createState() => _LineClampState();
}

class _LineClampState extends State<LineClamp> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.lines > widget.maxLines;
    if (!long) return widget.builder(null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.builder(_all ? null : widget.maxLines),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 12.5)),
            onPressed: () => keepInPlace(context, () => setState(() => _all = !_all)),
            icon: Icon(_all ? Icons.unfold_less_rounded : Icons.unfold_more_rounded, size: 16),
            label: Text(_all ? 'Show less' : 'Show all ${widget.lines} lines'),
          ),
        ),
      ],
    );
  }
}

class OnlineDot extends StatelessWidget {
  const OnlineDot({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: online ? context.colors.success : context.colors.faint, shape: BoxShape.circle),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: (color ?? c.muted).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: TextStyle(fontSize: 11, color: color ?? c.muted, fontWeight: FontWeight.w500)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: c.faint),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(body!, style: TextStyle(color: c.muted), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: context.colors.faint)),
            ),
            ?trailing,
          ],
        ),
      );
}

/// The connection's state in a few words: connected, connecting (with the
/// attempt), or offline with a countdown to the next try. Tapping it
/// retries now; the last error shows on hover or long press.
class ConnectionLine extends StatefulWidget {
  const ConnectionLine({super.key, required this.status, this.retryAt, this.attempts = 0, this.error, this.onRetry});

  final ConnectionStatus status;
  final DateTime? retryAt;
  final int attempts;
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<ConnectionLine> createState() => _ConnectionLineState();
}

class _ConnectionLineState extends State<ConnectionLine> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(ConnectionLine old) {
    super.didUpdateWidget(old);
    _schedule();
  }

  // A countdown needs a redraw every second; nothing else does.
  void _schedule() {
    _tick?.cancel();
    _tick = widget.retryAt == null ? null : Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final w = widget;
    final wait = w.retryAt?.difference(DateTime.now());
    final (color, text) = switch (w.status) {
      ConnectionStatus.connected => (c.success, 'Connected'),
      ConnectionStatus.connecting => (c.warning, w.attempts > 0 ? 'Reconnecting… (try ${w.attempts + 1})' : 'Connecting…'),
      ConnectionStatus.unauthorized => (c.danger, 'Token rejected'),
      ConnectionStatus.notConfigured => (c.faint, 'Not set up'),
      ConnectionStatus.offline when wait != null && wait.inSeconds > 0 => (c.danger, 'Offline · retrying in ${wait.inSeconds + 1}s'),
      ConnectionStatus.offline => (c.danger, 'Offline · retrying'),
    };
    final retryable = w.onRetry != null && w.status != ConnectionStatus.connected && w.status != ConnectionStatus.notConfigured;
    final line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted))),
        if (retryable) ...[
          const SizedBox(width: 6),
          Text('Retry', style: TextStyle(fontSize: 12, color: c.accent, fontWeight: FontWeight.w600)),
        ],
      ],
    );
    final tip = [
      if (w.error != null && w.status != ConnectionStatus.connected) w.error!,
      if (w.attempts > 0 && w.status != ConnectionStatus.connected) '${w.attempts} failed ${w.attempts == 1 ? 'try' : 'tries'}',
    ].join('\n');
    final body = retryable ? InkWell(key: const Key('connection-retry'), borderRadius: BorderRadius.circular(6), onTap: w.onRetry, child: line) : line;
    return tip.isEmpty ? body : Tooltip(message: tip, child: body);
  }
}
