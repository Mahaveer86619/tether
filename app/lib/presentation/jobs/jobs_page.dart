import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'jobs_cubit.dart';

/// Servers, scripts and training runs the devices run for you; see
/// docs/architecture/jobs.md.
class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<JobsCubit>()..start(),
        child: const JobsView(),
      );
}

class JobsView extends StatelessWidget {
  const JobsView({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return BlocConsumer<JobsCubit, JobsState>(
      listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
      listener: (context, s) => showFailure(context, s.failure!),
      builder: (context, s) {
        final job = s.selectedJob;
        if (!wide && job != null) return _JobDetail(job: job, logs: s.logs, busy: s.busy.contains(job.id), onBack: () => context.read<JobsCubit>().select(null));
        final list = _JobList(state: s);
        if (!wide) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 380, child: list),
            VerticalDivider(width: 1, color: context.colors.border),
            Expanded(
              child: job == null
                  ? const EmptyState(icon: Icons.terminal_rounded, title: 'Pick a job', body: 'Its output and controls show here.')
                  : _JobDetail(job: job, logs: s.logs, busy: s.busy.contains(job.id)),
            ),
          ],
        );
      },
    );
  }
}

class _JobList extends StatelessWidget {
  const _JobList({required this.state});

  final JobsState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<JobsCubit>();
    final jobs = state.list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(Gap.page(context), Gap.md, Gap.page(context), 0),
          child: Row(
            children: [
              Expanded(child: Text('Processes your devices run and keep running when the app closes.', style: TextStyle(color: c.muted, fontSize: 13))),
              const SizedBox(width: Gap.sm),
              FilledButton.icon(
                key: const Key('new-job'),
                onPressed: () => _startJob(context, cubit),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New job'),
              ),
            ],
          ),
        ),
        Expanded(
          child: !state.loaded
              ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
              : jobs.isEmpty
                  ? const EmptyState(
                      icon: Icons.play_circle_outline_rounded,
                      title: 'No jobs yet',
                      body: 'Start a dev server or a training run on any device, or ask a chat to.',
                    )
                  : RefreshIndicator(
                      onRefresh: cubit.load,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(Gap.page(context), Gap.sm, Gap.page(context), bottomRoom(context)),
                        children: [
                          for (final j in jobs)
                            _JobTile(job: j, selected: j.id == state.selected, onTap: () => cubit.select(j.id)),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

Color jobStateColor(BuildContext context, JobState s) {
  final c = context.colors;
  return switch (s) {
    JobState.running => c.success,
    JobState.starting => c.info,
    JobState.paused => c.warning,
    JobState.queued => c.info,
    JobState.failed || JobState.lost => c.danger,
    _ => c.muted,
  };
}

class JobStateChip extends StatelessWidget {
  const JobStateChip(this.state, {super.key});

  final JobState state;

  @override
  Widget build(BuildContext context) => Pill(state.label, color: jobStateColor(context, state));
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, required this.selected, required this.onTap});

  final Job job;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Material(
        color: selected ? c.raised : c.surface,
        shape: RoundedRectangleBorder(borderRadius: context.round(10), side: BorderSide(color: selected ? c.accent : c.border)),
        child: InkWell(
          borderRadius: context.round(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(job.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Type.title(context))),
                    const SizedBox(width: Gap.sm),
                    JobStateChip(job.state),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Text(job.command, maxLines: 1, overflow: TextOverflow.ellipsis, style: Type.meta(context)),
                const SizedBox(height: Gap.xs),
                Text(
                  [job.node, if (job.started != null) ago(job.started), if (job.address.isNotEmpty) job.address].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.meta(context, color: c.faint, size: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JobDetail extends StatelessWidget {
  const _JobDetail({required this.job, required this.logs, required this.busy, this.onBack});

  final Job job;
  final List<String> logs;
  final bool busy;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<JobsCubit>();
    void act(JobAction a) => cubit.act(job.id, a);
    final live = job.state.isLive;
    final waiting = job.state.isWaiting;
    return Padding(
      padding: EdgeInsets.fromLTRB(Gap.page(context), Gap.md, Gap.page(context), Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onBack != null) IconButton(tooltip: 'Back', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
              Expanded(child: Text(job.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
              JobStateChip(job.state),
            ],
          ),
          const SizedBox(height: Gap.sm),
          SelectableText(job.command, style: Type.meta(context, color: c.text, size: 13)),
          const SizedBox(height: Gap.xs),
          Text(
            [
              'on ${job.node}',
              job.cwd,
              if (job.restart != RestartPolicy.never) 'restart ${job.restart.label.toLowerCase()}${job.restarts > 0 ? ' (${job.restarts} so far)' : ''}',
              if (job.secretFiles.isNotEmpty) 'secrets from ${job.secretFiles.join(', ')}',
              if (job.schedule.isNotEmpty) 'when ${job.schedule == 'next_free' ? 'the device is next free' : 'slot ${job.schedule}'}',
              if (job.ended != null && !live) 'exit code ${job.exitCode}',
            ].join(' · '),
            style: Type.meta(context, size: 11),
          ),
          if (job.address.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('job-address'),
                onPressed: () => launchUrl(Uri.parse(job.address), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(job.address),
              ),
            ),
          ],
          if (job.error.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(job.error, style: TextStyle(color: job.state == JobState.failed || job.state == JobState.lost ? c.danger : c.muted, fontSize: 13)),
          ],
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              if (job.state == JobState.running || job.state == JobState.starting)
                OutlinedButton.icon(onPressed: busy ? null : () => act(JobAction.pause), icon: const Icon(Icons.pause_rounded, size: 18), label: const Text('Pause')),
              if (job.state == JobState.paused)
                OutlinedButton.icon(onPressed: busy ? null : () => act(JobAction.resume), icon: const Icon(Icons.play_arrow_rounded, size: 18), label: const Text('Resume')),
              if (live || waiting)
                OutlinedButton.icon(
                  onPressed: busy ? null : () => act(JobAction.stop),
                  style: OutlinedButton.styleFrom(foregroundColor: c.danger),
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('Stop'),
                ),
              if (!waiting)
                OutlinedButton.icon(
                  onPressed: busy ? null : () => act(JobAction.restart),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: Text(live ? 'Restart' : 'Start again'),
                ),
              if (!live && !waiting)
                TextButton.icon(onPressed: () => cubit.forget(job.id), icon: const Icon(Icons.delete_outline_rounded, size: 18), label: const Text('Remove')),
            ],
          ),
          if (waiting) ...[
            const SizedBox(height: Gap.sm),
            Text(
              key: const Key('wait-note'),
              'Waiting for a free window or a booked slot. It starts by itself, and pauses when the window closes so the device owner gets it back.',
              style: TextStyle(color: c.muted, fontSize: 12),
            ),
          ],
          if (job.state.isLive) ...[
            const SizedBox(height: Gap.sm),
            Text(
              'Pausing suspends every process of the job on its device. Its memory, and a GPU\'s memory, stay held while paused, '
              'and whatever is connected to it (a browser, a database) may time out.',
              key: const Key('pause-note'),
              style: TextStyle(color: c.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(child: Text('OUTPUT', style: Type.label(context))),
              IconButton(
                tooltip: 'Copy',
                iconSize: 18,
                onPressed: logs.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: logs.join('\n'))),
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          Expanded(child: _LogView(lines: logs)),
        ],
      ),
    );
  }
}

/// The log's tail, kept scrolled to the end unless you scrolled up.
class _LogView extends StatefulWidget {
  const _LogView({required this.lines});

  final List<String> lines;

  @override
  State<_LogView> createState() => _LogViewState();
}

class _LogViewState extends State<_LogView> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(_LogView old) {
    super.didUpdateWidget(old);
    final atEnd = !_scroll.hasClients || _scroll.position.pixels >= _scroll.position.maxScrollExtent - 24;
    if (atEnd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.codeBg, borderRadius: context.round(8), border: Border.all(color: c.border)),
      child: widget.lines.isEmpty
          ? Center(child: Text('No output yet.', style: TextStyle(color: c.faint, fontSize: 13)))
          : SelectionArea(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(Gap.sm),
                itemCount: widget.lines.length,
                itemBuilder: (_, i) => Text(widget.lines[i], style: Type.meta(context, color: c.text, size: 12)),
              ),
            ),
    );
  }
}

Future<void> _startJob(BuildContext context, JobsCubit cubit) async {
  final nodes = context.read<HubCubit>().state.hub.nodes.values.where((n) => n.online).toList()..sort((a, b) => a.name.compareTo(b.name));
  await showDialog<void>(context: context, builder: (_) => BlocProvider.value(value: cubit, child: NewJobDialog(nodes: nodes)));
}

/// The start form: device, folder, command, and the optional rest.
class NewJobDialog extends StatefulWidget {
  const NewJobDialog({super.key, required this.nodes});

  final List<Node> nodes;

  @override
  State<NewJobDialog> createState() => _NewJobDialogState();
}

class _NewJobDialogState extends State<NewJobDialog> {
  final _cwd = TextEditingController();
  final _command = TextEditingController();
  final _name = TextEditingController();
  final _port = TextEditingController();
  final _secrets = TextEditingController();
  String? _node;
  RestartPolicy _restart = RestartPolicy.never;
  bool _gpu = false;
  bool _whenFree = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _node = widget.nodes.firstOrNull?.name;
  }

  @override
  void dispose() {
    for (final c in [_cwd, _command, _name, _port, _secrets]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final node = _node;
    if (node == null || _cwd.text.trim().isEmpty || _command.text.trim().isEmpty) {
      setState(() => _error = 'A device, a folder and a command are needed.');
      return;
    }
    final port = int.tryParse(_port.text.trim()) ?? 0;
    if (_port.text.trim().isNotEmpty && (port < 1 || port > 65535)) {
      setState(() => _error = 'The port is a number from 1 to 65535.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final failure = await context.read<JobsCubit>().startJob(NewJobRequest(
          node: node,
          cwd: _cwd.text.trim(),
          command: _command.text.trim(),
          name: _name.text.trim(),
          port: port,
          restart: _restart,
          needsGpu: _gpu,
          secretsFrom: _secrets.text.trim(),
          schedule: _whenFree ? 'next_free' : '',
          queueWhenBusy: _whenFree,
        ));
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _sending = false;
        _error = failure.userMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Node? node;
    for (final n in widget.nodes) {
      if (n.name == _node) node = n;
    }
    final hasGpu = node?.capabilities.contains('gpu') ?? false;
    return AlertDialog(
      title: const Text('New job'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.nodes.isEmpty)
                Text('No device is online.', style: TextStyle(color: c.danger))
              else
                DropdownButtonFormField<String>(
                  key: const Key('job-node'),
                  initialValue: _node,
                  decoration: const InputDecoration(labelText: 'Device'),
                  items: [
                    for (final n in widget.nodes)
                      DropdownMenuItem(value: n.name, child: Text(n.capabilities.contains('gpu') ? '${n.name} · GPU' : n.name)),
                  ],
                  onChanged: (v) => setState(() => _node = v),
                ),
              TextField(key: const Key('job-cwd'), controller: _cwd, decoration: const InputDecoration(labelText: 'Folder on that device')),
              TextField(
                key: const Key('job-command'),
                controller: _command,
                decoration: const InputDecoration(labelText: 'Command', hintText: 'npm run dev, python train.py ...'),
                style: Type.meta(context, color: c.text, size: 13),
              ),
              TextField(key: const Key('job-name'), controller: _name, decoration: const InputDecoration(labelText: 'Name (optional)')),
              TextField(
                key: const Key('job-port'),
                controller: _port,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port, for a server (optional)', helperText: 'You get a link to it on your tailnet.'),
              ),
              DropdownButtonFormField<RestartPolicy>(
                initialValue: _restart,
                decoration: const InputDecoration(labelText: 'Restart when it ends'),
                items: [for (final p in RestartPolicy.values) DropdownMenuItem(value: p, child: Text(p.label))],
                onChanged: (v) => setState(() => _restart = v ?? RestartPolicy.never),
              ),
              TextField(
                controller: _secrets,
                decoration: const InputDecoration(
                  labelText: 'Secrets from (optional)',
                  hintText: '.env',
                  helperText: 'A sealed setup file of the project in this folder; its keys go into the environment.',
                ),
              ),
              if (hasGpu)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _gpu,
                  onChanged: (v) => setState(() => _gpu = v ?? false),
                  title: const Text('Needs the GPU'),
                ),
              CheckboxListTile(
                key: const Key('job-when-free'),
                contentPadding: EdgeInsets.zero,
                value: _whenFree,
                onChanged: (v) => setState(() => _whenFree = v ?? false),
                title: const Text('Wait for the device to be free'),
                subtitle: const Text('Queues the job if it is busy or outside your sharing hours; it starts by itself later.'),
              ),
              if (_error != null) ...[
                const SizedBox(height: Gap.sm),
                Text(_error!, key: const Key('job-error'), style: TextStyle(color: c.danger, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(key: const Key('job-start'), onPressed: _sending || widget.nodes.isEmpty ? null : _submit, child: const Text('Start')),
      ],
    );
  }
}
