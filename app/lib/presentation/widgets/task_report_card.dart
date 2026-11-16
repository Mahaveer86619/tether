import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../gen/tether/v1/render.pb.dart' as pb;
import '../nav/nav_cubit.dart';
import '../theme/theme.dart';
import '../ui/tokens.dart';
import 'common.dart';
import 'markdown_view.dart';

/// How tall a long report stays until it is opened.
const double _folded = 200;

/// What a task session reported when it finished: who did it and where, and
/// what it said, drawn like any reply (lists, tables, code) in a card of its
/// own, folded when long, with a way into the task's session.
class TaskReportCard extends StatefulWidget {
  const TaskReportCard({super.key, required this.report});

  final pb.TaskReport report;

  /// Whether a report is long enough to fold: a table, several blocks or a lot of text.
  static bool isLong(pb.TaskReport r) => r.blocks.any((b) => b.hasTable()) || r.blocks.length > 4 || r.blocks.fold<int>(0, (n, b) => n + b.writeToBuffer().length) > 700;

  @override
  State<TaskReportCard> createState() => _TaskReportCardState();
}

class _TaskReportCardState extends State<TaskReportCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = widget.report;
    final tone = r.failed ? c.danger : c.accent;
    final long = TaskReportCard.isLong(r);
    final where = [if (r.node.isNotEmpty) r.node, if (r.folder.isNotEmpty) r.folder];
    return Container(
      key: Key('task-report-${r.session}'),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: context.round(10),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: tone),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(r.failed ? Icons.error_outline_rounded : Icons.task_alt_rounded, size: 16, color: tone),
                        const SizedBox(width: Gap.sm),
                        Text(r.failed ? 'TASK FAILED' : 'TASK FINISHED', style: Type.label(context, color: tone)),
                        const Spacer(),
                        if (r.session.isNotEmpty)
                          TextButton(
                            key: const Key('task-report-open'),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: Gap.sm)),
                            onPressed: () => context.read<NavCubit>().openSession(r.session),
                            child: const Text('Open'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(r.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
                    if (where.isNotEmpty) ...[
                      const SizedBox(height: Gap.xs),
                      Wrap(spacing: Gap.sm, children: [for (final w in where) Pill(w, color: c.muted)]),
                    ],
                    if (r.detail.isNotEmpty) ...[
                      const SizedBox(height: Gap.sm),
                      Text(r.detail, style: TextStyle(fontSize: 13, color: c.danger)),
                    ],
                    if (r.blocks.isNotEmpty) ...[
                      const SizedBox(height: Gap.md),
                      _Body(blocks: r.blocks, folded: long && !_open),
                      if (long)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('task-report-more'),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                            onPressed: () => setState(() => _open = !_open),
                            icon: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                            label: Text(_open ? 'Show less' : 'Show all'),
                          ),
                        ),
                      if (_open && r.clipped)
                        Text('Cut short here. The rest is in the task\'s own session.', style: Type.meta(context, color: c.faint, size: 11.5)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The report's text, cut off with a fade when folded: laid out in full inside
/// a window that is at most [_folded] tall, and as short as the text if it is shorter.
class _Body extends StatelessWidget {
  const _Body({required this.blocks, required this.folded});

  final List<pb.Block> blocks;
  final bool folded;

  @override
  Widget build(BuildContext context) {
    final body = MarkdownView(blocks: blocks);
    if (!folded) return body;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _folded),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, 0.65, 1]).createShader(r),
        child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: body),
      ),
    );
  }
}
