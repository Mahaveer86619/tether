import 'package:flutter/material.dart';

import '../../domain/entities/entities.dart';
import '../theme/theme.dart';
import '../ui/tokens.dart';

/// The `/word` being typed at the cursor, if any: where it starts and the
/// word without the slash. A slash inside a word or a path doesn't count.
({int start, String query})? slashAt(TextEditingValue v) {
  final end = v.selection.isValid && v.selection.isCollapsed ? v.selection.baseOffset : v.text.length;
  if (end < 0 || end > v.text.length) return null;
  final before = v.text.substring(0, end);
  final start = before.lastIndexOf('/');
  if (start < 0 || (start > 0 && !RegExp(r'\s').hasMatch(before[start - 1]))) return null;
  final query = before.substring(start + 1);
  if (query.contains(RegExp(r'\s'))) return null;
  return (start: start, query: query);
}

/// The skills that fit what follows `/`, name over description; tap to pick.
class SkillPickerList extends StatelessWidget {
  const SkillPickerList({super.key, required this.results, required this.onPick, this.loading = false});

  final List<SkillMatch> results;
  final ValueChanged<String> onPick;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (results.isEmpty) {
      return Padding(
        key: const Key('skill-picker'),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(loading ? 'Looking…' : 'No approved skill fits', style: Type.meta(context, color: c.faint)),
      );
    }
    return Container(
      key: const Key('skill-picker'),
      constraints: const BoxConstraints(maxHeight: 240),
      margin: const EdgeInsets.only(bottom: 4, right: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 4),
        children: [
          for (final (i, m) in results.take(8).indexed)
            InkWell(
              key: Key('skill-pick-${m.name}'),
              borderRadius: context.round(8),
              onTap: () => onPick(m.name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: i == 0 ? BoxDecoration(color: c.raised, borderRadius: context.round(8)) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('/${m.name}', style: Type.meta(context, color: c.text).copyWith(fontWeight: FontWeight.w600)),
                    if (m.description.isNotEmpty)
                      Text(m.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The skill a message will be done with, above the text; × takes it off.
class SkillChip extends StatelessWidget {
  const SkillChip({super.key, required this.name, required this.onRemove});

  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 2),
        child: InputChip(
          key: const Key('skill-chip'),
          avatar: Icon(Icons.bolt_rounded, size: 16, color: c.accent),
          label: Text('Skill: $name', style: Type.meta(context, color: c.text)),
          tooltip: 'Claude follows this skill, at its current version, for this message',
          onDeleted: onRemove,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
