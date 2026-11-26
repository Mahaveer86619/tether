import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tether/core/error/failures.dart';
import 'package:tether/core/result.dart';
import 'package:tether/data/datasources/hub_endpoint.dart';
import 'package:tether/data/datasources/hub_rest_api.dart';
import 'package:tether/data/datasources/hub_socket.dart';
import 'package:tether/data/repositories/jobs_repository_impl.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/jobs_repository.dart';
import 'package:tether/domain/usecases/jobs.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/gen/tether/v1/tether.pb.dart' as pb;
import 'package:tether/gen/tether/v1/tether.pbenum.dart' as pbe;
import 'package:tether/presentation/hub/hub_cubit.dart';
import 'package:tether/presentation/jobs/jobs_cubit.dart';
import 'package:tether/presentation/jobs/jobs_page.dart';
import 'package:tether/presentation/theme/theme.dart';
import 'package:tether/presentation/widgets/format.dart';

import '../helpers/fakes.dart';

class FakeJobsRepository implements JobsRepository {
  FakeJobsRepository(this.jobs);

  List<Job> jobs;
  final started = <NewJobRequest>[];
  final acted = <(String, JobAction)>[];
  var logLines = <String>['epoch 1', 'epoch 2'];
  Failure? startFailure;
  final _changes = StreamController<Job>.broadcast();

  void push(Job j) => _changes.add(j);

  @override
  Stream<Job> get changes => _changes.stream;

  @override
  Future<Result<List<Job>>> list() async => Ok(jobs);

  @override
  Future<Result<Job>> start(NewJobRequest r) async {
    started.add(r);
    if (startFailure != null) return Err(startFailure!);
    return Ok(Job(id: 'new', name: r.command, node: r.node, cwd: r.cwd, command: r.command, state: JobState.starting));
  }

  @override
  Future<Result<void>> act(String jobId, JobAction action) async {
    acted.add((jobId, action));
    return const Ok(null);
  }

  @override
  Future<Result<void>> forget(String jobId) async => const Ok(null);

  @override
  Future<Result<List<String>>> logs(String jobId, {int lines = 200}) async => Ok(logLines);
}

Job job(String id, JobState state, {String address = ''}) =>
    Job(id: id, name: 'trainer $id', node: 'desk', cwd: '/work', command: 'python train.py', state: state, address: address, created: DateTime(2026, 11, 26));

HubCubit hubCubitFor(FakeHubRepository repo) => HubCubit(
      setMode: SetPermissionMode(repo),
      presence: ReportPresence(repo),
      watchHub: WatchHub(repo),
      decideApproval: DecideApproval(repo),
      setArchived: SetSessionArchived(repo),
      retry: RetryConnection(repo),
    );

Widget app(JobsCubit cubit, {List<Node> nodes = const [laptop]}) {
  final hub = FakeHubRepository(snapshotWith(const [], nodes: nodes));
  return MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider(lazy: false, create: (_) => hubCubitFor(hub)),
        ],
        child: const JobsView(),
      ),
    ),
  );
}

void main() {
  group('JobsCubit', () {
    test('lists jobs, live first, and follows the hub\'s pushes', () async {
      final repo = FakeJobsRepository([job('a', JobState.exited), job('b', JobState.running)]);
      final cubit = JobsCubit(jobs: Jobs(repo), logEvery: const Duration(hours: 1));
      await cubit.start();
      expect(cubit.state.list.map((j) => j.id), ['b', 'a']);

      repo.push(job('b', JobState.paused));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.jobs['b']!.state, JobState.paused);

      repo.push(const Job(id: 'a', name: '', node: '', cwd: '', command: '', state: JobState.unknown, removed: true));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.jobs.keys, ['b']);

      cubit.select('b');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.logs, ['epoch 1', 'epoch 2']);

      await cubit.act('b', JobAction.resume);
      expect(repo.acted.single, ('b', JobAction.resume));
      expect(cubit.state.busy, isEmpty);
      await cubit.close();
    });

    test('a failed start comes back to the form', () async {
      final repo = FakeJobsRepository([])..startFailure = const NodeOfflineFailure('desk is offline');
      final cubit = JobsCubit(jobs: Jobs(repo));
      final failure = await cubit.startJob(const NewJobRequest(node: 'desk', cwd: '/w', command: 'x'));
      expect(failure, isA<NodeOfflineFailure>());
      await cubit.close();
    });
  });

  group('JobsRepositoryImpl', () {
    test('reads the list and turns pushed frames into changes', () async {
      final requests = <http.Request>[];
      final api = HubRestApi(MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/jobs') && r.method == 'GET') {
          final list = pb.JobList(jobs: [
            pb.Job(id: 'j1', state: pbe.JobState.JOB_STATE_RUNNING, spec: pb.JobSpec(node: 'desk', command: 'serve', port: 8000), address: 'http://desk:8000'),
          ]);
          return http.Response(jsonEncode(list.toProto3Json()), 200);
        }
        return http.Response(jsonEncode(pb.Job(id: 'j1').toProto3Json()), 200);
      }), clientName: 'test')
        ..endpoint = HubEndpoint('ws://hub:7420/ws', 'tok');
      final socket = FakeHubSocket();
      final repo = JobsRepositoryImpl(api: api, socket: socket);

      final list = (await repo.list()).valueOrNull!;
      expect(list.single.address, 'http://desk:8000');
      expect(list.single.state, JobState.running);

      final next = repo.changes.first;
      socket.push(SocketFrame(pb.Frame(job: pb.Job(id: 'j1', state: pbe.JobState.JOB_STATE_PAUSED, spec: pb.JobSpec(node: 'desk')))));
      expect((await next).state, JobState.paused);

      final gone = repo.changes.first;
      socket.push(SocketFrame(pb.Frame(job: pb.Job(id: 'j1', endedMs: Int64(1)))));
      expect((await gone).removed, isTrue);

      await repo.act('j1', JobAction.pause);
      expect(requests.last.url.path, endsWith('/jobs/j1/pause'));
      await repo.start(const NewJobRequest(node: 'desk', cwd: '/w', command: 'serve', secretsFrom: '.env', restart: RestartPolicy.onFailure));
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body['envFrom'], [
        {'file': '.env'}
      ]);
      expect(body['restart'], 'on-failure');
      await repo.dispose();
    });
  });

  group('JobsView', () {
    testWidgets('shows state chips, the pause note, the address and the controls', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeJobsRepository([job('a', JobState.running, address: 'http://desk:8000'), job('b', JobState.failed)]);
      final cubit = JobsCubit(jobs: Jobs(repo), logEvery: const Duration(hours: 1));
      await tester.pumpWidget(app(cubit..start()));
      await tester.pump();
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);

      await tester.tap(find.text('trainer a'));
      await tester.pump();
      expect(find.byKey(const Key('pause-note')), findsOneWidget);
      expect(find.byKey(const Key('job-address')), findsOneWidget);
      expect(find.text('epoch 2'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(repo.acted.single, ('a', JobAction.pause));

      await tester.tap(find.text('trainer b'));
      await tester.pump();
      expect(find.byKey(const Key('pause-note')), findsNothing);
      expect(find.text('Start again'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('the start form asks for what it needs and starts the job', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeJobsRepository([]);
      final cubit = JobsCubit(jobs: Jobs(repo), logEvery: const Duration(hours: 1));
      await tester.pumpWidget(app(cubit..start()));
      await tester.pump();
      expect(find.text('No jobs yet'), findsOneWidget);

      await tester.tap(find.byKey(const Key('new-job')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('job-start')));
      await tester.pump();
      expect(find.byKey(const Key('job-error')), findsOneWidget);
      expect(repo.started, isEmpty);

      await tester.enterText(find.byKey(const Key('job-cwd')), '/work');
      await tester.enterText(find.byKey(const Key('job-command')), 'npm run dev');
      await tester.enterText(find.byKey(const Key('job-port')), '5173');
      await tester.tap(find.byKey(const Key('job-start')));
      await tester.pumpAndSettle();
      expect(repo.started.single, const NewJobRequest(node: 'laptop', cwd: '/work', command: 'npm run dev', port: 5173));
      expect(find.byType(NewJobDialog), findsNothing);
      await cubit.close();
    });
  });

  test('hardware reads as one line', () {
    const n = Node(name: 'desk', online: true, gpus: [Gpu(name: 'NVIDIA GeForce RTX 4090', memoryBytes: 24 << 30)], memoryBytes: 64 << 30, cpus: 16);
    expect(hardwareSummary(n), 'RTX 4090 24 GB · 64 GB RAM · 16 CPUs');
    expect(hardwareSummary(laptop), '');
  });
}
