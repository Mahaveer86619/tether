import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/error/exceptions.dart';
import '../../gen/tether/v1/tether.pb.dart' as pb;

/// Chat history and the last dashboard state on this device, so sessions
/// open instantly and the app is useful before it reconnects. Stored as
/// protobuf files; a missing or corrupt file just means "nothing cached".
abstract interface class HubCache {
  Future<pb.TimelinePage?> readTimeline(String session);
  Future<void> writeTimeline(pb.TimelinePage page);
  Future<void> removeTimeline(String session);
  Future<pb.Welcome?> readState();
  Future<void> writeState(pb.Welcome state);
  Future<void> clear();
}

class FileHubCache implements HubCache {
  FileHubCache({Future<Directory> Function()? root, this.maxTimelines = 300})
      : _root = root ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _root;
  final int maxTimelines;
  Directory? _dir;

  Future<Directory> get _base async {
    if (_dir != null) return _dir!;
    final d = Directory('${(await _root()).path}${Platform.pathSeparator}hub-cache');
    await d.create(recursive: true);
    return _dir = d;
  }

  Future<File> _timelineFile(String session) async {
    // Session ids are UUIDs; anything else is reduced to safe characters.
    final safe = session.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '_');
    return File('${(await _base).path}${Platform.pathSeparator}$safe.timeline');
  }

  Future<File> get _stateFile async => File('${(await _base).path}${Platform.pathSeparator}state.bin');

  @override
  Future<pb.TimelinePage?> readTimeline(String session) async {
    try {
      final f = await _timelineFile(session);
      if (!await f.exists()) return null;
      return pb.TimelinePage.fromBuffer(await f.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeTimeline(pb.TimelinePage page) async {
    await _atomicWrite(await _timelineFile(page.session), page.writeToBuffer());
    await _prune();
  }

  @override
  Future<void> removeTimeline(String session) async {
    try {
      final f = await _timelineFile(session);
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // Already gone or being replaced; nothing to keep either way.
    }
  }

  @override
  Future<pb.Welcome?> readState() async {
    try {
      final f = await _stateFile;
      if (!await f.exists()) return null;
      return pb.Welcome.fromBuffer(await f.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeState(pb.Welcome state) async => _atomicWrite(await _stateFile, state.writeToBuffer());

  @override
  Future<void> clear() async {
    try {
      final d = await _base;
      if (await d.exists()) await d.delete(recursive: true);
      _dir = null;
    } on FileSystemException catch (e) {
      throw StorageException(e.message);
    }
  }

  Future<void> _atomicWrite(File f, List<int> bytes) async {
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(f.path);
    } on FileSystemException catch (e) {
      throw StorageException(e.message);
    }
  }

  /// Keeps the most recently written timelines only.
  Future<void> _prune() async {
    final files = (await _base).listSync().whereType<File>().where((f) => f.path.endsWith('.timeline')).toList();
    if (files.length <= maxTimelines) return;
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final f in files.skip(maxTimelines)) {
      try {
        f.deleteSync();
      } on FileSystemException {
        // Another write may be replacing it; it will be pruned next time.
      }
    }
  }
}
