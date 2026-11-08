import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../widgets/common.dart';
import 'tokens.dart';

/// A settings section that folds away: its title, how many things are in it,
/// and a line that says what it is while it is shut. Long lists stay out of
/// the way until you want them.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.count,
    this.summary = '',
    this.actions = const [],
    this.initiallyOpen = false,
  });

  final String title;
  final Widget child;

  /// Shown beside the title.
  final int? count;

  /// A line under the title while the section is shut.
  final String summary;

  /// Buttons at the end of the header; they work whether it is open or not.
  final List<Widget> actions;
  final bool initiallyOpen;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: context.round(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('section-${widget.title.toLowerCase()}'),
            borderRadius: context.round(12),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                            if (widget.count != null) ...[const SizedBox(width: Gap.sm), Pill('${widget.count}')],
                          ],
                        ),
                        if (!_open && widget.summary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(widget.summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.muted)),
                        ],
                      ],
                    ),
                  ),
                  ...widget.actions,
                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: c.muted),
                  const SizedBox(width: Gap.xs),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}
