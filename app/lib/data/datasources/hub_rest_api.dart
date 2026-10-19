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
import 'hub_tls.dart';

/// The hub's REST API (request/response). Throws [DataException]s only.
class HubRestApi {
  HubRestApi(this._client, {required this.clientName, this._tls, this.timeout = const Duration(seconds: 15)});

  final http.Client _client;
  final String clientName;
  final Duration timeout;
  final HubTls? _tls;
  HubEndpoint? _current;

  HubEndpoint? get endpoint => _current;
  set endpoint(HubEndpoint? e) {
    _current = e;
    if (e != null) _tls?.fingerprint = e.fingerprint;
  }

  Future<pb.Welcome> fetchState() => _get('/state', pb.Welcome());

  Future<pb.TimelinePage> fetchTimeline(String session, {Int64? after}) =>
      _get('/sessions/${Uri.encodeComponent(session)}/timeline', pb.TimelinePage(),
          query: after == null || after == Int64.ZERO ? null : {'after': '$after'});

  Future<String> createSession(pb.CreateSession body) async => (await _post('/sessions', body, pb.Ack())).session;

  Future<String> sendMessage(String session, String text, {bool fork = false, List<String> attachments = const [], String clientId = ''}) async => (await _post(
        '/sessions/${Uri.encodeComponent(session)}/messages',
        pb.SendMessage(text: text, fork: fork, attachments: attachments, clientId: clientId.isEmpty ? null : clientId),
        pb.Ack(),
      ))
          .session;

  Future<void> setGlobal(String session, {required bool global}) =>
      _post('/sessions/${Uri.encodeComponent(session)}/global', pb.SetGlobal(global: global), pb.Ack());

  Future<String> continueOnHub(String session, String text) async =>
      (await _post('/sessions/${Uri.encodeComponent(session)}/continue', pb.SendMessage(text: text), pb.Ack())).session;

  Future<pb.ArtifactList> artifacts({String session = '', int limit = 300}) =>
      _get('/artifacts', pb.ArtifactList(), query: {if (session.isNotEmpty) 'session': session, 'limit': '$limit'});

  /// Starts a resumable upload (see docs/plan.md#large-files).
  Future<pb.Upload> startUpload({
    required String name,
    required int size,
    required String sha256,
    String session = '',
    String origin = 'upload',
    String note = '',
    bool deliver = false,
  }) =>
      _send(
        () => _client.post(
          _endpoint.api('/uploads'),
          headers: {
            ..._headers,
            'Content-Type': 'application/octet-stream',
            'X-Name': Uri.encodeComponent(name),
            'X-Size': '$size',
            'X-Sha256': sha256,
            if (session.isNotEmpty) 'X-Session': session,
            'X-Origin': origin,
            if (note.isNotEmpty) 'X-Note': Uri.encodeComponent(note),
            if (deliver) 'X-Deliver': '1',
          },
        ),
        pb.Upload(),
      );

  Future<pb.Upload> uploadStatus(String id) => _get('/uploads/${Uri.encodeComponent(id)}', pb.Upload());

  /// Sends [chunk] at [offset]. The last chunk's answer carries the artifact.
  Future<pb.Upload> appendUpload(String id, int offset, List<int> chunk) => _send(
        () => _client.patch(
          _endpoint.api('/uploads/${Uri.encodeComponent(id)}'),
          headers: {..._headers, 'Content-Type': 'application/offset+octet-stream', 'Upload-Offset': '$offset'},
          body: chunk,
        ),
        pb.Upload(),
        // A chunk over a slow phone connection, plus hashing the whole file
        // on the hub after the last one.
        timeout: const Duration(minutes: 10),
      );

  Future<void> cancelUpload(String id) =>
      _send(() => _client.delete(_endpoint.api('/uploads/${Uri.encodeComponent(id)}'), headers: _headers), pb.Ack());

  Uri artifactContentUrl(String id) => _endpoint.api('/artifacts/${Uri.encodeComponent(id)}/content');

  /// Headers for requests made outside this client, e.g. background downloads.
  Map<String, String> get authHeaders => {'Authorization': 'Bearer ${_endpoint.token}', 'X-Tether-Client': clientName};

  /// Whether the hub uses a pinned self-signed certificate, which only this
  /// client knows how to check.
  bool get pinnedCertificate => (_current?.fingerprint ?? '').isNotEmpty;

  /// The file's bytes. Not protobuf, so it skips [_send]'s decoding.
  Future<List<int>> artifactBytes(String id) async {
    try {
      final res = await _client.get(_endpoint.api('/artifacts/${Uri.encodeComponent(id)}/content'), headers: _headers).timeout(const Duration(minutes: 2));
      if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, code: 'artifact', message: 'could not fetch the file (${res.statusCode})');
      return res.bodyBytes;
    } on TimeoutException {
      throw const RequestTimeoutException('the file took too long to download');
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  /// A link to the file that works without a token until it expires.
  Future<String> artifactLink(String id, {Duration ttl = const Duration(hours: 1)}) async {
    final link = await _send(
      () => _client.post(_endpoint.api('/artifacts/${Uri.encodeComponent(id)}/link', {'ttl': '${ttl.inSeconds}'}), headers: _headers, body: '{}'),
      pb.ArtifactLink(),
    );
    return _endpoint.httpBase.resolve(link.url).toString();
  }

  /// Pages with links resolved against the hub, so they open in a browser.
  Future<List<pb.Page>> pages({String session = ''}) async {
    final list = await _get('/pages', pb.PageList(), query: {if (session.isNotEmpty) 'session': session});
    return [for (final p in list.pages) p..url = _endpoint.httpBase.resolve(p.url).toString()];
  }

  Future<void> deleteArtifact(String id) =>
      _send(() => _client.delete(_endpoint.api('/artifacts/${Uri.encodeComponent(id)}'), headers: _headers), pb.Ack());

  Future<void> interrupt(String session) => _post('/sessions/${Uri.encodeComponent(session)}/interrupt', null, pb.Ack());

  Future<void> stop(String session) => _post('/sessions/${Uri.encodeComponent(session)}/stop', null, pb.Ack());

  Future<void> savePreferences(pb.Preferences p) =>
      _send(() => _client.put(_endpoint.api('/preferences'), headers: {..._headers, 'Content-Type': 'application/json'}, body: jsonEncode(p.toProto3Json())), pb.Ack());

  Future<pb.Tailnet> tailnet() => _get('/tailnet', pb.Tailnet());

  Future<pb.CodebaseList> codebases() => _get('/codebases', pb.CodebaseList());

  Future<void> snapshotCodebase(String id) => _post('/codebases/${Uri.encodeComponent(id)}/snapshot', null, pb.Ack());

  Future<pb.Workspaces> workspaces() => _get('/workspaces', pb.Workspaces());

  Future<pb.Workspaces> setWorkspaceRoot(pb.WorkspaceRoot root, {required bool remove}) => _send(
        () => (remove ? _client.delete : _client.put)(
          _endpoint.api('/workspaces'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(root.toProto3Json()),
        ),
        pb.Workspaces(),
      );

  Future<pb.UsageSummary> usage() => _get('/usage', pb.UsageSummary());


  Future<pb.PairingCode> createPairingCode() => _post('/pairing-codes', null, pb.PairingCode());

  Future<pb.DeviceList> devices() => _get('/devices', pb.DeviceList());

  Future<void> revokeDevice(String id) =>
      _send(() => _client.delete(_endpoint.api('/devices/${Uri.encodeComponent(id)}'), headers: _headers), pb.Ack());

  /// Trades a pairing code for this device's token. It needs no token, so it
  /// takes the hub's address (and certificate fingerprint) directly.
  Future<pb.PairResult> pair(String wsUrl, String fingerprint, pb.PairRequest body) {
    _tls?.fingerprint = fingerprint;
    return _send(
      () => _client.post(
        HubEndpoint(wsUrl, '').api('/pair'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'X-Tether-Client': clientName},
        body: jsonEncode(body.toProto3Json()),
      ),
      pb.PairResult(),
    );
  }

  Future<void> archive(String session, {required bool archived}) =>
      _post('/sessions/${Uri.encodeComponent(session)}/archive', pb.ArchiveSession(archived: archived), pb.Ack());

  Future<pb.ScreenSnapshot> screen(String session) =>
      _send(() => _client.get(_endpoint.api('/sessions/${Uri.encodeComponent(session)}/screen'), headers: _headers), pb.ScreenSnapshot(),
          timeout: const Duration(seconds: 20));

  Future<void> sendKeys(String session, List<String> keys, {String text = ''}) =>
      _post('/sessions/${Uri.encodeComponent(session)}/keys', pb.SendKeys(keys: keys, text: text), pb.Ack());

  Future<void> decide(String approvalId, {required bool allow, String message = '', Map<String, String> answers = const {}, int option = 0}) => _post(
        '/approvals/${Uri.encodeComponent(approvalId)}',
        pb.ApprovalDecision(
            decision: allow ? pbe.Decision.DECISION_ALLOW : pbe.Decision.DECISION_DENY, message: message, answers: answers.entries, option: option),
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

  HubEndpoint get _endpoint => _current ?? (throw const NetworkException('hub address is not set'));

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${_endpoint.token}',
        'Accept': 'application/json',
        'X-Tether-Client': clientName,
      };

  Future<T> _send<T extends GeneratedMessage>(Future<http.Response> Function() request, T into, {Duration? timeout}) async {
    final limit = timeout ?? this.timeout;
    final http.Response res;
    try {
      res = await request().timeout(limit);
    } on TimeoutException {
      throw RequestTimeoutException('no answer within ${limit.inSeconds}s');
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
