import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'usage_cubit.dart';

/// The plan's limits and the tokens used per machine and session. Each
/// machine uses only its own Claude login; this only reports.
class UsagePage extends StatelessWidget {
  const UsagePage({super.key, required this.onSession});

  final ValueChanged<String> onSession;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<UsageCubit>()..start(),
        child: _UsageBody(onSession: onSession),
      );
}

class _UsageBody extends StatelessWidget {
  const _UsageBody({required this.onSession});

  final ValueChanged<String> onSession;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hub = context.select<HubCubit, HubSnapshot>((h) => h.state.hub);
    return BlocConsumer<UsageCubit, UsageState>(
      listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
      listener: (context, s) => showFailure(context, s.failure!),
      builder: (context, s) {
        final summary = s.summary;
        if (summary == null) return const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)));
        // Machines on one Claude account report the same limits: one card each.
        final accounts = <List<NodeUsage>>[];
        for (final n in summary.nodes) {
          final p = n.plan;
          if (p == null) continue;
          final same = accounts.where((a) => a.first.plan!.sameAccountAs(p)).firstOrNull;
          same == null ? accounts.add([n]) : same.add(n);
        }
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
                    const SectionLabel('Claude plan'),
                    if (accounts.isEmpty)
                      Text('Waiting for the machines to report their limits.', style: TextStyle(color: c.muted, fontSize: 13))
                    else
                      for (final nodes in accounts) Padding(padding: const EdgeInsets.only(bottom: 10), child: _PlanCard(nodes: nodes)),
                    const SectionLabel('Tokens by machine'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Read from the Claude Code transcripts on each machine. Counted = input + output + cache writes; cache reads are shown apart.',
                        style: TextStyle(color: c.muted, fontSize: 13),
                      ),
                    ),
                    if (summary.nodes.isEmpty) Text('No usage yet.', style: TextStyle(color: c.muted)),
                    for (final n in summary.nodes)
                      Padding(padding: const EdgeInsets.only(bottom: 10), child: _NodeCard(usage: n, online: hub.nodes[n.node]?.online ?? false)),
                    SectionLabel('Sessions this week', trailing: Text('${summary.sessions.length}', style: TextStyle(color: c.faint, fontSize: 12))),
                    for (final u in summary.sessions)
                      _SessionRow(usage: u, session: hub.sessions[u.session], onTap: () => onSession(u.session)),
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

/// One Claude account's limits, as Claude Code's /usage reports them.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.nodes});

  final List<NodeUsage> nodes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final plan = nodes.first.plan!;
    final checked = [for (final n in nodes) n.plan!.checked].whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(nodes.map((n) => n.node).join(' · '), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              if (checked != null) Text('checked ${ago(checked)}', style: TextStyle(fontSize: 12, color: c.faint)),
            ],
          ),
          const SizedBox(height: 4),
          if (nodes.length > 1)
            Text('Same Claude account, so the same limits.', style: TextStyle(fontSize: 12, color: c.faint)),
          if (plan.limits.isEmpty) ...[
            const SizedBox(height: 8),
            Text(plan.error.isNotEmpty ? plan.error : 'No limits in /usage.', style: TextStyle(fontSize: 13, color: c.muted)),
            if (plan.raw.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(8)),
                child: SelectableText(plan.raw, style: monoStyle(context, size: 12, color: c.muted)),
              ),
            ],
          ] else
            for (final l in plan.limits) _LimitBar(limit: l),
        ],
      ),
    );
  }
}

class _LimitBar extends StatelessWidget {
  const _LimitBar({required this.limit});

  final PlanLimit limit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = limit;
    final color = l.percent >= 90 ? c.danger : (l.percent >= 70 ? c.warning : c.success);
    final label = 'Current ${l.label}';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label[0].toUpperCase() + label.substring(1), style: const TextStyle(fontSize: 13.5))),
              Text('${l.percent}% used', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (l.percent / 100).clamp(0, 1).toDouble(), minHeight: 6, backgroundColor: c.raised, color: color),
          ),
          if (l.resets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Resets ${l.resets}', style: TextStyle(fontSize: 12, color: c.faint)),
            ),
        ],
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.usage, required this.online});

  final NodeUsage usage;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final u = usage;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(u.node, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(width: 8),
              OnlineDot(online: online),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tokens(u.window.counted), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('in the last 5 hours', overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _Figure('Today', tokens(u.today.counted)),
              _Figure('7 days', tokens(u.week.counted)),
              _Figure('5 hours · messages', '${u.window.messages}'),
              _Figure('5 hours · cache reads', tokens(u.window.cacheRead)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);

  final String label, value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: context.colors.faint)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.usage, required this.session, required this.onTap});

  final SessionUsage usage;
  final Session? session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: s == null ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s?.displayTitle ?? 'Session no longer listed', maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    [if (s != null) s.node, if (s != null && s.cwd.isNotEmpty) baseName(s.cwd), '${usage.total.messages} messages', ago(usage.last)].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.faint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(tokens(usage.total.counted), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
