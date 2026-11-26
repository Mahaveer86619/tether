import '../../core/result.dart';
import '../entities/entities.dart';

/// Jobs the agents run for the hub; see docs/architecture/jobs.md.
abstract interface class JobsRepository {
  /// Newest first.
  Future<Result<List<Job>>> list();

  Future<Result<Job>> start(NewJobRequest request);

  /// Asks the job's device; the new state arrives on [changes].
  Future<Result<void>> act(String jobId, JobAction action);

  /// Forgets an ended job.
  Future<Result<void>> forget(String jobId);

  /// The last [lines] lines of its output.
  Future<Result<List<String>>> logs(String jobId, {int lines = 200});

  /// Every change the hub pushes, as it happens.
  Stream<Job> get changes;
}
