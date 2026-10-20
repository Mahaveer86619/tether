import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';

/// Claude's AskUserQuestion: each question with its options, as single or
/// multiple choice, plus an answer in your own words.
class QuestionCard extends StatefulWidget {
  const QuestionCard({super.key, required this.approval, this.sessionTitle});

  final Approval approval;
  final String? sessionTitle;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final _picked = <String, Set<String>>{};
  final _other = <String, TextEditingController>{};

  TextEditingController _otherFor(String q) => _other.putIfAbsent(q, () => TextEditingController()..addListener(() => setState(() {})));

  @override
  void dispose() {
    for (final t in _other.values) {
      t.dispose();
    }
    super.dispose();
  }

  /// Each question's answer as Claude Code takes it: labels joined with ", ",
  /// with the user's own words last.
  Map<String, String> _answers(List<Question> qs) => {
        for (final q in qs)
          if (_answer(q).isNotEmpty) q.question: _answer(q),
      };

  String _answer(Question q) => [
        for (final o in q.options)
          if (_picked[q.question]?.contains(o.label) ?? false) o.label,
        if ((_other[q.question]?.text.trim() ?? '').isNotEmpty) _other[q.question]!.text.trim(),
      ].join(', ');

  void _toggle(Question q, String label) => setState(() {
        final set = _picked.putIfAbsent(q.question, () => {});
        if (q.multiSelect) {
          if (!set.remove(label)) set.add(label);
        } else {
          set
            ..clear()
            ..add(label);
          _other[q.question]?.clear();
        }
      });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = widget.approval;
    final qs = a.questions;
    final busy = context.select<HubCubit, bool>((cubit) => cubit.state.deciding.contains(a.id));
    final answers = _answers(qs);
    final complete = qs.isNotEmpty && answers.length == qs.length;
    return Container(
      key: const Key('question-card'),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.accent.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(qs.length == 1 ? 'Claude has a question' : 'Claude has ${qs.length} questions', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              Text(a.node, style: TextStyle(fontSize: 12, color: c.faint)),
            ],
          ),
          if (widget.sessionTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(widget.sessionTitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
            ),
          for (final q in qs) ...[
            const SizedBox(height: 12),
            if (q.header.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(6)),
                  child: Text(q.header, style: TextStyle(fontSize: 11.5, color: c.muted, fontWeight: FontWeight.w600)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(q.question, style: const TextStyle(fontSize: 14)),
            ),
            if (q.multiSelect) Text('Pick any', style: TextStyle(fontSize: 11.5, color: c.faint)),
            for (final o in q.options) _option(c, q, o),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextField(
                controller: _otherFor(q.question),
                onChanged: (v) {
                  if (!q.multiSelect && v.trim().isNotEmpty) setState(() => _picked[q.question]?.clear());
                },
                decoration: const InputDecoration(isDense: true, hintText: 'Or answer in your own words…'),
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
          ],
          if (qs.isEmpty) Text("This question couldn't be read. Skip it, or answer in the terminal.", style: TextStyle(fontSize: 13, color: c.muted)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Without answers Claude hears "did not answer" and carries on, rather than stopping as on a denial.
              TextButton(onPressed: busy ? null : () => context.read<HubCubit>().decide(a.id, allow: true), child: const Text('Skip')),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('answer-questions'),
                onPressed: busy || !complete ? null : () => context.read<HubCubit>().decide(a.id, allow: true, answers: answers),
                child: const Text('Answer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _option(TetherColors c, Question q, QuestionOption o) {
    final on = _picked[q.question]?.contains(o.label) ?? false;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _toggle(q, o.label),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              q.multiSelect
                  ? (on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                  : (on ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
              size: 18,
              color: on ? c.accent : c.faint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.label, style: TextStyle(fontSize: 13.5, fontWeight: on ? FontWeight.w600 : FontWeight.w500)),
                  if (o.description.isNotEmpty) Text(o.description, style: TextStyle(fontSize: 12, color: c.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
