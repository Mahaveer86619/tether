import 'package:fixnum/fixnum.dart';

import '../../domain/entities/entities.dart';
import '../../gen/tether/v1/tether.pb.dart' as pb;
import '../../gen/tether/v1/tether.pbenum.dart' as pbe;

DateTime? _time(Int64 ms) => ms == Int64.ZERO ? null : DateTime.fromMillisecondsSinceEpoch(ms.toInt());

JobState jobStateFromPb(pbe.JobState s) => switch (s) {
      pbe.JobState.JOB_STATE_STARTING => JobState.starting,
      pbe.JobState.JOB_STATE_RUNNING => JobState.running,
      pbe.JobState.JOB_STATE_PAUSED => JobState.paused,
      pbe.JobState.JOB_STATE_QUEUED => JobState.queued,
      pbe.JobState.JOB_STATE_EXITED => JobState.exited,
      pbe.JobState.JOB_STATE_FAILED => JobState.failed,
      pbe.JobState.JOB_STATE_STOPPED => JobState.stopped,
      pbe.JobState.JOB_STATE_LOST => JobState.lost,
      _ => JobState.unknown,
    };

/// A job frame without a spec says the hub forgot the job.
Job jobFromPb(pb.Job j) => Job(
      id: j.id,
      name: j.spec.name,
      node: j.spec.node,
      cwd: j.spec.cwd,
      command: j.spec.command,
      state: jobStateFromPb(j.state),
      port: j.spec.port,
      restart: RestartPolicyWire.parse(j.spec.restart),
      needsGpu: j.spec.needsGpu,
      secretFiles: [for (final r in j.spec.envFrom) r.file],
      created: _time(j.createdMs),
      started: _time(j.startedMs),
      ended: _time(j.endedMs),
      exitCode: j.exitCode,
      restarts: j.restarts,
      error: j.error,
      address: j.address,
      by: j.by,
      removed: !j.hasSpec(),
      schedule: j.spec.schedule,
      queueWhenBusy: j.spec.queueWhenBusy,
    );

pb.JobSpec jobSpecToPb(NewJobRequest r) => pb.JobSpec(
      node: r.node,
      cwd: r.cwd,
      command: r.command,
      name: r.name.isEmpty ? null : r.name,
      port: r.port > 0 ? r.port : null,
      restart: r.restart == RestartPolicy.never ? null : r.restart.wire,
      needsGpu: r.needsGpu ? true : null,
      envFrom: r.secretsFrom.isEmpty ? null : [pb.EnvRef(file: r.secretsFrom)],
      schedule: r.schedule.isEmpty ? null : r.schedule,
      queueWhenBusy: r.queueWhenBusy ? true : null,
    );
