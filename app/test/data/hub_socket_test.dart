import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:async/async.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:tether/data/datasources/hub_endpoint.dart';
import 'package:tether/data/datasources/hub_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A WebSocket the test plays the hub on: it reads what the app wrote and
/// says what it likes, or nothing at all.
class _Channel with StreamChannelMixin<dynamic> implements WebSocketChannel {
  _Channel({this.fail = false});

  final bool fail;
  final incoming = StreamController<dynamic>();
  final written = <Map<String, dynamic>>[];
  bool closed = false;

  @override
  Future<void> get ready => fail ? Future.error(Exception('connection refused')) : Future.value();

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  late final WebSocketSink sink = _Sink(this);

  void say(Map<String, dynamic> frame) => incoming.add(jsonEncode(frame));

  Iterable<String> kinds() => written.map((f) => f.keys.firstWhere((k) => k != 'v' && k != 'id'));

  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
}

class _Sink extends DelegatingStreamSink<dynamic> implements WebSocketSink {
  _Sink(this.ch) : super(StreamController<dynamic>());
  final _Channel ch;

  @override
  void add(dynamic data) => ch.written.add(jsonDecode(data as String) as Map<String, dynamic>);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async => ch.closed = true;
}

class _NoJitter implements Random {
  @override
  double nextDouble() => 1.0;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  late List<_Channel> channels;
  late List<SocketEvent> events;
  late WebSocketHubSocket socket;
  var failNext = 0;

  WebSocketHubSocket make() {
    final s = WebSocketHubSocket(
      clientName: 'test',
      platform: 'test',
      backoff: Backoff(random: _NoJitter()),
      channelFactory: (uri) {
        final ch = _Channel(fail: failNext > 0);
        if (failNext > 0) failNext--;
        channels.add(ch);
        return ch;
      },
    );
    s.events.listen(events.add);
    return s;
  }

  setUp(() {
    channels = [];
    events = [];
    failNext = 0;
  });

  final endpoint = HubEndpoint('ws://100.64.0.1:7420/ws', 'tok');

  test('backoff doubles to the cap, with jitter between half and all of it', () {
    final b = Backoff(random: _NoJitter());
    expect([for (var i = 0; i < 7; i++) b.next().inSeconds], [1, 2, 4, 8, 16, 30, 30]);
    b.reset();
    expect(b.next().inSeconds, 1);
    final r = Backoff(random: Random(1));
    for (var i = 0; i < 50; i++) {
      final d = r.next();
      final cap = min(30000, 1000 * (1 << min(i, 20)));
      expect(d.inMilliseconds, inInclusiveRange(cap ~/ 2, cap));
    }
  });

  test('a failed connect retries on the backoff and says when', () {
    fakeAsync((async) {
      failNext = 2;
      socket = make()..connect(endpoint);
      async.flushMicrotasks();
      final closed = events.whereType<SocketClosed>().single;
      expect(closed.attempts, 1);
      expect(closed.retryAt, isNotNull);
      expect(closed.error, contains('connection refused'));
      async.elapse(const Duration(milliseconds: 999));
      expect(channels, hasLength(1), reason: 'waits the backoff');
      async.elapse(const Duration(milliseconds: 1));
      expect(channels, hasLength(2));
      async.elapse(const Duration(seconds: 2));
      expect(channels, hasLength(3), reason: 'then twice as long');
      expect(events.whereType<SocketConnecting>().last.attempt, 3);
      expect(channels.last.kinds(), ['clientHello', 'clientPresence']);
      socket.close();
    });
  });

  test('a socket that stops answering is dropped and replaced', () {
    fakeAsync((async) {
      socket = make()..connect(endpoint);
      async.flushMicrotasks();
      final first = channels.single;
      first.say({'welcome': {'hubVersion': '0.17.0'}});
      async.flushMicrotasks();

      // The hub answers heartbeats: nothing happens.
      async.elapse(const Duration(seconds: 15));
      expect(first.kinds().last, 'heartbeat');
      first.say({'replyTo': first.written.last['id'], 'ack': {}});
      async.elapse(const Duration(seconds: 12));
      expect(channels, hasLength(1));

      // Then it goes quiet: after the timeout, the socket is closed and a new one opened.
      async.elapse(const Duration(seconds: 15));
      expect(first.closed, isTrue);
      expect(events.whereType<SocketClosed>().last.error, contains('no answer'));
      async.elapse(const Duration(seconds: 1));
      expect(channels, hasLength(2));
      socket.close();
    });
  });

  test('an older hub answering a heartbeat with an error still counts as alive', () {
    fakeAsync((async) {
      socket = make()..connect(endpoint);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 15));
      final ch = channels.single;
      ch.say({'replyTo': ch.written.last['id'], 'error': {'code': 'unsupported', 'message': 'unsupported request'}});
      async.elapse(const Duration(seconds: 12));
      expect(ch.closed, isFalse);
      socket.close();
    });
  });

  test('Retry replaces even a socket that looks open; so does a network change', () {
    fakeAsync((async) {
      socket = make()..connect(endpoint);
      async.flushMicrotasks();
      socket.retryNow();
      async.flushMicrotasks();
      expect(channels, hasLength(2));
      expect(channels.first.closed, isTrue);
      socket.networkChanged();
      async.flushMicrotasks();
      expect(channels, hasLength(3));
      socket.close();
    });
  });

  test('coming back to the foreground checks the connection, or retries at once if it was down', () {
    fakeAsync((async) {
      failNext = 1;
      socket = make()..connect(endpoint);
      async.flushMicrotasks();
      expect(events.last, isA<SocketClosed>());
      socket.setPresence(active: false);
      socket.setPresence(active: true);
      async.flushMicrotasks();
      expect(channels, hasLength(2), reason: "didn't wait out the backoff");

      // Now open: resuming sends a heartbeat at once rather than waiting 15s.
      socket.setPresence(active: false);
      socket.setPresence(active: true);
      expect(channels.last.kinds(), contains('heartbeat'));
      async.elapse(const Duration(seconds: 10));
      expect(channels.last.closed, isTrue, reason: 'no answer after resuming: reconnect');
      socket.close();
    });
  });

  test('a rejected token stops the retries', () {
    fakeAsync((async) {
      socket = make()..connect(endpoint);
      async.flushMicrotasks();
      channels.single.say({'error': {'code': 'unauthorized', 'message': 'bad token'}});
      channels.single.incoming.close();
      async.flushMicrotasks();
      final closed = events.whereType<SocketClosed>().single;
      expect(closed.unauthorized, isTrue);
      expect(closed.retryAt, isNull);
      async.elapse(const Duration(minutes: 5));
      expect(channels, hasLength(1));
      socket.close();
    });
  });
}
