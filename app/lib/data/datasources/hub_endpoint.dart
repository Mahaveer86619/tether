/// Where the hub is and how to authenticate. One hub address serves both
/// the WebSocket (`ws://host:7420/ws`) and the REST API (`http://host:7420`).
class HubEndpoint {
  HubEndpoint(String wsUrl, this.token, {this.fingerprint = ''}) : ws = Uri.parse(wsUrl);

  final Uri ws;
  final String token;

  /// The hub's pinned self-signed certificate, if it uses one.
  final String fingerprint;

  Uri get httpBase => ws.replace(scheme: ws.scheme == 'wss' ? 'https' : 'http', path: '');

  Uri api(String path, [Map<String, String>? query]) =>
      httpBase.replace(path: '/api/v1$path', queryParameters: query == null || query.isEmpty ? null : query);
}
