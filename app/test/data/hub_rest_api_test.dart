import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tether/core/error/exceptions.dart';
import 'package:tether/core/error/failures.dart';
import 'package:tether/data/datasources/hub_endpoint.dart';
import 'package:tether/data/datasources/hub_rest_api.dart';
import 'package:tether/data/repositories/failure_mapper.dart';

HubRestApi api(MockClientHandler handler, {Duration timeout = const Duration(seconds: 2)}) =>
    HubRestApi(MockClient(handler), clientName: 'test', timeout: timeout)..endpoint = HubEndpoint('ws://100.64.0.1:7420/ws', 'tok');

void main() {
  test('endpoint derives the REST base from the WebSocket URL', () {
    final e = HubEndpoint('wss://hub.example:8443/ws', 't');
    expect(e.api('/state').toString(), 'https://hub.example:8443/api/v1/state');
    expect(HubEndpoint('ws://1.2.3.4:7420/ws', 't').api('/x', {'after': '5'}).toString(), 'http://1.2.3.4:7420/api/v1/x?after=5');
  });

  test('sends the token and client name, parses the ack', () async {
    late http.Request seen;
    final rest = api((req) async {
      seen = req;
      return http.Response('{"session":"abc"}', 200);
    });
    expect(await rest.sendMessage('s1', 'hello', fork: true), 'abc');
    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/v1/sessions/s1/messages');
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(seen.headers['X-Tether-Client'], 'test');
    expect(jsonDecode(seen.body), {'text': 'hello', 'fork': true});
  });

  test('parses timeline pages with int64 strings', () async {
    final rest = api((_) async => http.Response(
          '{"session":"s1","seq":"42","items":[{"itemId":"a","ord":"1","user":{"text":"hi"}}]}',
          200,
        ));
    final page = await rest.fetchTimeline('s1');
    expect(page.seq.toInt(), 42);
    expect(page.items.single.user.text, 'hi');
  });

  group('errors become typed exceptions, then failures', () {
    Future<Object> errorOf(MockClientHandler h, {Duration timeout = const Duration(seconds: 2)}) async {
      try {
        await api(h, timeout: timeout).interrupt('s1');
      } catch (e) {
        return e;
      }
      fail('expected an exception');
    }

    test('hub error bodies keep their code', () async {
      final e = await errorOf((_) async => http.Response('{"code":"terminal_active","message":"open in a terminal"}', 409));
      expect(e, isA<ApiException>().having((x) => x.code, 'code', 'terminal_active').having((x) => x.statusCode, 'status', 409));
      expect(failureFrom(e), isA<TerminalActiveFailure>());
    });

    test('401 without a body is unauthorized', () async {
      final e = await errorOf((_) async => http.Response('', 401));
      expect(failureFrom(e), isA<UnauthorizedFailure>());
    });

    test('503 node offline', () async {
      final e = await errorOf((_) async => http.Response('{"code":"node_offline","message":"node is not connected"}', 503));
      expect(failureFrom(e), isA<NodeOfflineFailure>());
    });

    test('HTML error pages from proxies are not protocol errors', () async {
      final e = await errorOf((_) async => http.Response('<html>bad gateway</html>', 502, reasonPhrase: 'Bad Gateway'));
      expect(e, isA<ApiException>().having((x) => x.statusCode, 'status', 502));
      expect(failureFrom(e), isA<ServerFailure>());
    });

    test('garbage on success is a protocol error', () async {
      final e = await errorOf((_) async => http.Response('not json', 200));
      expect(e, isA<ProtocolException>());
    });

    test('unreachable hub is a network failure', () async {
      final e = await errorOf((_) async => throw const SocketException('Connection refused'));
      expect(failureFrom(e), isA<NetworkFailure>());
    });

    test('slow hub is a timeout failure', () async {
      final e = await errorOf((_) => Completer<http.Response>().future, timeout: const Duration(milliseconds: 50));
      expect(failureFrom(e), isA<TimeoutFailure>());
    });
  });

  test('no endpoint is a network exception, not a crash', () async {
    final rest = HubRestApi(MockClient((_) async => http.Response('{}', 200)), clientName: 't');
    expect(rest.fetchState(), throwsA(isA<NetworkException>()));
  });
}
