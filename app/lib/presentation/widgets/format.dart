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

/// A token count, short: 950, 12.4k, 3.1M.
String tokens(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}k';
  return '${(n / 1000000).toStringAsFixed(n < 10000000 ? 1 : 0)}M';
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

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "Today", "Yesterday", a weekday within the week, else "Oct 3, 2026".
String dayLabel(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return _dayNames[t.weekday - 1];
  return '${_monthNames[t.month - 1]} ${t.day}, ${t.year}';
}

/// "3:20pm".
String clockTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')}${t.hour < 12 ? 'am' : 'pm'}';
}

/// A short name for a shell command, for a card's header: what it runs, not
/// the whole line ("go test ./…", "git status +2"). The full command is in the
/// card's body. A leading `cd dir &&` is skipped, only the first command is
/// named, and `+N` says how many more are chained after it.
String shellSummary(String command, {int max = 44}) {
  final line = command.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '').trim();
  var parts = line.split(RegExp(r'&&|\|\||;|\|')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  while (parts.isNotEmpty && RegExp(r'^cd(\s|$)').hasMatch(parts.first)) {
    parts = parts.sublist(1);
  }
  if (parts.isEmpty) return line.length <= max ? line : '${line.substring(0, max - 1)}…';
  // Quoted text and everything from the first redirection or heredoc on say little.
  final head = parts.first.replaceAll(RegExp(r'"[^"]*"|' "'[^']*'"), ' ').split(RegExp(r'(^|\s)\d*[<>]')).first.trim();
  var words = head.split(RegExp(r'\s+'));
  while (words.isNotEmpty && (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*=').hasMatch(words.first) || words.first == 'sudo' || words.first == 'export')) {
    words = words.sublist(1);
  }
  if (words.isEmpty) return line.length <= max ? line : '${line.substring(0, max - 1)}…';
  final more = parts.length - 1;
  final suffix = more > 0 ? ' +$more' : '';
  // The command's own name, then up to two plain words after it: a subcommand and a target.
  final shown = <String>[baseName(words.first).replaceAll(RegExp(r'\.exe$'), '')];
  for (final w in words.skip(1)) {
    // Flags and their numbers, quoted text and redirections or heredocs say little.
    if (w.startsWith('-') || w.startsWith('"') || w.startsWith("'") || RegExp(r'^\d*[<>]').hasMatch(w) || RegExp(r'^\d+$').hasMatch(w) || w.contains('=')) continue;
    shown.add(w.length > 24 ? '${w.substring(0, 23)}…' : w);
    if (shown.length == 3) break;
  }
  final text = shown.join(' ');
  final room = max - suffix.length;
  return (text.length <= room ? text : '${text.substring(0, room - 1)}…') + suffix;
}
