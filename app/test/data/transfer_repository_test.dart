import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tether/data/datasources/file_downloads.dart';
import 'package:tether/data/datasources/hub_endpoint.dart';
import 'package:tether/data/datasources/hub_rest_api.dart';
import 'package:tether/data/repositories/transfer_repository_impl.dart';
import 'package:tether/domain/entities/entities.dart';

/// The hub's upload endpoints, in memory, dropping one chunk halfway.
class FakeUploadHub {
  final received = BytesBuilder();
  int size = 0;
  String sha = '';
  String note = '';
  bool deliver = false;
  int patches = 0;

  /// Which PATCH loses its connection halfway, if any.
  int dropPatch = 0;

  /// Record a hash the content won't match.
  bool wrongSha = false;

  http.Client get client => MockClient((r) async {
        final path = r.url.path;
        if (r.method == 'POST' && path == '/api/v1/uploads') {
          size = int.parse(r.headers['X-Size']!);
          sha = wrongSha ? '0' * 64 : r.headers['X-Sha256']!;
          note = Uri.decodeComponent(r.headers['X-Note'] ?? '');
          deliver = r.headers['X-Deliver'] == '1';
          return http.Response(jsonEncode({'id': 'u1', 'offset': '0', 'size': '$size'}), 200);
        }
        if (r.method == 'GET' && path == '/api/v1/uploads/u1') {
          return http.Response(jsonEncode({'id': 'u1', 'offset': '${received.length}', 'size': '$size'}), 200);
        }
        if (r.method == 'PATCH' && path == '/api/v1/uploads/u1') {
          patches++;
          final off = int.parse(r.headers['Upload-Offset']!);
          if (off != received.length) return http.Response(jsonEncode({'code': 'offset', 'message': 'wrong offset'}), 409);
          if (patches == dropPatch) {
            received.add(r.bodyBytes.sublist(0, r.bodyBytes.length ~/ 2));
            throw http.ClientException('connection reset');
          }
          received.add(r.bodyBytes);
          if (received.length < size) return http.Response(jsonEncode({'id': 'u1', 'offset': '${received.length}', 'size': '$size'}), 200);
          final got = sha256.convert(received.toBytes()).toString();
          if (got != sha) return http.Response(jsonEncode({'code': 'checksum', 'message': 'mismatch'}), 422);
          return http.Response(
            jsonEncode({
              'id': 'u1',
              'offset': '$size',
              'size': '$size',
              'artifact': {'id': 'a1', 'name': 'data.csv', 'size': '$size', 'sha256': got, 'session': 's1', 'origin': 'attachment', 'note': note},
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });
}

class FakeDownloads implements FileDownloads {
  final _events = StreamController<DownloadEvent>.broadcast();
  final paths = <String, String>{};
  final saved = <String>[];
  final enqueued = <(String, Uri, Map<String, String>, String)>[];

  void emit(DownloadEvent e) => _events.add(e);

  @override
  Stream<DownloadEvent> get events => _events.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> enqueue({required String id, required Uri url, required Map<String, String> headers, required String name, String meta = ''}) async =>
      enqueued.add((id, url, headers, meta));

  @override
  Future<void> pause(String id) async => emit(DownloadEvent(id, status: DownloadStatus.paused));

  @override
  Future<void> resume(String id) async => emit(DownloadEvent(id, status: DownloadStatus.running));

  @override
  Future<void> cancel(String id) async => emit(DownloadEvent(id, status: DownloadStatus.canceled));

  @override
  Future<String> pathOf(String id) async => paths[id]!;

  @override
  Future<String> saveToDevice(String id, {String mime = ''}) async {
    saved.add(id);
    return 'Download/Tether/$id.csv';
  }
}

Future<void> until(bool Function() ok) async {
  for (var i = 0; i < 200 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(ok(), isTrue);
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('transfers'));
  tearDown(() async => dir.delete(recursive: true));

  HubRestApi api(http.Client client) => HubRestApi(client, clientName: 'test')..endpoint = HubEndpoint('ws://hub:7420/ws', 'tok');

  test('an upload is sent in chunks from disk and resumes where the hub got to', () async {
    final data = List<int>.generate(10 * 1000 + 7, (i) => i * 31 % 251);
    final file = File('${dir.path}/data.csv')..writeAsBytesSync(data);
    // The second chunk is cut off halfway.
    final hub = FakeUploadHub()..dropPatch = 2;
    final repo = TransferRepositoryImpl(api: api(hub.client), downloads: FakeDownloads(), chunkSize: 4000, retryDelay: Duration.zero);
    final result = await repo.upload(LocalFile(path: file.path, name: 'data.csv', size: data.length), session: 's1', note: 'q3 numbers', deliver: true);

    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    expect(hub.received.toBytes(), data);
    expect(hub.sha, sha256.convert(data).toString());
    expect(hub.note, 'q3 numbers');
    expect(hub.deliver, isTrue);
    final a = result.valueOrNull!;
    expect(a.id, 'a1');
    expect(a.note, 'q3 numbers');
    expect(repo.current.values.single.state, TransferState.done);
    expect(repo.current.values.single.bytes, data.length);
    expect(hub.patches, 4, reason: 'three chunks plus the one resent after the drop');
    await repo.dispose();
  });

  test('an upload the hub rejects as corrupt fails without retrying', () async {
    final file = File('${dir.path}/x.bin')..writeAsBytesSync([1, 2, 3]);
    final hub = FakeUploadHub()..wrongSha = true;
    final repo = TransferRepositoryImpl(api: api(hub.client), downloads: FakeDownloads(), retryDelay: Duration.zero);
    final result = await repo.upload(LocalFile(path: file.path, name: 'x.bin', size: 3));
    expect(result.isOk, isFalse);
    expect(hub.patches, 1);
    expect(repo.current.values.single.state, TransferState.failed);
    await repo.dispose();
  });

  test('a finished download is checked against its sha256 before it is saved', () async {
    final data = utf8.encode('a,b\n1,2\n');
    final good = File('${dir.path}/good.csv')..writeAsBytesSync(data);
    final bad = File('${dir.path}/bad.csv')..writeAsBytesSync(utf8.encode('tampered'));
    final downloads = FakeDownloads()
      ..paths['a1'] = good.path
      ..paths['a2'] = bad.path;
    final repo = TransferRepositoryImpl(api: api(MockClient((_) async => http.Response('{}', 200))), downloads: downloads);
    final sha = sha256.convert(data).toString();

    await repo.download(Artifact(id: 'a1', name: 'good.csv', size: data.length, sha256: sha, mime: 'text/csv'));
    expect(downloads.enqueued.single.$2.path, '/api/v1/artifacts/a1/content');
    expect(downloads.enqueued.single.$3['Authorization'], 'Bearer tok');
    downloads.emit(DownloadEvent('a1', progress: 0.5, total: data.length, speed: 1000));
    await until(() => repo.current['a1']!.bytes == data.length ~/ 2);
    downloads.emit(DownloadEvent('a1', status: DownloadStatus.paused));
    await until(() => repo.current['a1']!.state == TransferState.paused);
    downloads.emit(DownloadEvent('a1', status: DownloadStatus.complete));
    await until(() => repo.current['a1']!.state == TransferState.done);
    expect(repo.current['a1']!.savedTo, 'Download/Tether/a1.csv');

    await repo.download(Artifact(id: 'a2', name: 'bad.csv', size: 8, sha256: sha));
    downloads.emit(DownloadEvent('a2', status: DownloadStatus.complete));
    await until(() => repo.current['a2']!.state == TransferState.failed);
    expect(repo.current['a2']!.error, contains('sha256'));
    expect(downloads.saved, ['a1']);
    expect(bad.existsSync(), isFalse, reason: 'a corrupt download is deleted');
    await repo.dispose();
  });

  test('a download started before the app restarted is picked up from its metadata', () async {
    final data = utf8.encode('hello');
    final f = File('${dir.path}/h.txt')..writeAsBytesSync(data);
    final downloads = FakeDownloads()..paths['a9'] = f.path;
    final repo = TransferRepositoryImpl(api: api(MockClient((_) async => http.Response('{}', 200))), downloads: downloads);
    final meta = jsonEncode({'sha256': sha256.convert(data).toString(), 'mime': 'text/plain', 'size': 5, 'session': 's1'});
    downloads.emit(DownloadEvent('a9', name: 'h.txt', meta: meta, status: DownloadStatus.complete));
    await until(() => repo.current['a9']?.state == TransferState.done);
    expect(repo.current['a9']!.session, 's1');
    await repo.dispose();
  });
}
