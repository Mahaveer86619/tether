import 'package:flutter_test/flutter_test.dart';
import 'package:tether/core/error/failures.dart';
import 'package:tether/core/result.dart';
import 'package:tether/core/version.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;

import 'package:tether/presentation/session/mode_picker.dart';

import '../helpers/fakes.dart';

void main() {
  test('time left on a timed mode reads plainly', () {
    final now = DateTime(2026, 10, 20, 12);
    expect(untilLabel(now.add(const Duration(seconds: 30)), now: now), 'now');
    expect(untilLabel(now.add(const Duration(minutes: 14, seconds: 59)), now: now), '14m left');
    expect(untilLabel(now.add(const Duration(hours: 1, minutes: 5)), now: now), '1h 5m left');
  });

  test('versions compare by their numbers, and builds without one are never flagged', () {
    expect(isOlderVersion('0.14.0', '0.15.0'), isTrue);
    expect(isOlderVersion('0.9.9', '0.10.0'), isTrue, reason: 'numbers, not text');
    expect(isOlderVersion('0.15.0', '0.15.0'), isFalse);
    expect(isOlderVersion('1.0.0', '0.15.0'), isFalse);
    expect(isOlderVersion('dev', '0.15.0'), isFalse);
    expect(isOlderVersion('0.13.0', ''), isFalse);
    expect(isOlderVersion('v0.14.2-rc1', '0.14.3'), isTrue);
  });

  group('Outbox', () {
    OutboxEntry entry(String id, String text, {OutboxState state = OutboxState.sent}) =>
        OutboxEntry(id: id, session: 's1', text: text, created: DateTime(2026), state: state, sentAt: DateTime(2026));
    TimelineItem user(String id, String text, {String clientId = '', bool queued = false}) =>
        TimelineItem(itemId: id, user: rpb.UserText(text: text, clientId: clientId, queued: queued));

    test('a message leaves the outbox once the timeline shows it, by client id', () {
      final pending = Outbox.pending(
        [entry('c1', 'run the tests'), entry('c2', 'then lint')],
        [user('u1', 'run the tests', clientId: 'c1'), user('q2', 'then lint', queued: true)],
      );
      expect(pending.map((e) => e.id), ['c2'], reason: 'a queued placeholder is not the message yet');
    });

    test('from a hub that stamps no ids, the latest messages are matched by text, once each', () {
      final pending = Outbox.pending(
        [entry('c1', 'again'), entry('c2', 'again'), entry('c3', 'with files', state: OutboxState.sent)],
        [user('u1', 'again'), user('u2', 'with files\r\n\r\nAttached files (in this folder):\r\n- a.png')],
      );
      expect(pending.map((e) => e.id), ['c2'], reason: 'one "again" arrived, so one is still to come');
    });

    test('unsent and failed messages stay whatever the timeline shows', () {
      final pending = Outbox.pending(
        [entry('c1', 'x', state: OutboxState.failed), entry('c2', 'y', state: OutboxState.sending)],
        [user('u1', 'x'), user('u2', 'y')],
      );
      expect(pending, hasLength(2));
    });

    test('a hub queued item stands for its message', () {
      final e = entry('c1', 'later');
      expect(Outbox.queuedOnHub(e, [user('q', 'later', queued: true)]), isTrue);
      expect(Outbox.queuedOnHub(e, [user('q', 'other', queued: true)]), isFalse);
    });

    test('a send cut short by the app closing comes back as failed, for a retry', () async {
      final settings = FakeSettingsRepository()..outboxes['s1'] = [entry('c1', 'x', state: OutboxState.sending)];
      final loaded = await Outbox(settings).load('s1');
      expect(loaded.single.state, OutboxState.failed);
      expect(loaded.single.error, isNotEmpty);
    });
  });

  group('SendMessage', () {
    test('rejects empty text without calling the hub', () async {
      final repo = FakeHubRepository(snapshotWith([session('s1')]));
      final r = await SendMessage(repo)('s1', '   ');
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(repo.sent, isEmpty);
    });

    test('refuses a session open in your own terminal, but allows forking it', () async {
      final repo = FakeHubRepository(snapshotWith([session('t1', host: SessionHost.terminal, state: SessionState.running)]));
      expect((await SendMessage(repo)('t1', 'hi')).failureOrNull, isA<TerminalActiveFailure>());
      final fork = await SendMessage(repo)('t1', 'hi', fork: true);
      expect(fork.valueOrNull, 'fork-of-t1');
      expect(repo.sent.single, ('t1', 'hi', true));
    });

    test('trims and sends to tmux sessions', () async {
      final repo = FakeHubRepository(snapshotWith([session('s1')]));
      expect((await SendMessage(repo)('s1', '  hello \n')).valueOrNull, 's1');
      expect(repo.sent.single.$2, 'hello');
    });

    test('unknown session is not found', () async {
      final repo = FakeHubRepository(snapshotWith([]));
      expect((await SendMessage(repo)('nope', 'x')).failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('CreateSession', () {
    test('requires a device and a prompt', () async {
      final repo = FakeHubRepository(snapshotWith([]));
      expect((await CreateSession(repo)(const NewSessionRequest(node: '', prompt: 'x'))).failureOrNull, isA<ValidationFailure>());
      expect((await CreateSession(repo)(const NewSessionRequest(node: 'minipc', prompt: ' '))).failureOrNull, isA<ValidationFailure>());
      expect(repo.created, isEmpty);
    });

    test('refuses offline devices', () async {
      final repo = FakeHubRepository(snapshotWith([], nodes: [const Node(name: 'minipc', online: false)]));
      expect((await CreateSession(repo)(const NewSessionRequest(node: 'minipc', prompt: 'x'))).failureOrNull, isA<NodeOfflineFailure>());
    });

    test('passes trimmed input through', () async {
      final repo = FakeHubRepository(snapshotWith([]));
      final r = await CreateSession(repo)(const NewSessionRequest(node: 'minipc', prompt: ' fix it ', cwd: ' /srv/app '));
      expect(r, isA<Ok<String>>());
      expect(repo.created.single, const NewSessionRequest(node: 'minipc', prompt: 'fix it', cwd: '/srv/app'));
    });
  });

  group('normalizeHubUrl', () {
    test('accepts the usual ways of writing the hub address', () {
      expect(normalizeHubUrl('100.64.0.1'), 'ws://100.64.0.1:7420/ws');
      expect(normalizeHubUrl('100.64.0.1:9000'), 'ws://100.64.0.1:9000/ws');
      expect(normalizeHubUrl('http://hub.tail.ts.net'), 'ws://hub.tail.ts.net:7420/ws');
      expect(normalizeHubUrl('https://hub.tail.ts.net:443'), 'wss://hub.tail.ts.net:443/ws');
      expect(normalizeHubUrl('https://hub.tail.ts.net'), 'wss://hub.tail.ts.net:443/ws');
      expect(normalizeHubUrl('ws://100.64.0.1:7420/ws'), 'ws://100.64.0.1:7420/ws');
    });

    test('rejects nonsense', () {
      expect(normalizeHubUrl(''), isNull);
      expect(normalizeHubUrl('ftp://x'), isNull);
    });
  });

  test('SaveConnection validates, saves and connects', () async {
    final repo = FakeHubRepository();
    final settings = FakeSettingsRepository();
    final save = SaveConnection(settings, repo);
    expect((await save('', 'tok')).failureOrNull, isA<ValidationFailure>());
    expect((await save('100.64.0.1', ' ')).failureOrNull, isA<ValidationFailure>());
    final ok = await save('100.64.0.1', ' tok ');
    expect(ok.valueOrNull, const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 'tok'));
    expect(settings.saved, ok.valueOrNull);
  });

  group('Pairing', () {
    test('a pairing code becomes the device token, with the pinned certificate', () async {
      final hub = FakeHubRepository(snapshotWith([]));
      final settings = FakeSettingsRepository();
      final pair = PairThisDevice(SaveConnection(settings, hub), hub, name: 'phone', platform: 'android');
      final ok = await pair('100.64.0.1', ' ABCDE-FGHJK ', fingerprint: 'ab12');
      expect(ok.valueOrNull, const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 'device-token', fingerprint: 'ab12'));
      expect(settings.saved, ok.valueOrNull);
      expect(hub.paired.single, ('ws://100.64.0.1:7420/ws', 'ABCDE-FGHJK', 'ab12'));
    });

    test('a wrong code saves nothing', () async {
      final hub = FakeHubRepository(snapshotWith([]));
      final settings = FakeSettingsRepository();
      final pair = PairThisDevice(SaveConnection(settings, hub), hub, name: 'phone', platform: 'android');
      expect((await pair('100.64.0.1', 'WRONG')).failureOrNull, isA<UnauthorizedFailure>());
      expect((await pair('100.64.0.1', ' ')).failureOrNull, isA<ValidationFailure>());
      expect(settings.saved.isComplete, isFalse);
    });

    test('over Tailscale, the machine name is enough', () async {
      final hub = FakeHubRepository(snapshotWith([]));
      final settings = FakeSettingsRepository();
      final ok = await ConnectOverTailnet(settings, hub)('minipc');
      expect(ok.valueOrNull, const HubConnection(url: 'ws://minipc:7420/ws', token: '', viaTailnet: true));
      expect(settings.saved.isComplete, isTrue);
      expect((await ConnectOverTailnet(settings, hub)(' ')).failureOrNull, isA<ValidationFailure>());
    });

    test('disconnecting revokes this device and forgets the hub', () async {
      final hub = FakeHubRepository(snapshotWith([]).copyWith(deviceId: 'd1'));
      final settings = FakeSettingsRepository()..saved = const HubConnection(url: 'ws://minipc:7420/ws', token: 't');
      expect((await DisconnectThisDevice(settings, hub)()).failureOrNull, isNull);
      expect(hub.devices.where((d) => d.id == 'd1'), isEmpty);
      expect(settings.saved.isComplete, isFalse);
      expect(hub.disconnected, isTrue);
    });

    test('the QR link round-trips', () {
      final invite = PairingInvite(code: 'ABCDE-FGHJK', expires: DateTime(2030), hubUrl: 'wss://hub.example:7420/ws', fingerprint: 'ab12');
      final parsed = parsePairingLink(invite.link);
      expect(parsed, (url: 'wss://hub.example:7420/ws', code: 'ABCDE-FGHJK', fingerprint: 'ab12'));
      expect(parsePairingLink('https://example.com'), isNull);
    });
  });

  test("the node on the app's own machine is told apart from the others", () {
    const here = Node(name: 'laptop', online: true, ip: '100.90.0.1');
    const there = Node(name: 'minipc', online: true, ip: '100.118.0.1');
    final hub = HubSnapshot(nodes: const {'laptop': here, 'minipc': there}, clientIp: '100.90.0.1');
    expect(hub.selfNode, 'laptop');
    expect(hub.otherNodes, [there]);
    // A phone runs no node, so every node is another device.
    expect(hub.copyWith(clientIp: '100.70.0.9').selfNode, '');
    expect(hub.copyWith(clientIp: '100.70.0.9').otherNodes, [here, there]);
  });

  test('new project folders are plain names joined with the device separator', () {
    expect(projectPath(r'C:\code', 'app', windows: true), r'C:\code\app');
    expect(projectPath('/srv/', 'app', windows: false), '/srv/app');
    for (final bad in ['', ' ', '..', 'a/b', r'a\b', 'x:y']) {
      expect(projectPath('/srv', bad, windows: false), isNull, reason: bad);
    }
  });
}
