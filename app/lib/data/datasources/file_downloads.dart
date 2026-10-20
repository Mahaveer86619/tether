import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

import '../../core/error/exceptions.dart';

enum DownloadStatus { queued, running, paused, complete, failed, canceled }

class DownloadEvent {
  const DownloadEvent(this.id, {this.name = '', this.meta = '', this.status, this.progress, this.total = -1, this.speed = -1, this.error = ''});

  final String id, name;

  /// What was passed to [FileDownloads.enqueue], for downloads that outlive
  /// the app's memory of them.
  final String meta;

  /// Set on status changes.
  final DownloadStatus? status;

  /// 0..1, set on progress updates.
  final double? progress;
  final int total;

  /// Bytes per second.
  final double speed;
  final String error;
}

/// Downloads that keep going with the app in the background: on Android
/// a foreground service with a notification (pause, cancel), resuming with
/// Range requests. Throws [DataException]s only.
abstract interface class FileDownloads {
  Stream<DownloadEvent> get events;

  /// Picks up downloads from before the app was last closed.
  Future<void> start();

  Future<void> enqueue({required String id, required Uri url, required Map<String, String> headers, required String name, String meta = ''});
  Future<void> pause(String id);
  Future<void> resume(String id);
  Future<void> cancel(String id);

  /// Where the download is written inside the app's storage.
  Future<String> pathOf(String id);

  /// Moves a finished download somewhere the user can find it (Downloads,
  /// through MediaStore on Android) and returns where.
  Future<String> saveToDevice(String id, {String mime = ''});
}

class BackgroundFileDownloads implements FileDownloads {
  BackgroundFileDownloads([FileDownloader? downloader]) : _d = downloader ?? FileDownloader();

  final FileDownloader _d;
  final _events = StreamController<DownloadEvent>.broadcast();
  StreamSubscription<TaskUpdate>? _sub;
  bool _started = false;

  static const _group = 'artifacts';

  @override
  Stream<DownloadEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _sub = _d.updates.listen(_onUpdate);
    await _d.configure(globalConfig: [
      // Fail early rather than fill the disk; keep 200 MB free.
      (Config.checkAvailableSpace, 200),
      // Android's cache can be evicted mid-download, which breaks resume.
      (Config.useCacheDir, Config.never),
      (Config.runInForeground, Config.always),
      (Config.requestTimeout, const Duration(minutes: 1)),
    ]);
    _d.configureNotificationForGroup(
      _group,
      running: const TaskNotification('Downloading', '{filename} · {progress}'),
      paused: const TaskNotification('Paused', '{filename}'),
      complete: const TaskNotification('Downloaded', '{filename}'),
      error: const TaskNotification("Couldn't download", '{filename}'),
      progressBar: true,
    );
    await _d.start(autoCleanDatabase: true);
  }

  void _onUpdate(TaskUpdate u) {
    if (u.task.group != _group) return;
    switch (u) {
      case TaskStatusUpdate(:final status, :final exception):
        final s = switch (status) {
          TaskStatus.enqueued || TaskStatus.waitingToRetry => DownloadStatus.queued,
          TaskStatus.running => DownloadStatus.running,
          TaskStatus.paused => DownloadStatus.paused,
          TaskStatus.complete => DownloadStatus.complete,
          TaskStatus.canceled => DownloadStatus.canceled,
          TaskStatus.failed || TaskStatus.notFound => DownloadStatus.failed,
        };
        _events.add(DownloadEvent(u.task.taskId, name: u.task.filename, meta: u.task.metaData, status: s, error: exception?.description ?? (status == TaskStatus.notFound ? 'the file is gone from the hub' : '')));
      case TaskProgressUpdate(:final progress, :final expectedFileSize, :final networkSpeed):
        // Negative progress values are status signals, sent as status too.
        if (progress < 0) return;
        _events.add(DownloadEvent(u.task.taskId, name: u.task.filename, meta: u.task.metaData, progress: progress, total: expectedFileSize, speed: networkSpeed < 0 ? -1 : networkSpeed * 1024 * 1024));
    }
  }

  DownloadTask _task(String id, {Uri? url, Map<String, String> headers = const {}, String name = '', String meta = ''}) => DownloadTask(
        taskId: id,
        url: url?.toString() ?? 'about:blank',
        headers: headers,
        filename: name,
        // One folder per artifact: two files may share a name.
        directory: 'downloads/$id',
        baseDirectory: BaseDirectory.applicationSupport,
        group: _group,
        updates: Updates.statusAndProgress,
        retries: 5,
        allowPause: true,
        displayName: name,
        metaData: meta,
        transferHints: {TransferHint.userInitiated, TransferHint.largeFile},
      );

  Future<DownloadTask> _existing(String id) async {
    final t = await _d.taskForId(id) ?? (await _d.database.recordForId(id))?.task;
    if (t is DownloadTask) return t;
    throw ProtocolException('no download $id');
  }

  @override
  Future<void> enqueue({required String id, required Uri url, required Map<String, String> headers, required String name, String meta = ''}) async {
    await start();
    // The notification carries progress and the pause and cancel buttons.
    if (Platform.isAndroid && await _d.permissions.status(PermissionType.notifications) != PermissionStatus.granted) {
      await _d.permissions.request(PermissionType.notifications);
    }
    final task = _task(id, url: url, headers: headers, name: name, meta: meta);
    final old = File(await task.filePath());
    if (await old.exists()) await old.delete();
    if (!await _d.enqueue(task)) throw const NetworkException("couldn't start the download");
  }

  @override
  Future<void> pause(String id) async {
    if (!await _d.pause(await _existing(id))) throw const ProtocolException("the download can't be paused right now");
  }

  @override
  Future<void> resume(String id) async {
    if (!await _d.resume(await _existing(id))) throw const ProtocolException("the download can't be resumed; start it again");
  }

  @override
  Future<void> cancel(String id) => _d.cancelTaskWithId(id);

  @override
  Future<String> pathOf(String id) async => (await _existing(id)).filePath();

  @override
  Future<String> saveToDevice(String id, {String mime = ''}) async {
    final task = await _existing(id);
    final saved = await _d.moveToSharedStorage(task, SharedStorage.downloads, directory: 'Tether', mimeType: mime.isEmpty ? null : mime);
    if (saved == null) throw const StorageException("couldn't move the file to Downloads");
    return saved;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _events.close();
  }
}
