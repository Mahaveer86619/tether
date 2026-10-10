import 'package:flutter_test/flutter_test.dart';
import 'package:tether/core/error/failures.dart';
import 'package:tether/core/result.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/usecases/usecases.dart';

import '../helpers/fakes.dart';

void main() {
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
}
