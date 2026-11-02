import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../core/error/exceptions.dart';
import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/hub_rest_api.dart';
import '../datasources/settings_local.dart';
import '../datasources/update_platform.dart';
import '../mappers/hub_mappers.dart';
import 'failure_mapper.dart';

class UpdateRepositoryImpl implements UpdateRepository {
  UpdateRepositoryImpl({required this._api, required this._client, required this._platform, required this._local});

  final HubRestApi _api;
  final http.Client _client;
  final UpdatePlatform _platform;
  final SettingsLocalDataSource _local;

  static const _skippedKey = 'update:skipped';
  static const _notifiedKey = 'update:notified';

  @override
  String? get platform => _platform.key;

  @override
  Future<Result<Release?>> latest() => guard(() async => releaseFromPb(await _api.latestRelease()));

  @override
  Future<Result<String>> download(UpdateAsset asset, {void Function(int received, int total)? onProgress}) => guard(() async {
        final dir = await _platform.downloads();
        final file = File('${dir.path}${Platform.pathSeparator}${asset.name}');
        if (await file.exists() && await _sha256(file) == asset.sha256.toLowerCase()) return file.path;
        // An older download of another release is no longer useful.
        await for (final old in dir.list()) {
          if (old is File && old.path != file.path && !old.path.endsWith('.ps1') && !old.path.endsWith('.log')) await old.delete();
        }
        final part = File('${file.path}.part');
        final req = http.Request('GET', _api.resolve(asset.url));
        if (asset.url.startsWith('/')) req.headers.addAll(_api.authHeaders);
        final http.StreamedResponse res;
        try {
          res = await _client.send(req).timeout(const Duration(seconds: 30));
        } on TimeoutException {
          throw const RequestTimeoutException('the hub took too long to start the download');
        } on SocketException catch (e) {
          throw NetworkException(e.message);
        } on http.ClientException catch (e) {
          throw NetworkException(e.message);
        }
        if (res.statusCode != 200) {
          throw ApiException(statusCode: res.statusCode, code: 'http_${res.statusCode}', message: 'download failed (HTTP ${res.statusCode})');
        }
        final total = res.contentLength ?? asset.size;
        final sink = part.openWrite();
        var received = 0;
        try {
          await for (final chunk in res.stream) {
            sink.add(chunk);
            received += chunk.length;
            onProgress?.call(received, total);
          }
        } on Exception catch (e) {
          await sink.close();
          throw NetworkException('the download broke off: $e');
        }
        await sink.close();
        final sum = await _sha256(part);
        if (sum != asset.sha256.toLowerCase()) {
          await part.delete();
          throw const ProtocolException('the download does not match its checksum, so it was thrown away');
        }
        await part.rename(file.path);
        return file.path;
      });

  @override
  Future<Result<void>> install(String path) => guard(() => _platform.install(File(path)));

  static Future<String> _sha256(File f) async => (await sha256.bind(f.openRead()).first).toString();

  @override
  Future<String> skipped() => _local.readValue(_skippedKey);

  @override
  Future<void> skip(String version) => _local.writeValue(_skippedKey, version);

  @override
  Future<String> notified() => _local.readValue(_notifiedKey);

  @override
  Future<void> setNotified(String version) => _local.writeValue(_notifiedKey, version);

  @override
  Future<void> notify(String title, String body) => _platform.notify(title, body);
}
