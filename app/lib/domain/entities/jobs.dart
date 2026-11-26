import 'package:equatable/equatable.dart';

/// See docs/architecture/jobs.md.
enum JobState { starting, running, paused, exited, failed, stopped, lost, unknown }

extension JobStateInfo on JobState {
  bool get isLive => this == JobState.starting || this == JobState.running || this == JobState.paused;

  String get label => switch (this) {
        JobState.starting => 'Starting',
        JobState.running => 'Running',
        JobState.paused => 'Paused',
        JobState.exited => 'Exited',
        JobState.failed => 'Failed',
        JobState.stopped => 'Stopped',
        JobState.lost => 'Lost',
        JobState.unknown => 'Unknown',
      };
}

enum RestartPolicy { never, onFailure, always }

extension RestartPolicyWire on RestartPolicy {
  String get wire => switch (this) {
        RestartPolicy.never => 'never',
        RestartPolicy.onFailure => 'on-failure',
        RestartPolicy.always => 'always',
      };

  String get label => switch (this) {
        RestartPolicy.never => 'Never',
        RestartPolicy.onFailure => 'On failure',
        RestartPolicy.always => 'Always',
      };

  static RestartPolicy parse(String s) => switch (s) {
        'on-failure' => RestartPolicy.onFailure,
        'always' => RestartPolicy.always,
        _ => RestartPolicy.never,
      };
}

class Job extends Equatable {
  const Job({
    required this.id,
    required this.name,
    required this.node,
    required this.cwd,
    required this.command,
    required this.state,
    this.port = 0,
    this.restart = RestartPolicy.never,
    this.needsGpu = false,
    this.secretFiles = const [],
    this.created,
    this.started,
    this.ended,
    this.exitCode = 0,
    this.restarts = 0,
    this.error = '',
    this.address = '',
    this.by = '',
    this.removed = false,
  });

  final String id, name, node, cwd, command;
  final JobState state;
  final int port;
  final RestartPolicy restart;
  final bool needsGpu;

  /// The sealed project files its secrets come from, e.g. ".env".
  final List<String> secretFiles;
  final DateTime? created, started, ended;
  final int exitCode, restarts;
  final String error;

  /// http://machine:port on the tailnet, for a server.
  final String address;
  final String by;

  /// The hub forgot it.
  final bool removed;

  @override
  List<Object?> get props =>
      [id, name, node, cwd, command, state, port, restart, needsGpu, secretFiles, created, started, ended, exitCode, restarts, error, address, by, removed];
}

class NewJobRequest extends Equatable {
  const NewJobRequest({
    required this.node,
    required this.cwd,
    required this.command,
    this.name = '',
    this.port = 0,
    this.restart = RestartPolicy.never,
    this.needsGpu = false,
    this.secretsFrom = '',
  });

  final String node, cwd, command, name;
  final int port;
  final RestartPolicy restart;
  final bool needsGpu;

  /// A sealed setup file of the project in [cwd] whose keys the job gets.
  final String secretsFrom;

  @override
  List<Object?> get props => [node, cwd, command, name, port, restart, needsGpu, secretsFrom];
}

enum JobAction { stop, pause, resume, restart }

class Gpu extends Equatable {
  const Gpu({required this.name, this.memoryBytes = 0});

  final String name;
  final int memoryBytes;

  @override
  List<Object?> get props => [name, memoryBytes];
}
