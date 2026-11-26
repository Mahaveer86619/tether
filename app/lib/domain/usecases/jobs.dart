import '../../core/result.dart';
import '../entities/entities.dart';
import '../repositories/jobs_repository.dart';

/// Start, control and read jobs on any device.
class Jobs {
  const Jobs(this._repo);
  final JobsRepository _repo;

  Future<Result<List<Job>>> list() => _repo.list();
  Future<Result<Job>> start(NewJobRequest request) => _repo.start(request);
  Future<Result<void>> act(String jobId, JobAction action) => _repo.act(jobId, action);
  Future<Result<void>> forget(String jobId) => _repo.forget(jobId);
  Future<Result<List<String>>> logs(String jobId, {int lines = 200}) => _repo.logs(jobId, lines: lines);
  Stream<Job> get changes => _repo.changes;
}
