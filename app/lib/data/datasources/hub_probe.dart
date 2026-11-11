import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';

/// Asks a host for a Tether hub's `GET /api/v1/hello`, which needs no token.
class HttpHubProbe implements HubProbe {
  HttpHubProbe({http.Client? client, this.timeout = const Duration(milliseconds: 1500)}) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<HubHello?> hello(String host, {int port = 7420}) async {
    try {
      final res = await _client.get(Uri(scheme: 'http', host: host, port: port, path: '/api/v1/hello')).timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic> || body['app'] != 'tether-hub') return null;
      return HubHello(version: '${body['version'] ?? ''}', trusted: body['trusted'] == true);
    } on Exception {
      // Nothing there, too slow, or not a hub: all the same to the caller.
      return null;
    }
  }
}
