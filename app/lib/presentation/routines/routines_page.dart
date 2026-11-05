import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../nav/nav_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'routines_cubit.dart';

/// What you keep asking for, read from the hub's history, and the skills made
/// from it. A routine can be drafted into a skill; a draft waits here for your
/// approval, and only an approved skill is used.
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
      listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null || a.draftedId != b.draftedId,
      listener: (context, s) {
        if (s.drafted.isNotEmpty && s.draftedId > 0) {
          showToast(context, 'Drafting the skill. It shows under Skills when it is ready.', icon: Icons.auto_awesome_rounded);
          context.read<NavCubit>().openSession(s.drafted);
        } else if (s.failure != null) {
          showFailure(context, s.failure!);
        }
      },
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
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              'Things you keep asking for. Draft a routine into a skill, check it, and Claude can run it instead of working it out each time.',
                              style: TextStyle(fontSize: 13, color: c.muted),
                            ),
                          ),
                        ),
                        IconButton(key: const Key('routines-refresh'), tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: s.loading ? null : cubit.load),
                      ],
                    ),
                    if (s.skills.isNotEmpty) ...[
                      SectionLabel('Skills', trailing: Pill('${s.skills.length}', color: c.accent)),
                      for (final skill in s.skills) _SkillCard(skill: skill, busy: s.busy.contains(skill.name)),
                      const SizedBox(height: 8),
                    ],
                    const SectionLabel('Routines'),
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
                        for (final r in report.routines)
                          _RoutineCard(
                            routine: r,
                            skill: s.skills.where((k) => k.source == r.example).firstOrNull,
                            drafting: s.busy.contains(r.example),
                          ),
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

// ---- skills ----

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill, required this.busy});

  final SkillInfo skill;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final k = skill;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: k.proposed ? c.warning.withValues(alpha: 0.6) : c.border),
          borderRadius: context.round(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('skill-${k.name}'),
          onTap: () => showSkill(context, k.name),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(k.proposed ? Icons.hourglass_top_rounded : Icons.check_circle_rounded, size: 17, color: k.proposed ? c.warning : c.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text(k.name, style: monoStyle(context, size: 14, color: c.text).copyWith(fontWeight: FontWeight.w600))),
                    if (busy) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) else Icon(Icons.chevron_right_rounded, size: 20, color: c.faint),
                  ],
                ),
                const SizedBox(height: 6),
                Text(k.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Pill(k.proposed ? 'Waiting for your approval' : 'In use', color: k.proposed ? c.warning : c.success),
                    Pill(k.mutating ? 'changes things' : 'read-only', color: k.mutating ? c.warning : null),
                    if (k.version > 1) Pill('version ${k.version}'),
                    if (k.updated != null) Pill('${ago(k.updated)} ago'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a skill: its text, why and how it changed, and the decisions.
Future<void> showSkill(BuildContext context, String name) {
  final cubit = context.read<RoutinesCubit>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(value: cubit, child: _SkillDialog(name: name)),
  );
}

class _SkillDialog extends StatefulWidget {
  const _SkillDialog({required this.name});

  final String name;

  @override
  State<_SkillDialog> createState() => _SkillDialogState();
}

class _SkillDialogState extends State<_SkillDialog> {
  late Future<SkillDetail?> _detail = context.read<RoutinesCubit>().detail(widget.name);
  int _shown = 0;

  void _reload() => setState(() {
        _shown = 0;
        _detail = context.read<RoutinesCubit>().detail(widget.name);
      });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<RoutinesCubit>();
    final busy = context.select<RoutinesCubit, bool>((x) => x.state.busy.contains(widget.name));
    return AlertDialog(
      key: const Key('skill-dialog'),
      title: Text(widget.name, style: monoStyle(context, size: 16, color: c.text).copyWith(fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 640,
        child: FutureBuilder<SkillDetail?>(
          future: _detail,
          builder: (context, snap) {
            final d = snap.data;
            if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            if (d == null) return const Text('This skill is no longer here.');
            final v = d.versions.isEmpty ? null : d.versions[(_shown == 0 ? d.versions.length : _shown) - 1];
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Pill(d.info.proposed ? 'Waiting for your approval' : 'In use', color: d.info.proposed ? c.warning : c.success),
                      Pill(d.info.mutating ? 'changes things' : 'read-only', color: d.info.mutating ? c.warning : null),
                    ],
                  ),
                  if (d.info.source.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Learned from "${d.info.source}"', style: TextStyle(fontSize: 12.5, color: c.muted)),
                    ),
                  if (d.info.mutating)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.1), borderRadius: context.round(8)),
                      child: Text('Some steps change things. Claude is told to confirm with you before it runs them.', style: TextStyle(fontSize: 12.5, color: c.text)),
                    ),
                  const SizedBox(height: 12),
                  if (v != null)
                    Container(
                      key: const Key('skill-text'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: c.codeBg, borderRadius: context.round(8), border: Border.all(color: c.border)),
                      child: SelectableText(v.text, style: monoStyle(context, size: 12, color: c.text)),
                    ),
                  if (d.versions.length > 1) ...[
                    const SizedBox(height: 12),
                    Text('Versions', style: TextStyle(fontSize: 11.5, color: c.faint, fontWeight: FontWeight.w600)),
                    for (final ver in d.versions.reversed)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: InkWell(
                                key: Key('skill-version-${ver.n}'),
                                onTap: () => setState(() => _shown = ver.n == d.versions.length ? 0 : ver.n),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Version ${ver.n}${ver.n == d.versions.length ? ' (in use)' : ''} · ${ver.by}${ver.at == null ? '' : ' · ${ago(ver.at)} ago'}',
                                      style: TextStyle(fontSize: 12.5, fontWeight: (_shown == 0 ? d.versions.length : _shown) == ver.n ? FontWeight.w600 : FontWeight.w500),
                                    ),
                                    if (ver.note.isNotEmpty) Text(ver.note, style: TextStyle(fontSize: 12, color: c.muted)),
                                  ],
                                ),
                              ),
                            ),
                            if (ver.n != d.versions.length && d.info.active)
                              TextButton(
                                key: Key('skill-rollback-${ver.n}'),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        await cubit.rollback(widget.name, ver.n);
                                        if (mounted) _reload();
                                      },
                                child: const Text('Go back to this'),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        FutureBuilder<SkillDetail?>(
          future: _detail,
          builder: (context, snap) {
            final d = snap.data;
            if (d == null) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  key: const Key('skill-dismiss'),
                  onPressed: busy
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          await cubit.dismiss(widget.name);
                          nav.pop();
                        },
                  child: Text(d.info.proposed ? 'Dismiss' : 'Remove'),
                ),
                if (d.info.proposed)
                  FilledButton(
                    key: const Key('skill-approve'),
                    onPressed: busy
                        ? null
                        : () async {
                            final nav = Navigator.of(context);
                            await cubit.approve(widget.name);
                            nav.pop();
                          },
                    child: const Text('Approve'),
                  ),
              ],
            );
          },
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

// ---- routines ----

/// A step by its short name; tap to see the whole command.
class _StepText extends StatefulWidget {
  const _StepText({required this.step});

  final RoutineStep step;

  @override
  State<_StepText> createState() => _StepTextState();
}

class _StepTextState extends State<_StepText> {
  bool _full = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.step;
    final isShell = s.key.startsWith('Bash:');
    final short = isShell && s.detail.isNotEmpty ? shellSummary(s.detail) : (s.detail.isEmpty ? s.key : s.detail);
    final canExpand = isShell && s.detail.trim() != short;
    return InkWell(
      onTap: canExpand ? () => setState(() => _full = !_full) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(short, maxLines: 1, overflow: TextOverflow.ellipsis, style: monoStyle(context, size: 12, color: c.muted)),
          if (_full)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(s.detail, style: monoStyle(context, size: 11.5, color: c.faint)),
            ),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatefulWidget {
  const _RoutineCard({required this.routine, required this.skill, required this.drafting});

  final Routine routine;

  /// The skill already drafted from this routine, if any.
  final SkillInfo? skill;
  final bool drafting;

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
        shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: context.round(12)),
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
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: widget.skill != null
                      ? OutlinedButton.icon(
                          key: Key('open-skill-${widget.skill!.name}'),
                          onPressed: () => showSkill(context, widget.skill!.name),
                          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: Text(widget.skill!.proposed ? 'Review the draft' : 'Skill: ${widget.skill!.name}'),
                        )
                      : FilledButton.tonalIcon(
                          key: Key('draft-${r.example.hashCode}'),
                          onPressed: widget.drafting ? null : () => context.read<RoutinesCubit>().draft(r.example),
                          icon: widget.drafting
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_awesome_outlined, size: 16),
                          label: const Text('Draft a skill'),
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
                            Expanded(child: _StepText(step: s)),
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
