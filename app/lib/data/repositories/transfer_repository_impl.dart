import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import '../../core/error/exceptions.dart';
import '../../core/upload_id.dart';
import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/file_downloads.dart';
import '../datasources/hub_rest_api.dart';
import '../mappers/hub_mappers.dart';
import 'failure_mapper.dart';

/// Downloads go through [FileDownloads] (in the background, resumable);
/// uploads are sent in chunks from disk, so a dropped connection costs one
/// chunk, not the file.
class TransferRepositoryImpl implements TransferRepository {
  TransferRepositoryImpl({required this._api, required this._downloads, this.chunkSize = 4 << 20, this.retryDelay = const Duration(seconds: 2)}) {
    _sub = _downloads.events.listen(_onDownload);
    unawaited(guard(_downloads.start));
  }

  final HubRestApi _api;
  final FileDownloads _downloads;
  final int chunkSize;
  final Duration retryDelay;
  late final StreamSubscription<DownloadEvent> _sub;
  final _changes = StreamController<Map<String, Transfer>>.broadcast();
  final _expected = <String, Artifact>{};
  final _canceledUploads = <String>{};
  Map<String, Transfer> _now = const {};
  int _uploads = 0;

  static const _attempts = 6;

  @override
  Map<String, Transfer> get current => _now;

  @override
  Stream<Map<String, Transfer>> watch() async* {
    yield _now;
    yield* _changes.stream;
  }

  void _put(Transfer t) {
    _now = {..._now, t.id: t};
    _changes.add(_now);
  }

  void _update(String id, Transfer Function(Transfer) change) {
    final t = _now[id];
    if (t != null) _put(change(t));
  }

  @override
  void dismiss(String id) {
    if (!(_now[id]?.finished ?? false)) return;
    _now = {..._now}..remove(id);
    _changes.add(_now);
  }

  @override
  Future<Result<void>> download(Artifact a) async {
    if (_api.endpoint == null) return const Err(NotConnectedFailure());
    if (_api.pinnedCertificate) {
      return const Err(TransferFailure("Downloads need a hub on Tailscale or with a trusted certificate; this one's certificate is pinned."));
    }
    if (_now[a.id]?.active ?? false) return const Ok(null);
    _expected[a.id] = a;
    _put(Transfer(id: a.id, kind: TransferKind.download, name: a.name, session: a.session, total: a.size, artifact: a));
    final meta = jsonEncode({'sha256': a.sha256, 'mime': a.mime, 'size': a.size, 'session': a.session});
    final r = await guard(() => _downloads.enqueue(id: a.id, url: _api.artifactContentUrl(a.id), headers: _api.authHeaders, name: a.name, meta: meta));
    if (r.failureOrNull case final f?) _update(a.id, (t) => t.copyWith(state: TransferState.failed, error: f.userMessage));
    return r;
  }

  void _onDownload(DownloadEvent e) {
    final t = _now[e.id] ?? _adopt(e);
    if (t == null) return;
    if (e.progress case final p?) {
      final total = e.total > 0 ? e.total : t.total;
      _put(t.copyWith(state: TransferState.running, bytes: (p * total).round(), total: total, speed: e.speed > 0 ? e.speed : t.speed));
      return;
    }
    switch (e.status) {
      case DownloadStatus.queued:
        _put(t.copyWith(state: TransferState.queued));
      case DownloadStatus.running:
        _put(t.copyWith(state: TransferState.running));
      case DownloadStatus.paused:
        _put(t.copyWith(state: TransferState.paused));
      case DownloadStatus.canceled:
        _put(t.copyWith(state: TransferState.canceled));
      case DownloadStatus.failed:
        _put(t.copyWith(state: TransferState.failed, error: e.error.isEmpty ? 'The download failed.' : e.error));
      case DownloadStatus.complete:
        // Restarts can report a completion twice; the file is moved after the first.
        if (t.state != TransferState.verifying && t.state != TransferState.done) unawaited(_finishDownload(t));
      case null:
        break;
    }
  }

  /// A download started before the app was last closed.
  Transfer? _adopt(DownloadEvent e) {
    final Map<String, dynamic> meta;
    try {
      meta = jsonDecode(e.meta) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
    final a = Artifact(
      id: e.id,
      name: e.name,
      sha256: meta['sha256'] as String? ?? '',
      mime: meta['mime'] as String? ?? '',
      size: meta['size'] as int? ?? 0,
      session: meta['session'] as String? ?? '',
    );
    _expected[a.id] = a;
    final t = Transfer(id: a.id, kind: TransferKind.download, name: a.name, session: a.session, total: a.size, artifact: a);
    _put(t);
    return t;
  }

  Future<void> _finishDownload(Transfer t) async {
    _put(t.copyWith(state: TransferState.verifying, bytes: t.total));
    try {
      final path = await _downloads.pathOf(t.id);
      final want = _expected[t.id]?.sha256 ?? '';
      if (want.isNotEmpty) {
        final got = await fileSha256(path);
        if (got != want) {
          await File(path).delete();
          _put(t.copyWith(state: TransferState.failed, error: "The download doesn't match the hub's copy (sha256). Try again."));
          return;
        }
      }
      final saved = await _downloads.saveToDevice(t.id, mime: _expected[t.id]?.mime ?? '');
      _put(t.copyWith(state: TransferState.done, bytes: t.total, savedTo: saved));
    } on Exception catch (e) {
      _put(t.copyWith(state: TransferState.failed, error: failureFrom(e).userMessage));
    }
  }

  @override
  Future<Result<void>> pause(String id) => guard(() async {
        if (_now[id]?.kind == TransferKind.download) await _downloads.pause(id);
      });

  @override
  Future<Result<void>> resume(String id) => guard(() async {
        if (_now[id]?.kind == TransferKind.download) await _downloads.resume(id);
      });

  @override
  Future<Result<void>> cancel(String id) => guard(() async {
        final t = _now[id];
        if (t == null) return;
        if (t.kind == TransferKind.download) {
          await _downloads.cancel(id);
        } else {
          _canceledUploads.add(id);
        }
      });

  @override
  Future<Result<Artifact>> upload(LocalFile file, {String session = '', String note = '', bool deliver = false}) async {
    if (_api.endpoint == null) return const Err(NotConnectedFailure());
    final id = 'upload-${++_uploads}';
    _put(Transfer(id: id, kind: TransferKind.upload, name: file.name, session: session, total: file.size, state: TransferState.preparing));
    final result = await guard(() => _upload(id, file, session: session, note: note, deliver: deliver));
    switch (result) {
      case Ok(:final value):
        _update(id, (t) => t.copyWith(state: TransferState.done, bytes: file.size, artifact: value));
      case Err(:final failure):
        final canceled = _canceledUploads.remove(id);
        _update(id, (t) => t.copyWith(state: canceled ? TransferState.canceled : TransferState.failed, error: canceled ? '' : failure.userMessage));
    }
    return result;
  }

  Future<Artifact> _upload(String id, LocalFile file, {required String session, required String note, required bool deliver}) async {
    final sha = await fileSha256(file.path);
    // One id for every try, so a start whose answer got lost doesn't leave an empty upload behind.
    final uploadId = file.uploadId.isEmpty ? newUploadId() : file.uploadId;
    final started = await _retrying(
      () => _api.startUpload(
        name: file.name,
        size: file.size,
        sha256: sha,
        uploadId: uploadId,
        session: session,
        origin: session.isEmpty ? 'upload' : 'attachment',
        note: note,
        deliver: deliver,
      ),
    );
    if (started.hasArtifact()) return artifactFromPb(started.artifact);
    _update(id, (t) => t.copyWith(state: TransferState.running));
    final raf = await File(file.path).open();
    try {
      var offset = started.offset.toInt();
      var failures = 0;
      final clock = Stopwatch()..start();
      var sentSince = 0;
      while (true) {
        if (_canceledUploads.contains(id)) {
          await _api.cancelUpload(started.id).catchError((_) {});
          throw const ProtocolException('canceled');
        }
        await raf.setPosition(offset);
        final chunk = await raf.read(chunkSize);
        try {
          final u = await _api.appendUpload(started.id, offset, chunk);
          failures = 0;
          sentSince += u.offset.toInt() - offset;
          offset = u.offset.toInt();
          final speed = clock.elapsedMilliseconds > 0 ? sentSince * 1000 / clock.elapsedMilliseconds : 0.0;
          _update(id, (t) => t.copyWith(state: u.hasArtifact() ? TransferState.verifying : TransferState.running, bytes: offset, speed: speed));
          if (u.hasArtifact()) return artifactFromPb(u.artifact);
          if (offset >= file.size) {
            // Everything is there, but the hub didn't file it: ask again.
            final again = await _api.uploadStatus(started.id);
            if (again.hasArtifact()) return artifactFromPb(again.artifact);
          }
        } on DataException catch (e) {
          // The hub rejected the content itself: retrying won't help.
          if (e is ApiException && e.statusCode != 409 && e.statusCode < 500) rethrow;
          if (++failures >= _attempts) rethrow;
          _update(id, (t) => t.copyWith(state: TransferState.queued));
          await Future<void>.delayed(retryDelay * failures);
          // Part of the chunk may have arrived; carry on from where the hub is.
          try {
            final now = await _api.uploadStatus(started.id);
            if (now.hasArtifact()) return artifactFromPb(now.artifact);
            offset = now.offset.toInt();
          } on NetworkException {
            // Still offline: the next chunk fails and waits longer.
          } on RequestTimeoutException {
            // As above.
          } on ApiException catch (e) {
            if (e.statusCode != 409) rethrow;
          }
          _update(id, (t) => t.copyWith(state: TransferState.running, bytes: offset));
        }
      }
    } finally {
      await raf.close();
    }
  }

  Future<T> _retrying<T>(Future<T> Function() call) async {
    for (var failures = 1;; failures++) {
      try {
        return await call();
      } on NetworkException {
        if (failures >= _attempts) rethrow;
      } on RequestTimeoutException {
        if (failures >= _attempts) rethrow;
      }
      await Future<void>.delayed(retryDelay * failures);
    }
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _changes.close();
  }
}

/// Hashes a file in another isolate, a chunk at a time.
Future<String> fileSha256(String path) => Isolate.run(() async => (await sha256.bind(File(path).openRead()).first).toString());
