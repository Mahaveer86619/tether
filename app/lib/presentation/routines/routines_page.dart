import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'routines_cubit.dart';

/// What you keep asking for, read from the hub's history: the routines that
/// could become skills. It only lists them; nothing is created yet.
class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<RoutinesCubit>()..load(),
        child: const _RoutinesBody(),
      );
}

class _RoutinesBody extends StatelessWidget {
  const _RoutinesBody();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return BlocConsumer<RoutinesCubit, RoutinesState>(
      listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
      listener: (context, s) => showFailure(context, s.failure!),
      builder: (context, s) {
        final cubit = context.read<RoutinesCubit>();
        final report = s.report;
        final side = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 16.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(side, 8, side, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        'Things you keep asking for. When a routine has come up often enough, Tether can turn it into a skill so Claude just runs it.',
                        style: TextStyle(fontSize: 13, color: c.muted),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(key: const Key('routines-recent'), label: const Text('Last 30 days'), selected: !s.allTime, onSelected: (_) => cubit.setAllTime(false)),
                        ChoiceChip(key: const Key('routines-all'), label: const Text('All history'), selected: s.allTime, onSelected: (_) => cubit.setAllTime(true)),
                        FilterChip(key: const Key('routines-two'), label: const Text('Include 2 runs'), selected: s.twoRuns, onSelected: cubit.setTwoRuns),
                      ],
                    ),
                    if (report == null)
                      const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))
                    else ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Text(
                          'Read ${report.tasks} requests from ${report.sessions} sessions${s.loading ? '…' : ''}',
                          key: const Key('routines-summary'),
                          style: TextStyle(fontSize: 12, color: c.faint),
                        ),
                      ),
                      if (report.routines.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: EmptyState(
                            icon: Icons.auto_awesome_outlined,
                            title: 'No routines yet',
                            body: 'A routine shows up once the same kind of request has come up in at least two sessions.',
                          ),
                        )
                      else
                        for (final r in report.routines) _RoutineCard(routine: r),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoutineCard extends StatefulWidget {
  const _RoutineCard({required this.routine});

  final Routine routine;

  @override
  State<_RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<_RoutineCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = widget.routine;
    final where = [
      r.nodes.join(', '),
      if (r.cwds.isNotEmpty) baseName(r.cwds.first) + (r.cwds.length > 1 ? ' and ${r.cwds.length - 1} more' : ''),
    ].where((x) => x.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('routine-${r.example.hashCode}'),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(r.example, maxLines: _open ? 4 : 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
                    Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: c.faint),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Pill('${r.runs} runs in ${r.sessions} sessions', color: c.accent),
                    Pill(r.mutating ? 'changes things' : 'read-only', color: r.mutating ? c.warning : c.success),
                    if (r.clean < 1) Pill('${(r.clean * 100).round()}% without failures'),
                  ],
                ),
                if (where.isNotEmpty || r.last != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      [if (where.isNotEmpty) where, if (r.last != null) 'last ${ago(r.last)} ago'].join(' · '),
                      style: TextStyle(fontSize: 12, color: c.muted),
                    ),
                  ),
                if (_open) ...[
                  if (r.requests.length > 1) ...[
                    const SizedBox(height: 10),
                    Text('How it was asked', style: TextStyle(fontSize: 11.5, color: c.faint, fontWeight: FontWeight.w600)),
                    for (final q in r.requests) Padding(padding: const EdgeInsets.only(top: 3), child: Text('“$q”', style: TextStyle(fontSize: 12.5, color: c.muted))),
                  ],
                  if (r.steps.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Steps most runs take', style: TextStyle(fontSize: 11.5, color: c.faint, fontWeight: FontWeight.w600)),
                    for (final s in r.steps)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(s.mutating ? Icons.edit_outlined : Icons.visibility_outlined, size: 14, color: s.mutating ? c.warning : c.faint),
                            const SizedBox(width: 6),
                            Expanded(child: Text(s.detail.isEmpty ? s.key : s.detail, maxLines: 3, overflow: TextOverflow.ellipsis, style: monoStyle(context, size: 12, color: c.muted))),
                            const SizedBox(width: 8),
                            Text('${(s.share * 100).round()}%', style: TextStyle(fontSize: 11.5, color: c.faint)),
                          ],
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
