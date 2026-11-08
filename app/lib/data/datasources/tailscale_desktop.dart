import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';

typedef RunTool = Future<ProcessResult> Function(String exe, List<String> args);
typedef StartTool = Future<Process> Function(String exe, List<String> args);

/// What `tailscale status --json` says, as a status. Anything that isn't
/// JSON is unknown.
TailscaleStatus parseTailscaleStatus(String json) {
  final Object? doc;
  try {
    doc = jsonDecode(json);
  } on FormatException {
    return const TailscaleStatus(TailscaleState.unknown);
  }
  if (doc is! Map<String, dynamic>) return const TailscaleStatus(TailscaleState.unknown);
  return switch (doc['BackendState']) {
    'Running' => const TailscaleStatus(TailscaleState.running),
    'Starting' || 'NoState' => const TailscaleStatus(TailscaleState.starting),
    'Stopped' => const TailscaleStatus(TailscaleState.stopped),
    'NeedsLogin' => TailscaleStatus(TailscaleState.needsLogin, loginUrl: doc['AuthURL'] as String? ?? ''),
    'NeedsMachineAuth' => const TailscaleStatus(TailscaleState.needsLogin, message: 'This device needs approving in your Tailscale admin console.'),
    _ => const TailscaleStatus(TailscaleState.unknown),
  };
}

/// The other devices in `tailscale status --json`, with an IPv4 address each
/// (the one a hub is reached at); this device is not among them.
List<TailnetPeer> parseTailnetPeers(String json) {
  final Object? doc;
  try {
    doc = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  final peers = doc is Map<String, dynamic> ? doc['Peer'] : null;
  if (peers is! Map<String, dynamic>) return const [];
  final out = <TailnetPeer>[];
  for (final p in peers.values) {
    if (p is! Map<String, dynamic>) continue;
    final ips = [for (final ip in p['TailscaleIPs'] as List<dynamic>? ?? const []) '$ip'];
    final v4 = ips.where((ip) => !ip.contains(':')).firstOrNull;
    if (v4 == null) continue;
    final name = (p['HostName'] as String?) ?? ((p['DNSName'] as String?) ?? '').split('.').first;
    out.add(TailnetPeer(name: name.isEmpty ? v4 : name, ip: v4, online: p['Online'] == true, os: p['OS'] as String? ?? ''));
  }
  out.sort((a, b) => a.online == b.online ? a.name.compareTo(b.name) : (a.online ? -1 : 1));
  return out;
}

/// Checks and starts Tailscale on a desktop through its command line, so the
/// owner doesn't have to open it first. It never changes how Tailscale is set
/// up: `up` is given the flags Tailscale itself says the current setup needs.
class DesktopTailscale implements TailscaleRepository {
  DesktopTailscale({
    String? os,
    RunTool? run,
    StartTool? startProcess,
    bool Function(String path)? exists,
    this.poll = const Duration(seconds: 2),
    this.startTimeout = const Duration(seconds: 90),
    this.loginTimeout = const Duration(minutes: 5),
  })  : _os = os ?? Platform.operatingSystem,
        _run = run ?? ((exe, args) => Process.run(exe, args)),
        _startProcess = startProcess ?? ((exe, args) => Process.start(exe, args)),
        _exists = exists ?? ((p) => File(p).existsSync());

  final String _os;
  final RunTool _run;
  final StartTool _startProcess;
  final bool Function(String) _exists;
  final Duration poll, startTimeout, loginTimeout;
  String? _exe;

  @override
  bool get canStart => true;

  List<String> get _installed => switch (_os) {
        'windows' => [r'C:\Program Files\Tailscale\tailscale.exe', r'C:\Program Files (x86)\Tailscale\tailscale.exe'],
        'macos' => ['/Applications/Tailscale.app/Contents/MacOS/Tailscale', '/opt/homebrew/bin/tailscale', '/usr/local/bin/tailscale'],
        _ => ['/usr/bin/tailscale', '/usr/local/bin/tailscale'],
      };

  /// Where the command line is, or null if Tailscale isn't installed.
  Future<String?> _find() async {
    if (_exe != null) return _exe;
    for (final p in _installed) {
      if (_exists(p)) return _exe = p;
    }
    try {
      final r = await _run('tailscale', ['version']);
      if (r.exitCode == 0) return _exe = 'tailscale';
    } on ProcessException {
      // Not on the PATH either.
    }
    return null;
  }

  @override
  Future<TailscaleStatus> status() async {
    final exe = await _find();
    if (exe == null) return const TailscaleStatus(TailscaleState.notInstalled);
    final ProcessResult r;
    try {
      r = await _run(exe, ['status', '--json']).timeout(const Duration(seconds: 8));
    } on TimeoutException {
      return const TailscaleStatus(TailscaleState.serviceStopped, message: "Tailscale isn't answering.");
    } on ProcessException {
      _exe = null;
      return const TailscaleStatus(TailscaleState.notInstalled);
    }
    final out = '${r.stdout}'.trim();
    if (out.startsWith('{')) return parseTailscaleStatus(out);
    // The command line is there but the service behind it isn't answering.
    return TailscaleStatus(TailscaleState.serviceStopped, message: _lastLine('${r.stderr}${r.stdout}'));
  }

  @override
  Future<List<TailnetPeer>> peers() async {
    final exe = await _find();
    if (exe == null) return const [];
    try {
      final r = await _run(exe, ['status', '--json']).timeout(const Duration(seconds: 8));
      return parseTailnetPeers('${r.stdout}');
    } on TimeoutException {
      return const [];
    } on ProcessException {
      return const [];
    }
  }

  @override
  Stream<TailscaleStatus> start() async* {
    var s = await status();
    yield s;
    if (s.running || s.state == TailscaleState.notInstalled || s.state == TailscaleState.unsupported) return;
    final exe = (await _find())!;

    if (s.state == TailscaleState.serviceStopped) {
      final problem = await _startService();
      if (problem != null) {
        s = TailscaleStatus(TailscaleState.serviceStopped, message: problem);
        yield s;
      }
    }

    var last = s;
    var deadline = DateTime.now().add(startTimeout);
    Process? up;
    var upExit = -1;
    var upOut = StringBuffer();
    var retriedWithFlags = false;
    var url = '';

    Future<void> launchUp(List<String> args) async {
      upOut = StringBuffer();
      upExit = -1;
      final p = await _startProcess(exe, args);
      up = p;
      for (final stream in [p.stdout, p.stderr]) {
        stream.transform(utf8.decoder).listen((t) {
          upOut.write(t);
          url = _loginUrl(upOut.toString()) ?? url;
        }, onError: (_) {});
      }
      unawaited(p.exitCode.then((c) => upExit = c));
    }

    try {
      while (DateTime.now().isBefore(deadline)) {
        final now = await status();
        if (now.running) {
          yield now;
          return;
        }
        // Switched off, or waiting for a sign-in: ask Tailscale to come up once.
        if (up == null && (now.state == TailscaleState.stopped || now.state == TailscaleState.needsLogin)) {
          try {
            await launchUp(['up']);
          } on ProcessException catch (e) {
            yield TailscaleStatus(now.state, message: e.message);
            return;
          }
        }
        if (up != null && upExit > 0) {
          // `up` refuses when the setup has settings it would change; Tailscale prints the command that keeps them.
          final again = retriedWithFlags ? null : _suggestedUp(upOut.toString());
          if (again != null) {
            retriedWithFlags = true;
            await launchUp(again);
            continue;
          }
          yield TailscaleStatus(now.state, loginUrl: url, message: _lastLine(upOut.toString()));
          return;
        }
        var shown = now;
        if (now.state == TailscaleState.needsLogin) {
          shown = TailscaleStatus(TailscaleState.needsLogin, loginUrl: now.loginUrl.isNotEmpty ? now.loginUrl : url, message: now.message);
          // Signing in takes a person; give them time.
          final longer = DateTime.now().add(loginTimeout);
          if (longer.isAfter(deadline)) deadline = longer;
        }
        if (shown != last) {
          last = shown;
          yield shown;
        }
        await Future<void>.delayed(poll);
      }
      yield TailscaleStatus(last.state, loginUrl: last.loginUrl, message: last.message.isEmpty ? "Tailscale didn't come up in time." : last.message);
    } finally {
      up?.kill();
    }
  }

  /// Starts the Tailscale service; null if that worked or was already so,
  /// otherwise what to tell the owner.
  Future<String?> _startService() async {
    try {
      switch (_os) {
        case 'windows':
          final r = await _run('sc', ['start', 'Tailscale']);
          // 1056: already running. 5: needs an administrator.
          if (r.exitCode == 0 || r.exitCode == 1056) return null;
          if (r.exitCode == 5) return 'Starting the Tailscale service needs administrator rights. Open Tailscale from the Start menu.';
          return _lastLine('${r.stdout}${r.stderr}');
        case 'macos':
          await _run('open', ['-a', 'Tailscale']);
          return null;
        default:
          final r = await _run('systemctl', ['start', 'tailscaled']);
          return r.exitCode == 0 ? null : 'Run "sudo systemctl start tailscaled" to start Tailscale.';
      }
    } on ProcessException catch (e) {
      return e.message;
    }
  }

  @override
  Future<void> openApp() async {
    try {
      switch (_os) {
        case 'windows':
          final dir = (await _find())?.replaceFirst(RegExp(r'tailscale\.exe$'), '');
          final gui = '${dir ?? r'C:\Program Files\Tailscale\'}tailscale-ipn.exe';
          if (_exists(gui)) await _startProcess(gui, const []);
        case 'macos':
          await _run('open', ['-a', 'Tailscale']);
      }
    } on ProcessException {
      // Nothing to open.
    }
  }

  static String? _loginUrl(String text) => RegExp(r'https://[^\s"]+').firstMatch(text)?.group(0);

  /// The arguments of the `tailscale up ...` command that `up` suggests when it
  /// refuses for a setup with non-default settings.
  static List<String>? _suggestedUp(String text) {
    if (!text.contains('non-default flags')) return null;
    for (final line in text.split('\n')) {
      // The suggestion is a line of its own; the explanation also names the command.
      final t = line.trim();
      if (!t.startsWith('tailscale up ')) continue;
      final args = t.substring('tailscale up'.length).trim().split(RegExp(r'\s+'));
      if (args.isNotEmpty && args.first.startsWith('--')) return ['up', ...args];
    }
    return null;
  }

  static String _lastLine(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return lines.isEmpty ? '' : lines.last;
  }
}
