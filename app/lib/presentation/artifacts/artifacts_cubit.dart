import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class ArtifactsState extends Equatable {
  const ArtifactsState({this.failure, this.failureId = 0, this.transfers = const {}});

  final Failure? failure;
  final int failureId;

  /// Downloads and uploads, by id; a download's id is its artifact's.
  final Map<String, Transfer> transfers;

  List<Transfer> get uploads => [for (final t in transfers.values) if (t.kind == TransferKind.upload) t];

  ArtifactsState copyWith({Failure? failure, int? failureId, Map<String, Transfer>? transfers}) =>
      ArtifactsState(failure: failure ?? this.failure, failureId: failureId ?? this.failureId, transfers: transfers ?? this.transfers);

  @override
  List<Object?> get props => [failure, failureId, transfers];
}

/// App-wide view model for the artifact store: file contents (cached),
/// downloads and uploads with progress, links and deletes. The list itself
/// comes with the hub snapshot.
class ArtifactsCubit extends Cubit<ArtifactsState> {
  ArtifactsCubit({required this._artifacts, required this._transfers}) : super(ArtifactsState(transfers: _transfers.current)) {
    _sub = _transfers.watch().listen((t) => emit(state.copyWith(transfers: t)));
  }

  final Artifacts _artifacts;
  final Transfers _transfers;
  late final StreamSubscription<Map<String, Transfer>> _sub;
  final _cache = <String, Future<Uint8List?>>{};

  static const _cacheSize = 60;

  /// The file's bytes, or null if they couldn't be fetched. Only for files
  /// small enough to preview; bigger ones are downloaded.
  Future<Uint8List?> bytes(String id) {
    final hit = _cache.remove(id);
    if (hit != null) return _cache[id] = hit;
    if (_cache.length >= _cacheSize) _cache.remove(_cache.keys.first);
    return _cache[id] = _artifacts.bytes(id).then((r) {
      if (r.valueOrNull case final b?) return Uint8List.fromList(b);
      _cache.remove(id);
      return null;
    });
  }

  /// Uploads a file from disk. With a [session] it's attached to it;
  /// [forMessage] holds it for the message being written.
  Future<Artifact?> upload(LocalFile file, {String session = '', String note = '', bool forMessage = false}) async {
    final result = await _transfers.upload(file, session: session, note: note, forMessage: forMessage);
    return result.fold((f) {
      _fail(f);
      return null;
    }, (a) => a);
  }

  Future<void> download(Artifact a) => _run(_transfers.download(a));
  Future<void> pause(String id) => _run(_transfers.pause(id));
  Future<void> resume(String id) => _run(_transfers.resume(id));
  Future<void> cancel(String id) => _run(_transfers.cancel(id));
  void dismiss(String id) => _transfers.dismiss(id);

  /// A link that works without a token for an hour.
  Future<String?> link(String id) async {
    final result = await _artifacts.link(id);
    return result.fold((f) {
      _fail(f);
      return null;
    }, (url) => url);
  }

  Future<void> delete(String id) => _run(_artifacts.delete(id));

  Future<void> _run(Future<Result<void>> call) async {
    if ((await call).failureOrNull case final f?) _fail(f);
  }

  void _fail(Failure f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1));

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
