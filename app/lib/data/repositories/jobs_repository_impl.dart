import 'dart:async';

import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/jobs_repository.dart';
import '../../gen/tether/v1/tether.pb.dart' as pb;
import '../datasources/hub_rest_api.dart';
import '../datasources/hub_socket.dart';
import '../mappers/job_mappers.dart';
import 'failure_mapper.dart';

class JobsRepositoryImpl implements JobsRepository {
  JobsRepositoryImpl({required this._api, required HubSocket socket}) {
    _sub = socket.events.listen((ev) {
      if (ev is SocketFrame && ev.frame.whichBody() == pb.Frame_Body.job) {
        _changes.add(jobFromPb(ev.frame.job));
      }
    });
  }

  final HubRestApi _api;
  late final StreamSubscription<SocketEvent> _sub;
  final _changes = StreamController<Job>.broadcast();

  @override
  Stream<Job> get changes => _changes.stream;

  @override
  Future<Result<List<Job>>> list() => guard(() async => [for (final j in (await _api.jobs()).jobs) jobFromPb(j)]);

  @override
  Future<Result<Job>> start(NewJobRequest request) => guard(() async => jobFromPb(await _api.startJob(jobSpecToPb(request))));

  @override
  Future<Result<void>> act(String jobId, JobAction action) => guard(() => _api.jobAction(jobId, action.name));

  @override
  Future<Result<void>> forget(String jobId) => guard(() => _api.forgetJob(jobId));

  @override
  Future<Result<List<String>>> logs(String jobId, {int lines = 200}) => guard(() async => (await _api.jobLogs(jobId, tail: lines)).lines.toList());

  Future<void> dispose() async {
    await _sub.cancel();
    await _changes.close();
  }
}
