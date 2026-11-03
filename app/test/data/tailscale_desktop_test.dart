import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tether/data/datasources/tailscale_desktop.dart';
import 'package:tether/domain/entities/entities.dart';

String statusJson(String backend, {String authUrl = ''}) => jsonEncode({'BackendState': backend, 'AuthURL': authUrl});

/// A process whose output is given and whose exit the test decides.
class FakeProcess implements Process {
  FakeProcess({String out = '', String err = '', int? exit}) {
    _out.add(utf8.encode(out));
    _err.add(utf8.encode(err));
    if (exit != null) _exit.complete(exit);
  }

  final _out = StreamController<List<int>>();
  final _err = StreamController<List<int>>();
  final _exit = Completer<int>();
  bool killed = false;

  @override
  Stream<List<int>> get stdout => _out.stream;
  @override
  Stream<List<int>> get stderr => _err.stream;
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 1;
  @override
  IOSink get stdin => throw UnimplementedError();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    return true;
  }
}

/// The command line as a script: `tailscale status --json` answers come from
/// [statuses] in turn (the last one repeats), other tools from [tools].
class Script {
  Script(this.statuses, {this.tools = const {}});

  final List<String> statuses;
  final Map<String, ProcessResult> tools;
  final calls = <String>[];
  final started = <List<String>>[];
  final processes = <FakeProcess>[];
  final upProcesses = <FakeProcess>[];
  var _i = 0;

  Future<ProcessResult> run(String exe, List<String> args) async {
    calls.add('$exe ${args.join(' ')}');
    if (args.isNotEmpty && args.first == 'status') {
      final s = statuses[_i < statuses.length ? _i : statuses.length - 1];
      _i++;
      return s.startsWith('{') ? ProcessResult(1, 0, s, '') : ProcessResult(1, 1, '', s);
    }
    return tools[exe] ?? ProcessResult(1, 0, '', '');
  }

  Future<Process> start(String exe, List<String> args) async {
    started.add(args);
    final p = upProcesses.isNotEmpty ? upProcesses.removeAt(0) : FakeProcess(exit: 0);
    processes.add(p);
    return p;
  }
}

DesktopTailscale desktop(Script s, {bool installed = true, String os = 'windows', Duration timeout = const Duration(seconds: 5)}) => DesktopTailscale(
      os: os,
      run: s.run,
      startProcess: s.start,
      exists: (_) => installed,
      poll: const Duration(milliseconds: 5),
      startTimeout: timeout,
      loginTimeout: timeout,
    );

void main() {
  group('parseTailscaleStatus', () {
    test('reads each state the command line reports', () {
      expect(parseTailscaleStatus(statusJson('Running')).state, TailscaleState.running);
      expect(parseTailscaleStatus(statusJson('Starting')).state, TailscaleState.starting);
      expect(parseTailscaleStatus(statusJson('NoState')).state, TailscaleState.starting);
      expect(parseTailscaleStatus(statusJson('Stopped')).state, TailscaleState.stopped);
      final login = parseTailscaleStatus(statusJson('NeedsLogin', authUrl: 'https://login.tailscale.com/a/abc'));
      expect((login.state, login.loginUrl), (TailscaleState.needsLogin, 'https://login.tailscale.com/a/abc'));
      expect(parseTailscaleStatus(statusJson('NeedsMachineAuth')).message, contains('approving'));
    });

    test('anything else is unknown', () {
      expect(parseTailscaleStatus('not json').state, TailscaleState.unknown);
      expect(parseTailscaleStatus('[1]').state, TailscaleState.unknown);
      expect(parseTailscaleStatus(statusJson('Something new')).state, TailscaleState.unknown);
    });
  });

  group('DesktopTailscale', () {
    test('a running Tailscale is left alone', () async {
      final s = Script([statusJson('Running')]);
      final seen = await desktop(s).start().toList();
      expect(seen.map((x) => x.state), [TailscaleState.running]);
      expect(s.started, isEmpty, reason: 'nothing is started when it is already up');
      expect(s.calls.where((c) => c.contains('sc ')), isEmpty);
    });

    test('no Tailscale on the machine is reported, and nothing is run', () async {
      final s = Script([statusJson('Running')]);
      final t = DesktopTailscale(
        os: 'windows',
        run: (exe, args) => throw const ProcessException('tailscale', ['version'], 'not found'),
        startProcess: s.start,
        exists: (_) => false,
      );
      expect((await t.status()).state, TailscaleState.notInstalled);
      expect((await t.start().toList()).single.state, TailscaleState.notInstalled);
      expect(s.started, isEmpty);
    });

    test('a switched-off Tailscale is brought up, and the stream ends when it is running', () async {
      final s = Script([statusJson('Stopped'), statusJson('Stopped'), statusJson('Starting'), statusJson('Running')]);
      final seen = await desktop(s).start().toList();
      expect(seen.map((x) => x.state), [TailscaleState.stopped, TailscaleState.starting, TailscaleState.running]);
      expect(s.started, [
        ['up']
      ]);
      expect(s.processes.single.killed, isTrue, reason: 'the up command is not left running');
    });

    test('a sign-in is waited for, and its address comes from what `up` prints', () async {
      final s = Script([statusJson('NeedsLogin'), statusJson('NeedsLogin'), statusJson('NeedsLogin'), statusJson('Running')]);
      s.upProcesses.add(FakeProcess(out: 'To authenticate, visit:\n\n\thttps://login.tailscale.com/a/xyz123\n'));
      final seen = await desktop(s).start().toList();
      final login = seen.firstWhere((x) => x.loginUrl.isNotEmpty);
      expect((login.state, login.loginUrl), (TailscaleState.needsLogin, 'https://login.tailscale.com/a/xyz123'));
      expect(seen.last.state, TailscaleState.running);
    });

    test('when `up` refuses for a setup with settings, it is run again with the command Tailscale gives', () async {
      final s = Script([statusJson('Stopped'), statusJson('Stopped'), statusJson('Stopped'), statusJson('Running')]);
      s.upProcesses.add(FakeProcess(
        err: "Error: changing settings via 'tailscale up' requires mentioning all\nnon-default flags. To proceed, either re-run your command with --reset or\nuse the command below to explicitly mention the current value of\nall non-default settings:\n\n\ttailscale up --unattended --accept-routes\n",
        exit: 1,
      ));
      final seen = await desktop(s).start().toList();
      expect(s.started, [
        ['up'],
        ['up', '--unattended', '--accept-routes'],
      ]);
      expect(seen.last.state, TailscaleState.running);
    });

    test('a stopped service is started first on Windows, and a refusal is explained', () async {
      final s = Script(['failed to connect to local Tailscale service; is Tailscale running?', 'failed to connect to local Tailscale service; is Tailscale running?', statusJson('Running')],
          tools: {'sc': ProcessResult(1, 0, '', '')});
      final seen = await desktop(s).start().toList();
      expect(s.calls, contains('sc start Tailscale'));
      expect((seen.first.state, seen.last.state), (TailscaleState.serviceStopped, TailscaleState.running));

      final denied = Script(['failed to connect to local Tailscale service; is Tailscale running?'], tools: {'sc': ProcessResult(1, 5, '', 'Access is denied.')});
      final refused = await desktop(denied, timeout: const Duration(milliseconds: 60)).start().toList();
      expect(refused.any((x) => x.message.contains('administrator rights')), isTrue);
      expect(refused.last.running, isFalse);
    });

    test('it gives up after its time and says so', () async {
      final s = Script([statusJson('Starting')]);
      final seen = await desktop(s, timeout: const Duration(milliseconds: 60)).start().toList();
      expect(seen.last.running, isFalse);
      expect(seen.last.message, contains("didn't come up"));
    });

    test('on a Mac the app is opened, on Linux the service is asked for', () async {
      final mac = Script(['failed to connect', statusJson('Running')]);
      await desktop(mac, os: 'macos').start().toList();
      expect(mac.calls, contains('open -a Tailscale'));
      final linux = Script(['failed to connect', statusJson('Running')], tools: {'systemctl': ProcessResult(1, 1, '', 'denied')});
      final seen = await desktop(linux, os: 'linux').start().toList();
      expect(linux.calls, contains('systemctl start tailscaled'));
      expect(seen.any((x) => x.message.contains('sudo systemctl start tailscaled')), isTrue);
    });
  });
}
