import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/version.dart';
import '../../gen/tether/v1/tether.pb.dart' as pb;
import 'hub_endpoint.dart';

sealed class SocketEvent {
  const SocketEvent();
}

class SocketConnecting extends SocketEvent {
  const SocketConnecting();
}

class SocketFrame extends SocketEvent {
  const SocketFrame(this.frame);
  final pb.Frame frame;
}

class SocketClosed extends SocketEvent {
  const SocketClosed({this.error, this.unauthorized = false});
  final String? error;
  final bool unauthorized;
}

typedef ChannelFactory = WebSocketChannel Function(Uri uri);

/// The hub's live push channel. It reconnects on its own with backoff and
/// reports what happens as [SocketEvent]s.
abstract interface class HubSocket {
  Stream<SocketEvent> get events;
  void connect(HubEndpoint endpoint);
  void retryNow();

  /// Closes the connection and stops reconnecting until [connect] is called again.
  void disconnect();
  void subscribe(String session, Int64 afterSeq);
  void unsubscribe(String session);
  Future<void> close();
}

class WebSocketHubSocket implements HubSocket {
  WebSocketHubSocket({required this.clientName, required this.platform, HttpClient? httpClient, ChannelFactory? channelFactory})
      : _factory = channelFactory ??
            ((uri) => IOWebSocketChannel.connect(uri,
                pingInterval: const Duration(seconds: 20), connectTimeout: const Duration(seconds: 10), customClient: httpClient));

  final String clientName, platform;
  final ChannelFactory _factory;
  final _events = StreamController<SocketEvent>.broadcast();
  final _rand = Random.secure();

  HubEndpoint? _endpoint;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  Duration _backoff = const Duration(seconds: 1);
  bool _closed = false;
  bool _rejected = false;
  int _generation = 0;

  @override
  Stream<SocketEvent> get events => _events.stream;

  @override
  void connect(HubEndpoint endpoint) {
    _endpoint = endpoint;
    _rejected = false;
    _backoff = const Duration(seconds: 1);
    _teardown();
    _open();
  }

  @override
  void disconnect() {
    _endpoint = null;
    _teardown();
  }

  @override
  void retryNow() {
    if (_endpoint == null || _channel != null) return;
    _rejected = false;
    _retry?.cancel();
    _open();
  }

  Future<void> _open() async {
    final endpoint = _endpoint;
    if (endpoint == null || _closed) return;
    final gen = ++_generation;
    _events.add(const SocketConnecting());
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
        onDone: () => _onClosed(gen, null),
        onError: (Object e) => _onClosed(gen, e.toString()),
      );
      _write(pb.Frame(clientHello: pb.ClientHello(token: endpoint.token, clientName: clientName, platform: platform, appVersion: appVersion)));
    } catch (e) {
      if (gen == _generation) _onClosed(gen, _describe(e));
    }
  }

  void _onData(dynamic data, int gen) {
    if (gen != _generation) return;
    final pb.Frame f;
    try {
      f = pb.Frame()..mergeFromProto3Json(jsonDecode(data as String), ignoreUnknownFields: true);
    } catch (_) {
      return;
    }
    if (f.whichBody() == pb.Frame_Body.welcome) _backoff = const Duration(seconds: 1);
    if (f.whichBody() == pb.Frame_Body.error && f.error.code == 'unauthorized') _rejected = true;
    _events.add(SocketFrame(f));
  }

  void _onClosed(int gen, String? error) {
    if (gen != _generation || _closed) return;
    _teardown();
    _events.add(SocketClosed(error: error, unauthorized: _rejected));
    if (_rejected) return;
    _retry?.cancel();
    _retry = Timer(_backoff, _open);
    _backoff = Duration(seconds: min(_backoff.inSeconds * 2, 30));
  }

  void _teardown() {
    _generation++;
    _retry?.cancel();
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

  @override
  Future<void> close() async {
    _closed = true;
    _teardown();
    await _events.close();
  }

  static String _describe(Object e) {
    final s = e.toString();
    return s.length > 200 ? '${s.substring(0, 200)}…' : s;
  }
}
