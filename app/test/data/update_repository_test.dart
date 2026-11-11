import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tether/core/version.dart';
import 'package:tether/data/datasources/hub_endpoint.dart';
import 'package:tether/data/datasources/hub_rest_api.dart';
import 'package:tether/data/datasources/settings_local.dart';
import 'package:tether/data/datasources/update_platform.dart';
import 'package:tether/data/repositories/update_repository_impl.dart';

class _Platform implements UpdatePlatform {
  @override
  String? get key => 'android';
  @override
  Future<Directory> downloads() async => Directory.systemTemp;
  @override
  Future<void> install(File file) async {}
  @override
  Future<void> notify(String title, String body) async {}
}

String _manifest(String version, {String url = 'https://github.com/Mahaveer86619/tether/releases/download/v0.18.0/tether-0.18.0.apk'}) => jsonEncode({
      'version': version,
      'notes': 'notes',
      'published': '2026-11-09T00:00:00Z',
      'min_supported': '0.15.0',
      'platforms': {'android': {'name': 'tether-$version.apk', 'url': url, 'sha256': 'ab' * 32, 'size': 10}},
    });

void main() {
  // GitHub and the hub are told apart by their address.
  UpdateRepositoryImpl repo({String? github, String? hub}) {
    final client = MockClient((req) async {
      if (req.url.toString() == releaseFeedUrl) return github == null ? http.Response('nope', 503) : http.Response(github, 200);
      if (req.url.path.endsWith('/updates/latest')) return hub == null ? http.Response('{"code":"x"}', 500) : http.Response(hub, 200, headers: {'content-type': 'application/json'});
      return http.Response('', 404);
    });
    final api = HubRestApi(client, clientName: 'test')..endpoint = HubEndpoint('ws://100.64.0.2:7420/ws', 'token');
    return UpdateRepositoryImpl(api: api, client: client, platform: _Platform(), local: SettingsLocalDataSource());
  }

  test('a release on GitHub is found without the hub', () async {
    final r = await repo(github: _manifest('0.18.0')).latest();
    expect(r.valueOrNull?.version, '0.18.0');
    expect(r.valueOrNull?.assets['android']?.url, startsWith('https://github.com/'));
  });

  test('the hub is the fallback when GitHub does not answer', () async {
    final r = await repo(hub: _manifest('0.17.9', url: '/api/v1/updates/files/0.17.9/tether-0.17.9.apk')).latest();
    expect(r.valueOrNull?.version, '0.17.9');
  });

  test('the newer of the two wins, and GitHub wins a tie', () async {
    var r = await repo(github: _manifest('0.18.0'), hub: _manifest('0.18.1', url: '/api/v1/updates/files/0.18.1/tether-0.18.1.apk')).latest();
    expect(r.valueOrNull?.version, '0.18.1', reason: 'a build only the hub has, made on the owner\'s machine');
    r = await repo(github: _manifest('0.18.1'), hub: _manifest('0.18.0', url: '/api/v1/updates/files/0.18.0/tether-0.18.0.apk')).latest();
    expect(r.valueOrNull?.version, '0.18.1');
    r = await repo(github: _manifest('0.18.0'), hub: _manifest('0.18.0', url: '/api/v1/updates/files/0.18.0/tether-0.18.0.apk')).latest();
    expect(r.valueOrNull?.assets['android']?.url, startsWith('https://github.com/'), reason: 'a tie goes to GitHub, which needs no hub');
  });

  test('neither answering is an error, and a feed that is not a release is ignored', () async {
    expect((await repo().latest()).failureOrNull, isNotNull);
    final r = await repo(github: '<html>not json</html>', hub: _manifest('0.17.9')).latest();
    expect(r.valueOrNull?.version, '0.17.9');
  });
}
