import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/prompt_desk.dart';
import '../../injection.dart';
import '../theme/theme.dart';
import '../ui/motion.dart';
import '../ui/refresh.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'insights_cubit.dart';

/// What the hub measures about how Tether is used, and analyses by Claude
/// that recommend rules, skills and context changes. See
/// docs/plans/prompt-desk.md#insights.
class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key, required this.onSession});

  final ValueChanged<String> onSession;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<InsightsCubit>()..load(),
        child: InsightsView(onSession: onSession),
      );
}

class InsightsView extends StatelessWidget {
  const InsightsView({super.key, required this.onSession});

  final ValueChanged<String> onSession;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MultiBlocListener(
      listeners: [
        BlocListener<InsightsCubit, InsightsState>(
          listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
          listener: (context, s) => showFailure(context, s.failure!),
        ),
        BlocListener<InsightsCubit, InsightsState>(
          listenWhen: (a, b) => a.noticeId != b.noticeId,
          listener: (context, s) => showToast(context, s.notice, icon: Icons.auto_awesome_rounded),
        ),
        BlocListener<InsightsCubit, InsightsState>(
          listenWhen: (a, b) => a.openSessionId != b.openSessionId,
          listener: (context, s) => onSession(s.openSession),
        ),
      ],
      child: BlocBuilder<InsightsCubit, InsightsState>(
        builder: (context, s) {
          final cubit = context.read<InsightsCubit>();
          final st = s.stats;
          final side = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 16.0;
          return PullRefresh(
            onRefresh: cubit.load,
            child: ListView(
              padding: EdgeInsets.fromLTRB(side, 8, side, bottomRoom(context)),
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
                                  'How you use Tether, measured from what the hub saved. Ask Claude to read it and recommend rules, skills and changes.',
                                  style: TextStyle(fontSize: 13, color: c.muted),
                                ),
                              ),
                            ),
                            IconButton(key: const Key('insights-refresh'), tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: s.loading ? null : cubit.load),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(key: const Key('insights-recent'), label: const Text('Last 30 days'), selected: !s.allTime, onSelected: (_) => cubit.setAllTime(false)),
                            ChoiceChip(key: const Key('insights-all'), label: const Text('All history'), selected: s.allTime, onSelected: (_) => cubit.setAllTime(true)),
                          ],
                        ),
                        if (st == null)
                          const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))
                        else ...[
                          _AnalyzeCard(stats: st, busy: s.analyzing || s.running),
                          if (s.reports.isNotEmpty) ...[
                            SectionLabel('Analyses', trailing: Pill('${s.reports.length}')),
                            for (final r in s.reports) _ReportCard(report: r, onSession: onSession),
                          ],
                          ..._statSections(context, st, s),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _statSections(BuildContext context, InsightStats st, InsightsState s) {
    final c = context.colors;
    final cubit = context.read<InsightsCubit>();
    if (st.chats == 0 && st.tokenSessions == 0 && st.toolCalls == 0) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 32),
          child: EmptyState(icon: Icons.query_stats_rounded, title: 'Nothing to measure yet', body: 'Insights appear once chats have run in this window.'),
        ),
      ];
    }
    final lineage = st.lineage.map((l) => '${l.count} ${l.label}').join(', ');
    final phrases = st.phrases.where((p) => p.prompts > 0).toList();
    return [
      const SectionLabel('Chats'),
      _Tiles(children: [
        _Stat('stat-chats', 'Chats', '${st.chats}', '${st.messages} messages, ${st.prompts} of them yours'),
        _Stat('stat-messages', 'Messages per chat', '${st.messagesPerChat.median}', 'median; 90% under ${st.messagesPerChat.p90}, longest ${st.messagesPerChat.max}'),
        _Stat('stat-prompts', 'Your prompts per chat', '${st.promptsPerChat.median}', 'median; longest chat ${st.promptsPerChat.max}'),
        _Stat('stat-sessions', 'Chats over several sessions', '${st.multiSessionChats}', lineage.isEmpty ? 'no moves or forks' : lineage),
        _Stat('stat-restarts', 'Restarts', '${st.restarts}', 'prompts asked again within 8; ${st.repeatedPrompts} word for word'),
        _Stat('stat-long', 'Long messages as files', '${st.longAsFile}', 'prompt length median ${st.promptLength.median} characters'),
      ]),
      if (st.promptLengths.any((b) => b.count > 0)) _Bars(key: const Key('bars-lengths'), title: 'Prompt length (characters)', rows: st.promptLengths),
      if (st.restartsBack.isNotEmpty) _Bars(key: const Key('bars-restarts'), title: 'Restarts, by how many prompts back', rows: [for (final r in st.restartsBack) Counted('${r.label} back', r.count)]),
      const SectionLabel('Context and cost'),
      _Tiles(children: [
        _Stat('stat-tokens', 'Tokens', tokens(st.input + st.output + st.cacheWrite + st.cacheRead), 'over ${st.tokenSessions} sessions; median ${tokens(st.perSession.median)} each'),
        _Stat('stat-cache', 'Cache reads', '${(st.cacheReadShare * 100).round()}%', 'of what was sent in: long contexts re-read every turn'),
        _Stat('stat-cost', 'Cost, estimated', '\$${st.costUsd.toStringAsFixed(2)}', st.unpriced > 0 ? 'list prices; ${st.unpriced} messages unpriced' : 'from list prices, not a bill'),
      ]),
      if (st.topSessions.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text('Heaviest sessions', style: TextStyle(fontSize: 12, color: c.faint))),
        for (final t in st.topSessions)
          ListTile(
            key: Key('top-${t.session}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t.title.isEmpty ? t.session : t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${t.messages} replies · ${shortModel(t.model)}'),
            trailing: Text(tokens(t.total), style: monoStyle(context, size: 13)),
            onTap: () => onSession(t.session),
          ),
      ],
      const SectionLabel('Tools and approvals'),
      _Tiles(children: [
        _Stat('stat-tools', 'Tool calls', '${st.toolCalls}', '${st.toolErrors} failed'),
        _Stat('stat-approvals', 'Approvals', '${st.allowed + st.denied}', '${st.allowed} allowed, ${st.denied} denied'),
        if (st.models.isNotEmpty) _Stat('stat-models', 'Models', '${st.models.length}', st.models.take(3).map((m) => '${shortModel(m.label)} ${m.count}').join(', ')),
      ]),
      if (st.tools.isNotEmpty) _Bars(key: const Key('bars-tools'), title: 'Most used tools (failed in red)', rows: [for (final t in st.tools.take(8)) Counted(t.name, t.calls)], errors: [for (final t in st.tools.take(8)) t.errors]),
      if (phrases.isNotEmpty) ...[
        const SectionLabel('Instructions you repeat'),
        for (final p in phrases)
          ListTile(
            key: Key('phrase-${p.label}'),
            contentPadding: EdgeInsets.zero,
            title: Text(p.label),
            subtitle: Text('${p.prompts} prompts in ${p.chats} chats'),
            trailing: s.done.contains('phrases/rule/${p.label}')
                ? Icon(Icons.check_rounded, color: c.success)
                : TextButton(
                    key: Key('phrase-rule-${p.label}'),
                    onPressed: s.busy.contains('phrases/rule/${p.label}') ? null : () => cubit.addPhraseRule(p),
                    child: const Text('Make it a rule'),
                  ),
          ),
      ],
    ];
  }
}

class _AnalyzeCard extends StatelessWidget {
  const _AnalyzeCard({required this.stats, required this.busy});

  final InsightStats stats;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: context.round(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Claude reads these numbers and ${stats.sampleMessages} masked messages from ${stats.sampleChats} chats, then says what is wasteful and what to change.',
                  style: TextStyle(fontSize: 13, color: c.muted),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('analyze'),
                onPressed: busy || stats.sampleMessages == 0 ? null : () => _confirm(context),
                child: Text(busy ? 'Analysing…' : 'Analyze with Claude'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final cubit = context.read<InsightsCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('analyze-dialog'),
        title: const Text('Analyze with Claude?'),
        content: Text(
          'A session on the hub\'s machine, on its Claude account, gets the stats above and a sample of '
          '${stats.sampleMessages} messages from the ${stats.sampleChats} most recent chats (at most 20 each, clipped). '
          'Paths, addresses, host and device names, ids, emails and anything that looks like a secret are masked first. '
          'It saves a report here; nothing is changed for you.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(key: const Key('analyze-confirm'), onPressed: () => Navigator.pop(context, true), child: const Text('Analyze')),
        ],
      ),
    );
    if (ok == true) await cubit.analyze();
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onSession});

  final InsightReport report;
  final ValueChanged<String> onSession;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = report;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        key: Key('report-${r.id}'),
        color: c.surface,
        shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: context.round(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (r.running) const Padding(padding: EdgeInsets.only(right: 8), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
                  Expanded(
                    child: Text(r.running ? 'Claude is analysing…' : r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  if (r.session.isNotEmpty)
                    TextButton(key: Key('report-session-${r.id}'), onPressed: () => onSession(r.session), child: const Text('Open session')),
                ],
              ),
              Wrap(spacing: 6, runSpacing: 4, children: [
                Pill(r.days == 0 ? 'all history' : 'last ${r.days} days'),
                Pill('${r.sampleMessages} messages sampled'),
                if (r.saved != null) Pill('${ago(r.saved)} ago') else if (r.started != null) Pill('started ${ago(r.started)} ago'),
              ]),
              if (r.summary.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: SelectableText(r.summary, style: const TextStyle(fontSize: 13, height: 1.4))),
              for (final rec in r.recommendations) _RecommendationTile(report: r, rec: rec),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.report, required this.rec});

  final InsightReport report;
  final Recommendation rec;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final key = recKey(report, rec);
    final s = context.watch<InsightsCubit>().state;
    final cubit = context.read<InsightsCubit>();
    final done = s.done.contains(key);
    final busy = s.busy.contains(key);
    final (icon, label) = switch (rec.kind) {
      RecommendationKind.rule => (Icons.rule_rounded, 'Rule'),
      RecommendationKind.skill => (Icons.auto_awesome_outlined, 'Skill'),
      RecommendationKind.context => (Icons.layers_outlined, 'Context'),
    };
    Widget action;
    if (done) {
      action = Icon(Icons.check_rounded, color: c.success, key: Key('rec-done-${rec.title}'));
    } else {
      action = switch (rec.kind) {
        RecommendationKind.rule => FilledButton.tonal(key: Key('rec-rule-${rec.title}'), onPressed: busy ? null : () => cubit.addRule(report, rec), child: const Text('Add rule')),
        RecommendationKind.skill => FilledButton.tonal(key: Key('rec-skill-${rec.title}'), onPressed: busy ? null : () => cubit.draftSkill(report, rec), child: const Text('Draft skill')),
        RecommendationKind.context => TextButton(
            key: Key('rec-copy-${rec.title}'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: rec.text));
              showToast(context, 'Copied');
            },
            child: const Text('Copy'),
          ),
      };
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(color: c.raised, borderRadius: context.round(10)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 18, color: c.accent)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Pill(label, color: c.accent),
                    const SizedBox(width: 6),
                    Expanded(child: Text(rec.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ]),
                  const SizedBox(height: 4),
                  SelectableText(rec.text, style: TextStyle(fontSize: 13, color: c.text)),
                  if (rec.why.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(rec.why, style: TextStyle(fontSize: 12, color: c.faint))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            action,
          ],
        ),
      ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 720 ? 3 : (box.maxWidth >= 420 ? 2 : 1);
          final width = (box.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final w in children) SizedBox(width: width, child: w)]);
        },
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.id, this.label, this.value, this.detail);

  final String id, label, value, detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      key: Key(id),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: context.round(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.faint)),
        ],
      ),
    );
  }
}

/// Horizontal bars with their counts written out; [errors] marks a failed
/// share of each bar.
class _Bars extends StatelessWidget {
  const _Bars({super.key, required this.title, required this.rows, this.errors});

  final String title;
  final List<Counted> rows;
  final List<int>? errors;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final most = rows.fold<int>(1, (m, r) => r.count > m ? r.count : m);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: c.faint)),
          const SizedBox(height: 6),
          for (final (i, r) in rows.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 120, child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final w = box.maxWidth * r.count / most;
                        final bad = errors == null || r.count == 0 ? 0.0 : w * errors![i] / r.count;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: w - bad, height: 12, decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(3))),
                            if (bad > 0) Container(width: bad, height: 12, decoration: BoxDecoration(color: c.danger.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(3))),
                          ]),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 56, child: Text('${r.count}', textAlign: TextAlign.right, style: monoStyle(context, size: 12))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
