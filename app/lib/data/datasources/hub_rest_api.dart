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

  Future<pb.UpdateManifest> latestRelease() => _get('/updates/latest', pb.UpdateManifest());

  /// A full URL for a path on the hub, or [url] itself if it's already one.
  Uri resolve(String url) => url.startsWith('/') ? _endpoint.httpBase.replace(path: Uri.parse(url).path) : Uri.parse(url);

  Future<pb.Chat> createChat(pb.CreateChat body, {String project = ''}) => _post('/chats', body, pb.Chat(), query: project.isEmpty ? null : {'project': project});

  Future<void> deleteChat(String chat) =>
      _send(() => _client.delete(_endpoint.api('/chats/${Uri.encodeComponent(chat)}'), headers: _headers), pb.Ack());

  Future<pb.Chat> updateChat(String chat, pb.UpdateChat body) => _send(
        () => _client.patch(
          _endpoint.api('/chats/${Uri.encodeComponent(chat)}'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body.toProto3Json()),
        ),
        pb.Chat(),
      );

  Future<String> sendToChat(String chat, String text, {List<String> attachments = const [], String clientId = ''}) async => (await _post(
        '/chats/${Uri.encodeComponent(chat)}/messages',
        pb.SendMessage(text: text, attachments: attachments, clientId: clientId.isEmpty ? null : clientId),
        pb.Ack(),
      ))
          .session;

  Future<pb.Chat> setChatTarget(String chat, pb.SetChatTarget body) => _post('/chats/${Uri.encodeComponent(chat)}/target', body, pb.Chat());

  Future<pb.Chat> linkSession(String chat, pb.LinkSession body) => _post('/chats/${Uri.encodeComponent(chat)}/links', body, pb.Chat());

  Future<pb.ChatContext> chatContext(String chat) => _get('/chats/${Uri.encodeComponent(chat)}/context', pb.ChatContext());

  Future<pb.TargetSuggestions> targetSuggestions(String prompt) =>
      _get('/targets', pb.TargetSuggestions(), query: prompt.isEmpty ? null : {'prompt': prompt});

  Future<pb.ArtifactList> artifacts({String session = '', int limit = 300}) =>
      _get('/artifacts', pb.ArtifactList(), query: {if (session.isNotEmpty) 'session': session, 'limit': '$limit'});

  /// Starts a resumable upload (see docs/plans/plan.md#large-files).
  Future<pb.Upload> startUpload({
    required String name,
    required int size,
    required String sha256,
    String uploadId = '',
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
            if (uploadId.isNotEmpty) 'X-Upload-Id': uploadId,
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

  Future<pb.ClientList> clients() => _get('/clients', pb.ClientList());

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

  Future<pb.JobList> jobs() => _get('/jobs', pb.JobList());

  Future<pb.Job> startJob(pb.JobSpec spec) => _post('/jobs', spec, pb.Job());

  Future<void> jobAction(String job, String action) => _post('/jobs/${Uri.encodeComponent(job)}/$action', null, pb.Job());

  Future<void> forgetJob(String job) => _send(() => _client.delete(_endpoint.api('/jobs/${Uri.encodeComponent(job)}'), headers: _headers), pb.Ack());

  Future<pb.JobLogTail> jobLogs(String job, {int tail = 200}) =>
      _get('/jobs/${Uri.encodeComponent(job)}/logs', pb.JobLogTail(), query: {'tail': '$tail'});

  /// The skills library: proposals waiting for approval and approved skills.
  Future<Map<String, dynamic>> skills() => _jsonMap(() => _client.get(_endpoint.api('/skills'), headers: _headers));

  /// One skill with the text of every version.
  Future<Map<String, dynamic>> skill(String name) =>
      _jsonMap(() => _client.get(_endpoint.api('/skills/${Uri.encodeComponent(name)}'), headers: _headers));

  /// An owner's decision on a skill: `approve`, `dismiss` or `rollback` (with a body).
  Future<Map<String, dynamic>> skillAction(String name, String action, {Map<String, Object?> body = const {}}) => _jsonMap(
        () => _client.post(
          _endpoint.api('/skills/${Uri.encodeComponent(name)}/$action'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      );

  /// Starts a session that drafts a skill for the routine; returns its id.
  Future<String> draftSkill(String example) async {
    final json = await _jsonMap(
      () => _client.post(_endpoint.api('/skills/draft'), headers: {..._headers, 'Content-Type': 'application/json'}, body: jsonEncode({'example': example})),
    );
    return json['session'] as String? ?? '';
  }

  /// A chat's remote setup; plain JSON.
  Future<Map<String, dynamic>> chatRemote(String chat) =>
      _jsonMap(() => _client.get(_endpoint.api('/chats/${Uri.encodeComponent(chat)}/remote'), headers: _headers));

  Future<void> setChatRemote(String chat, Map<String, Object?> body) => _jsonMap(
        () => _client.post(
          _endpoint.api('/chats/${Uri.encodeComponent(chat)}/remote'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      );

  /// The recap, context estimate, rules and rewind points of a chat; plain JSON.
  Future<Map<String, dynamic>> chatDesk(String chat) =>
      _jsonMap(() => _client.get(_endpoint.api('/chats/${Uri.encodeComponent(chat)}/desk'), headers: _headers));

  Future<Map<String, dynamic>> setChatDesk(String chat, Map<String, Object?> body) => _jsonMap(
        () => _client.put(
          _endpoint.api('/chats/${Uri.encodeComponent(chat)}/desk'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      );

  Future<Map<String, dynamic>> rewindChat(String chat, Map<String, Object?> body) => _jsonMap(
        () => _client.post(
          _endpoint.api('/chats/${Uri.encodeComponent(chat)}/rewind'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      );

  Future<Map<String, dynamic>> handoffChat(String chat, Map<String, Object?> body) => _jsonMap(
        () => _client.post(
          _endpoint.api('/chats/${Uri.encodeComponent(chat)}/handoff'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      );

  Future<Map<String, dynamic>> projectFiles(String repo) =>
      _jsonMap(() => _client.get(_endpoint.api('/projects/${Uri.encodeComponent(repo)}/files'), headers: _headers));

  Future<void> putProjectFile(String repo, String path, String content) => _jsonMap(
        () => _client.put(
          _endpoint.api('/projects/${Uri.encodeComponent(repo)}/files'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'path': path, 'content': content}),
        ),
      );

  Future<void> deleteProjectFile(String repo, String path) => _jsonMap(
        () => _client.delete(_endpoint.api('/projects/${Uri.encodeComponent(repo)}/files', {'path': path}), headers: _headers),
      );

  /// Projects with the ids of their chats; plain JSON, see docs/architecture/chats.md#projects.
  Future<Map<String, dynamic>> projects() => _jsonMap(() => _client.get(_endpoint.api('/projects'), headers: _headers));

  Future<Map<String, dynamic>> createProject(Map<String, Object?> body) => _jsonMap(
        () => _client.post(_endpoint.api('/projects'), headers: {..._headers, 'Content-Type': 'application/json'}, body: jsonEncode(body)),
      );

  Future<Map<String, dynamic>> addProjectFolder(String project, String node, String cwd) => _jsonMap(
        () => _client.post(
          _endpoint.api('/projects/${Uri.encodeComponent(project)}/folders'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'node': node, 'cwd': cwd}),
        ),
      );

  Future<void> setChatProject(String chat, String project) => _jsonMap(
        () => _client.put(
          _endpoint.api('/chats/${Uri.encodeComponent(chat)}/project'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'project': project}),
        ),
      );
  /// A plain JSON request (not a protobuf message) for the hub's JSON routes.
  Future<Map<String, dynamic>> plainJson(String method, String path, {Map<String, String>? query, Object? body}) => _jsonMap(() {
        final uri = _endpoint.api(path, query);
        final headers = {..._headers, if (body != null) 'Content-Type': 'application/json'};
        final encoded = body == null ? null : jsonEncode(body);
        return switch (method) {
          'GET' => _client.get(uri, headers: headers),
          'POST' => _client.post(uri, headers: headers, body: encoded ?? '{}'),
          'PUT' => _client.put(uri, headers: headers, body: encoded),
          'DELETE' => _client.delete(uri, headers: headers),
          _ => throw ArgumentError.value(method, 'method'),
        };
      });

  Future<Map<String, dynamic>> _jsonMap(Future<http.Response> Function() request) async {
    final json = await _sendJson(request);
    if (json is! Map<String, dynamic>) throw const ProtocolException('unexpected response shape');
    return json;
  }

  /// The routines found in the hub's history (see docs/plans/skills.md). Plain JSON,
  /// not a protobuf message.
  Future<Map<String, dynamic>> routines({required int days, required int runs}) async {
    final json = await _sendJson(() => _client.get(_endpoint.api('/skills/candidates', {'days': '$days', 'runs': '$runs'}), headers: _headers));
    if (json is! Map<String, dynamic>) throw const ProtocolException('unexpected response shape: routines');
    return json;
  }


  /// A token for [label]'s install that opens only the notifications (plain JSON).
  Future<Map<String, dynamic>> notifyToken(String label) => _jsonMap(() => _client.post(
        _endpoint.api('/notify-token'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'label': label}),
      ));

  Future<void> notifyTest() => _jsonMap(() => _client.post(_endpoint.api('/notifications/test'), headers: _headers));

  Future<pb.PairingCode> createPairingCode() => _post('/pairing-codes', null, pb.PairingCode());

  Future<pb.DeviceList> devices() => _get('/devices', pb.DeviceList());

  Future<void> revokeDevice(String id) =>
      _send(() => _client.delete(_endpoint.api('/devices/${Uri.encodeComponent(id)}'), headers: _headers), pb.Ack());

  Future<pb.UserList> users() => _get('/users', pb.UserList());

  /// A one-time code a new teammate joins with; admins only.
  Future<pb.PairingCode> createTeamInvite() => _post('/invites', null, pb.PairingCode());

  Future<void> removeUser(String id) =>
      _send(() => _client.delete(_endpoint.api('/users/${Uri.encodeComponent(id)}'), headers: _headers), pb.Ack());

  Future<void> shareDevice(String node, String user, String access) => _send(
        () => _client.put(
          _endpoint.api('/nodes/${Uri.encodeComponent(node)}/grants'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(pb.DeviceGrant(user: user, access: access).toProto3Json()),
        ),
        pb.Ack(),
      );

  Future<void> unshareDevice(String node, String user) => _send(
      () => _client.delete(_endpoint.api('/nodes/${Uri.encodeComponent(node)}/grants/${Uri.encodeComponent(user)}'), headers: _headers), pb.Ack());

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

  Future<void> setMode(String session, String mode, {Duration? revertAfter}) => _post(
        '/sessions/${Uri.encodeComponent(session)}/mode',
        pb.SetPermissionMode(mode: mode, revertAfterMs: revertAfter == null ? null : Int64(revertAfter.inMilliseconds)),
        pb.Ack(),
      );

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

  Future<T> _post<T extends GeneratedMessage>(String path, GeneratedMessage? body, T into, {Map<String, String>? query}) => _send(
        () => _client.post(
          _endpoint.api(path, query),
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
    final json = await _sendJson(request, timeout: timeout);
    try {
      return into..mergeFromProto3Json(json, ignoreUnknownFields: true);
    } catch (e) {
      throw ProtocolException('unexpected response shape: $e');
    }
  }

  /// The decoded JSON of a successful answer; failures become exceptions.
  Future<Object?> _sendJson(Future<http.Response> Function() request, {Duration? timeout}) async {
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
      // The hub sends JSON without a charset, which package:http would read as Latin-1.
      json = res.bodyBytes.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(res.bodyBytes));
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
    return json;
  }
}
