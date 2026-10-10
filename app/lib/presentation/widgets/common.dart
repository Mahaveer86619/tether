import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../theme/theme.dart';
import 'format.dart';

bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

void showFailure(BuildContext context, Failure failure) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(failure.userMessage)));
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
            Text(text.toUpperCase(),
                style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: context.colors.faint)),
            const Spacer(),
            ?trailing,
          ],
        ),
      );
}

class ConnectionLine extends StatelessWidget {
  const ConnectionLine({super.key, required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, text) = switch (status) {
      ConnectionStatus.connected => (c.success, 'Connected'),
      ConnectionStatus.connecting => (c.warning, 'Connecting…'),
      ConnectionStatus.unauthorized => (c.danger, 'Token rejected'),
      ConnectionStatus.notConfigured => (c.faint, 'Not set up'),
      ConnectionStatus.offline => (c.danger, 'Offline · retrying'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted))),
      ],
    );
  }
}
