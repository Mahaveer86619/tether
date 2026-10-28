import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tether/core/error/failures.dart';
import 'package:tether/core/result.dart';
import 'package:tether/data/datasources/hub_endpoint.dart';
import 'package:tether/data/datasources/hub_rest_api.dart';
import 'package:tether/data/datasources/settings_local.dart';
import 'package:tether/data/datasources/update_platform.dart';
import 'package:tether/data/repositories/update_repository_impl.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/presentation/update/update_cubit.dart';

import '../helpers/fakes.dart';

class _Platform implements UpdatePlatform {
  _Platform(this.dir);
  final Directory dir;
  final installed = <String>[];

  @override
  String? get key => 'android';

  @override
  Future<Directory> downloads() async => dir;

  @override
  Future<void> install(File file) async => installed.add(file.path);

  @override
  Future<void> notify(String title, String body) async {}
}

void main() {
  group('UpdateCubit', () {
    late FakeHubRepository hub;
    late FakeUpdateRepository updates;
    var exited = false;
    UpdateCubit cubit({String current = '0.17.0'}) =>
        UpdateCubit(updates: AppUpdates(updates), watchHub: WatchHub(hub), current: current, exit: () => exited = true);

    setUp(() {
      hub = FakeHubRepository(snapshotWith([]));
      updates = FakeUpdateRepository();
      exited = false;
    });

    test('a newer release the hub announces is offered once, and notified once', () async {
      final c = cubit()..start();
      hub.emitHub(hub.current.copyWith(update: () => release('0.18.0')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.state.stage, UpdateStage.available);
      expect(c.state.release?.version, '0.18.0');
      expect(c.state.forced, isFalse);
      expect(updates.notifications.single, ('Tether 0.18.0 is available', 'Faster chats.'));

      hub.emitHub(hub.current.copyWith(update: () => release('0.18.0')));
      await c.check();
      expect(updates.notifications, hasLength(1), reason: 'the same release is only notified once');
      await c.close();
    });

    test('nothing is offered for the same or an older version', () async {
      updates.release = release('0.17.0');
      final c = cubit();
      await c.check();
      expect(c.state.stage, UpdateStage.none);
      updates.release = release('0.16.2');
      await c.check();
      expect(c.state.stage, UpdateStage.none);
      await c.close();
    });

    test('a skipped release stays hidden; a required one cannot be skipped', () async {
      updates.release = release('0.18.0');
      final c = cubit();
      await c.check();
      await c.skip();
      expect(c.state.stage, UpdateStage.none);
      expect(updates.skippedVersion, '0.18.0');
      await c.check();
      expect(c.state.stage, UpdateStage.none, reason: 'still skipped');

      updates.release = release('0.18.0', minSupported: '0.17.5');
      await c.check();
      expect(c.state.forced, isTrue);
      expect(c.state.stage, UpdateStage.available, reason: 'a required update ignores the skip');
      await c.skip();
      c.later();
      expect(c.state.stage, UpdateStage.available);
      await c.close();
    });

    test('on Android the update downloads, then the installer opens', () async {
      updates.release = release('0.18.0');
      final c = cubit();
      await c.check();
      await c.update();
      expect(updates.installed, ['/tmp/update.bin']);
      expect(c.state.stage, UpdateStage.ready, reason: 'Install stays offered if the installer is cancelled');
      expect(exited, isFalse);
      await c.close();
    });

    test('on Windows it waits for Restart, then the app exits for the helper', () async {
      updates = FakeUpdateRepository(platform: 'windows', release: release('0.18.0'));
      final c = cubit();
      await c.check();
      await c.update();
      expect(c.state.stage, UpdateStage.ready);
      expect(updates.installed, isEmpty);
      await c.install();
      expect(updates.installed, ['/tmp/update.bin']);
      expect(exited, isTrue);
      await c.close();
    });

    test('a failed download says why and can be tried again', () async {
      updates.release = release('0.18.0');
      updates.downloadResult = const Err(ServerFailure('the download does not match its checksum'));
      final c = cubit();
      await c.check();
      await c.update();
      expect(c.state.stage, UpdateStage.failed);
      expect(c.state.failure?.userMessage, contains('checksum'));
      updates.downloadResult = const Ok('/tmp/update.bin');
      await c.update();
      expect(c.state.stage, UpdateStage.ready);
      await c.close();
    });

    test('a platform the app cannot update on offers nothing', () async {
      updates = FakeUpdateRepository(platform: null, release: release('0.18.0'));
      final c = cubit()..start();
      await c.check();
      expect(c.state.stage, UpdateStage.none);
      await c.close();
    });
  });

  group('UpdateRepositoryImpl', () {
    late Directory dir;
    late _Platform platform;
    late List<http.BaseRequest> requests;
    final apk = utf8.encode('the apk');

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('updates');
      platform = _Platform(dir);
      requests = [];
    });
    tearDown(() => dir.delete(recursive: true));

    UpdateRepositoryImpl repo(List<int> body) {
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response.bytes(body, 200);
      });
      final api = HubRestApi(client, clientName: 'test')..endpoint = HubEndpoint('ws://100.64.0.1:7420/ws', 'tok');
      return UpdateRepositoryImpl(api: api, client: client, platform: platform, local: SettingsLocalDataSource());
    }

    test('downloads from the hub with the token, checks the sha256, and reuses an intact file', () async {
      final asset = UpdateAsset(name: 'tether-0.18.0.apk', url: '/api/v1/updates/files/0.18.0/tether-0.18.0.apk', sha256: sha256.convert(apk).toString(), size: apk.length);
      final r = repo(apk);
      final got = await r.download(asset);
      final path = got.valueOrNull!;
      expect(await File(path).readAsBytes(), apk);
      expect(requests.single.url.toString(), 'http://100.64.0.1:7420/api/v1/updates/files/0.18.0/tether-0.18.0.apk');
      expect(requests.single.headers['Authorization'], 'Bearer tok');

      await r.download(asset);
      expect(requests, hasLength(1), reason: 'an intact download is reused');

      await r.install(path);
      expect(platform.installed, [path]);
    });

    test('a download that does not match its sha256 is thrown away', () async {
      final asset = UpdateAsset(name: 'tether-0.18.0.apk', url: 'https://github.com/x/tether-0.18.0.apk', sha256: sha256.convert(apk).toString());
      final got = await repo(utf8.encode('tampered')).download(asset);
      expect(got.failureOrNull?.userMessage, contains('checksum'));
      expect(requests.single.headers.containsKey('Authorization'), isFalse, reason: 'the token only goes to the hub');
      expect(dir.listSync(), isEmpty);
    });
  });
}
