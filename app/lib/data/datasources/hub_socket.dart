import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/version.dart';
import '../../gen/tether/v1/tether.pb.dart' as pb;
import 'hub_endpoint.dart';

sealed class SocketEvent {
  const SocketEvent();
}

class SocketConnecting extends SocketEvent {
  const SocketConnecting({this.attempt = 1});

  /// 1 for the first try after a drop, then counting up.
  final int attempt;
}

class SocketFrame extends SocketEvent {
  const SocketFrame(this.frame);
  final pb.Frame frame;
}

class SocketClosed extends SocketEvent {
  const SocketClosed({this.error, this.unauthorized = false, this.retryAt, this.attempts = 0});
  final String? error;
  final bool unauthorized;

  /// When the next try is due; null when it won't retry by itself.
  final DateTime? retryAt;

  /// Tries since the connection was last up.
  final int attempts;
}

typedef ChannelFactory = WebSocketChannel Function(Uri uri);

/// Exponential backoff with jitter: 1 s, 2 s, 4 s… up to [max], each
/// drawn between half and all of that, so clients don't retry in step.
class Backoff {
  Backoff({this.base = const Duration(seconds: 1), this.max = const Duration(seconds: 30), Random? random}) : _random = random ?? Random();

  final Duration base, max;
  final Random _random;
  int attempts = 0;

  Duration next() {
    final cap = min(max.inMilliseconds, base.inMilliseconds * (1 << min(attempts, 20)));
    attempts++;
    return Duration(milliseconds: (cap * (0.5 + _random.nextDouble() * 0.5)).round());
  }

  void reset() => attempts = 0;
}

/// The hub's live push channel. It reconnects on its own with backoff and
/// reports what happens as [SocketEvent]s.
abstract interface class HubSocket {
  Stream<SocketEvent> get events;
  void connect(HubEndpoint endpoint);

  /// Tries again now, even if the current connection looks alive: the
  /// user asked, so a quiet dead socket mustn't stand in the way.
  void retryNow();

  /// Closes the connection and stops reconnecting until [connect] is called again.
  void disconnect();
  void subscribe(String session, Int64 afterSeq);
  void unsubscribe(String session);

  /// Tells the hub whether the app is in the foreground, now and after
  /// every reconnect; the hub backs sessions up while an app is. Coming
  /// back to the foreground checks the connection is still alive.
  void setPresence({required bool active});

  /// The device's network changed (Wi-Fi, mobile data, a VPN): the socket
  /// may be bound to a route that's gone, so connect again.
  void networkChanged();
  Future<void> close();
}

class WebSocketHubSocket implements HubSocket {
  WebSocketHubSocket({
    required this.clientName,
    required this.platform,
    HttpClient? httpClient,
    ChannelFactory? channelFactory,
    Backoff? backoff,
    this.heartbeatEvery = const Duration(seconds: 15),
    this.heartbeatTimeout = const Duration(seconds: 10),
  })  : _factory = channelFactory ??
            ((uri) => IOWebSocketChannel.connect(uri,
                pingInterval: const Duration(seconds: 20), connectTimeout: const Duration(seconds: 10), customClient: httpClient)),
        _backoff = backoff ?? Backoff();

  final String clientName, platform;
  final ChannelFactory _factory;
  final Backoff _backoff;

  /// How often a connected socket proves it's alive, and how long the hub
  /// has to answer before the socket counts as dead.
  final Duration heartbeatEvery, heartbeatTimeout;

  final _events = StreamController<SocketEvent>.broadcast();
  final _rand = Random.secure();

  HubEndpoint? _endpoint;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry, _heartbeat, _deadline;
  bool _closed = false;
  bool _rejected = false;
  int _generation = 0;
  DateTime? _backgroundSince;

  @override
  Stream<SocketEvent> get events => _events.stream;

  bool get _open => _channel != null;

  @override
  void connect(HubEndpoint endpoint) {
    _endpoint = endpoint;
    _rejected = false;
    _backoff.reset();
    _teardown();
    _start();
  }

  @override
  void disconnect() {
    _endpoint = null;
    _teardown();
  }

  @override
  void retryNow() {
    if (_endpoint == null) return;
    _rejected = false;
    _backoff.reset();
    _note('retry now');
    _teardown();
    _start();
  }

  @override
  void networkChanged() {
    if (_endpoint == null || _rejected) return;
    _note('network changed');
    _backoff.reset();
    _teardown();
    _start();
  }

  Future<void> _start() async {
    final endpoint = _endpoint;
    if (endpoint == null || _closed) return;
    final gen = ++_generation;
    _events.add(SocketConnecting(attempt: _backoff.attempts + 1));
    try {
      final ch = _factory(endpoint.ws);
      await ch.ready;
      if (gen != _generation || _closed) {
        ch.sink.close();
        return;
      }
      _channel = ch;
      _sub = ch.stream.listen(
        (data) => _onData(data, gen),
        onDone: () => _onClosed(gen, 'the hub closed the connection'),
        onError: (Object e) => _onClosed(gen, _describe(e)),
      );
      _write(pb.Frame(clientHello: pb.ClientHello(token: endpoint.token, clientName: clientName, platform: platform, appVersion: appVersion)));
      _write(pb.Frame(clientPresence: pb.ClientPresence(active: _active)));
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(heartbeatEvery, (_) => _beat(gen));
    } catch (e) {
      if (gen == _generation) _onClosed(gen, _describe(e));
    }
  }

  /// Asks the hub for an answer; no frame at all within the timeout means
  /// the socket is dead, however open it looks.
  void _beat(int gen) {
    if (gen != _generation || !_open || _deadline != null) return;
    _write(pb.Frame(id: _id(), heartbeat: pb.Heartbeat()));
    _deadline = Timer(heartbeatTimeout, () {
      _deadline = null;
      if (gen == _generation) _onClosed(gen, 'no answer from the hub for ${heartbeatTimeout.inSeconds}s');
    });
  }

  void _onData(dynamic data, int gen) {
    if (gen != _generation) return;
    // Anything from the hub proves the connection is alive.
    _deadline?.cancel();
    _deadline = null;
    final pb.Frame f;
    try {
      f = pb.Frame()..mergeFromProto3Json(jsonDecode(data as String), ignoreUnknownFields: true);
    } catch (_) {
      return;
    }
    if (f.whichBody() == pb.Frame_Body.welcome) _backoff.reset();
    if (f.whichBody() == pb.Frame_Body.error && f.error.code == 'unauthorized') _rejected = true;
    _events.add(SocketFrame(f));
  }

  void _onClosed(int gen, String? error) {
    if (gen != _generation || _closed) return;
    _teardown();
    if (_rejected) {
      _note('rejected: $error');
      _events.add(SocketClosed(error: error, unauthorized: true));
      return;
    }
    final wait = _backoff.next();
    final at = DateTime.now().add(wait);
    _note('closed (attempt ${_backoff.attempts}): $error; retrying in ${wait.inMilliseconds} ms');
    _events.add(SocketClosed(error: error, retryAt: at, attempts: _backoff.attempts));
    _retry = Timer(wait, _start);
  }

  void _teardown() {
    _generation++;
    _retry?.cancel();
    _heartbeat?.cancel();
    _deadline?.cancel();
    _deadline = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _write(pb.Frame f) {
    f.v = 1;
    _channel?.sink.add(jsonEncode(f.toProto3Json()));
  }

  String _id() => List.generate(8, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  @override
  void subscribe(String session, Int64 afterSeq) =>
      _write(pb.Frame(id: _id(), subscribe: pb.Subscribe(session: session, afterSeq: afterSeq)));

  @override
  void unsubscribe(String session) => _write(pb.Frame(id: _id(), unsubscribe: pb.Unsubscribe(session: session)));

  bool _active = true;

  @override
  void setPresence({required bool active}) {
    final was = _active;
    _active = active;
    if (!active) {
      _backgroundSince ??= DateTime.now();
    } else if (!was) {
      final away = DateTime.now().difference(_backgroundSince ?? DateTime.now());
      _backgroundSince = null;
      if (_endpoint != null && !_rejected) {
        if (!_open) {
          // Waiting out a backoff while away: try now.
          _note('resumed after ${away.inSeconds}s; reconnecting');
          _backoff.reset();
          _teardown();
          _start();
          return;
        }
        // Open, but a phone asleep can't trust that: check at once.
        _beat(_generation);
      }
    }
    _write(pb.Frame(clientPresence: pb.ClientPresence(active: active)));
  }

  @override
  Future<void> close() async {
    _closed = true;
    _teardown();
    await _events.close();
  }

  void _note(String what) => debugPrint('tether socket: $what');

  static String _describe(Object e) {
    final s = e.toString();
    return s.length > 200 ? '${s.substring(0, 200)}…' : s;
  }
}
