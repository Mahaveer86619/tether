import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:http/http.dart' as http;
import 'package:protobuf/protobuf.dart';

import '../../core/error/exceptions.dart';
import '../../gen/tether/v1/tether.pb.dart' as pb;
import '../../gen/tether/v1/tether.pbenum.dart' as pbe;
import 'hub_endpoint.dart';

/// The hub's REST API (request/response). Throws [DataException]s only.
class HubRestApi {
  HubRestApi(this._client, {required this.clientName, this.timeout = const Duration(seconds: 15)});

  final http.Client _client;
  final String clientName;
  final Duration timeout;
  HubEndpoint? endpoint;

  Future<pb.Welcome> fetchState() => _get('/state', pb.Welcome());

  Future<pb.TimelinePage> fetchTimeline(String session, {Int64? after}) =>
      _get('/sessions/${Uri.encodeComponent(session)}/timeline', pb.TimelinePage(),
          query: after == null || after == Int64.ZERO ? null : {'after': '$after'});

  Future<String> createSession(pb.CreateSession body) async => (await _post('/sessions', body, pb.Ack())).session;

  Future<String> sendMessage(String session, String text, {bool fork = false}) async => (await _post(
        '/sessions/${Uri.encodeComponent(session)}/messages',
        pb.SendMessage(text: text, fork: fork),
        pb.Ack(),
      ))
          .session;

  Future<void> interrupt(String session) => _post('/sessions/${Uri.encodeComponent(session)}/interrupt', null, pb.Ack());

  Future<void> stop(String session) => _post('/sessions/${Uri.encodeComponent(session)}/stop', null, pb.Ack());

  Future<void> archive(String session, {required bool archived}) =>
      _post('/sessions/${Uri.encodeComponent(session)}/archive', pb.ArchiveSession(archived: archived), pb.Ack());

  Future<void> decide(String approvalId, {required bool allow, String message = ''}) => _post(
        '/approvals/${Uri.encodeComponent(approvalId)}',
        pb.ApprovalDecision(decision: allow ? pbe.Decision.DECISION_ALLOW : pbe.Decision.DECISION_DENY, message: message),
        pb.Ack(),
      );

  Future<T> _get<T extends GeneratedMessage>(String path, T into, {Map<String, String>? query}) =>
      _send(() => _client.get(_endpoint.api(path, query), headers: _headers), into);

  Future<T> _post<T extends GeneratedMessage>(String path, GeneratedMessage? body, T into) => _send(
        () => _client.post(
          _endpoint.api(path),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: body == null ? '{}' : jsonEncode(body.toProto3Json()),
        ),
        into,
      );

  HubEndpoint get _endpoint => endpoint ?? (throw const NetworkException('hub address is not set'));

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${_endpoint.token}',
        'Accept': 'application/json',
        'X-Tether-Client': clientName,
      };

  Future<T> _send<T extends GeneratedMessage>(Future<http.Response> Function() request, T into) async {
    final http.Response res;
    try {
      res = await request().timeout(timeout);
    } on TimeoutException {
      throw RequestTimeoutException('no answer within ${timeout.inSeconds}s');
    } on SocketException catch (e) {
      throw NetworkException(e.message.isEmpty ? e.toString() : e.message);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on HandshakeException catch (e) {
      throw NetworkException(e.message);
    }

    final Object? json;
    try {
      json = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } on FormatException {
      if (res.statusCode >= 400) {
        throw ApiException(statusCode: res.statusCode, code: 'http_${res.statusCode}', message: res.reasonPhrase ?? 'HTTP ${res.statusCode}');
      }
      throw ProtocolException('response is not JSON (HTTP ${res.statusCode})');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final err = pb.Error();
      try {
        err.mergeFromProto3Json(json, ignoreUnknownFields: true);
      } catch (_) {}
      throw ApiException(
        statusCode: res.statusCode,
        code: err.code.isEmpty ? 'http_${res.statusCode}' : err.code,
        message: err.message.isEmpty ? (res.reasonPhrase ?? 'HTTP ${res.statusCode}') : err.message,
      );
    }
    try {
      return into..mergeFromProto3Json(json, ignoreUnknownFields: true);
    } catch (e) {
      throw ProtocolException('unexpected response shape: $e');
    }
  }
}
