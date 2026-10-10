import 'package:flutter/material.dart';

import '../../domain/entities/entities.dart';
import '../theme/theme.dart';

String ago(DateTime? time) {
  if (time == null) return '';
  final d = DateTime.now().difference(time);
  if (d.inSeconds < 45) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 30) return '${d.inDays}d';
  return '${d.inDays ~/ 30}mo';
}

String baseName(String path) {
  final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty).toList();
  return parts.isEmpty ? path : parts.last;
}

String stateLabel(SessionState s) => switch (s) {
      SessionState.running => 'Working',
      SessionState.awaitingApproval => 'Needs approval',
      SessionState.ready => 'Waiting for input',
      SessionState.terminalActive => 'Open in a terminal',
      SessionState.error => 'Error',
      SessionState.idle => 'Idle',
    };

Color stateColor(BuildContext context, SessionState s) {
  final c = context.colors;
  return switch (s) {
    SessionState.running => c.accent,
    SessionState.awaitingApproval => c.warning,
    SessionState.ready => c.success,
    SessionState.terminalActive => c.info,
    SessionState.error => c.danger,
    SessionState.idle => c.faint,
  };
}

String hostLabel(SessionHost h) => switch (h) {
      SessionHost.tmux => 'tmux',
      SessionHost.headless => 'headless',
      SessionHost.terminal => 'terminal',
      SessionHost.none => '',
    };

IconData osIcon(String os) => switch (os) {
      'windows' => Icons.laptop_windows_outlined,
      'darwin' => Icons.laptop_mac_outlined,
      'linux' => Icons.dns_outlined,
      _ => Icons.computer_outlined,
    };

String shortModel(String model) {
  final m = RegExp(r'claude-(\w+)-(\d+)-(\d+)').firstMatch(model);
  if (m == null) return model;
  final name = m.group(1)!;
  return '${name[0].toUpperCase()}${name.substring(1)} ${m.group(2)}.${m.group(3)}';
}
