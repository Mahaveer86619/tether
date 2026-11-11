import 'package:flutter/material.dart';

import '../../gen/tether/v1/render.pb.dart' hide Divider;
import '../theme/syntax.dart';
import '../theme/theme.dart';
import '../ui/tokens.dart';
import 'common.dart';

/// One edit or write a session made to a file.
class FileChunk {
  const FileChunk({required this.itemId, required this.diff, required this.added, required this.removed, required this.running, required this.created});

  final String itemId;

  /// A unified diff for an edit, or the new file's text for a write.
  final String diff;
  final int added, removed;
  final bool running;

  /// A write of a whole file, shown as it is rather than as a diff.
  final bool created;
}

/// Everything a session did to one file, in order.
class FileChange {
  FileChange(this.path, this.chunks, {this.lastTouched = 0});

  final String path;
  final List<FileChunk> chunks;

  /// Where its latest change sits among all the changes, for finding the newest.
  final int lastTouched;

  String get name => path.split(RegExp(r'[\\/]')).last;
  int get added => chunks.fold(0, (a, c) => a + c.added);
  int get removed => chunks.fold(0, (a, c) => a + c.removed);
  bool get running => chunks.any((c) => c.running);

  /// The highlight.js language for the file's extension; unknown ones show plain.
  String get lang {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }
}

/// The files a session has edited or written, in the order they were first
/// touched, with each file's changes. Reads the same timeline items the chat
/// draws.
List<FileChange> fileChanges(Iterable<TimelineItem> items) {
  final byPath = <String, List<FileChunk>>{};
  final touched = <String, int>{};
  var n = 0;
  for (final it in items) {
    if (it.whichKind() != TimelineItem_Kind.tool) continue;
    final t = it.tool;
    final running = t.status == ToolCard_Status.STATUS_RUNNING || t.status == ToolCard_Status.STATUS_PENDING;
    if (t.status == ToolCard_Status.STATUS_FAILED) continue;
    if (t.hasEdit() && t.edit.path.isNotEmpty) {
      byPath.putIfAbsent(t.edit.path, () => []).add(FileChunk(itemId: it.itemId, diff: t.edit.unifiedDiff, added: t.edit.added, removed: t.edit.removed, running: running, created: false));
      touched[t.edit.path] = n++;
    } else if (t.hasWrite() && t.write.path.isNotEmpty) {
      byPath.putIfAbsent(t.write.path, () => []).add(FileChunk(itemId: it.itemId, diff: t.write.preview, added: t.write.lines, removed: 0, running: running, created: true));
      touched[t.write.path] = n++;
    }
  }
  return [for (final e in byPath.entries) FileChange(e.key, e.value, lastTouched: touched[e.key]!)];
}

/// A live view of the files a session is changing: a tab for each, and the
/// file's changes as coloured, syntax-highlighted diffs. It follows the newest
/// change while the session works, until you pick a file yourself.
class ChangesPane extends StatefulWidget {
  const ChangesPane({super.key, required this.items, this.working = false});

  final Iterable<TimelineItem> items;
  final bool working;

  @override
  State<ChangesPane> createState() => _ChangesPaneState();
}

class _ChangesPaneState extends State<ChangesPane> {
  /// How many files get a tab; the older ones are in a menu.
  static const _tabs = 6;

  String? _picked;
  String _lastSeen = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Newest first, so what Claude just touched is always the first tab.
    final files = fileChanges(widget.items)..sort((a, b) => b.lastTouched.compareTo(a.lastTouched));
    if (files.isEmpty) {
      return Container(
        key: const Key('changes-pane'),
        color: c.codeBg,
        child: const EmptyState(icon: Icons.difference_outlined, title: 'No file changes yet', body: 'Files Claude edits or writes show up here as it works.'),
      );
    }
    // The newest change is what to follow; a new one takes the view back to it.
    final latest = files.reduce((a, b) => a.lastTouched >= b.lastTouched ? a : b);
    final seen = '${latest.path}:${latest.chunks.length}';
    if (_lastSeen != seen) {
      _lastSeen = seen;
      _picked = null;
    }
    final shown = files.firstWhere((f) => f.path == _picked, orElse: () => latest);
    final pinnedOld = files.indexOf(shown) >= _tabs;
    final following = _picked == null;
    return Container(
      key: const Key('changes-pane'),
      color: c.codeBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
            child: Row(
              children: [
                Text('FILES CHANGED', style: Type.label(context)),
                const SizedBox(width: Gap.sm),
                Text('${files.length}', style: Type.meta(context, color: c.accent)),
                const Spacer(),
                Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(following ? Icons.my_location_rounded : Icons.location_disabled_rounded, size: 13, color: following ? c.accent : c.faint),
                      const SizedBox(width: 4),
                      Text(following ? 'following' : 'pinned', style: Type.meta(context, color: following ? c.accent : c.faint, size: 11.5)),
                    ],
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 6),
                    children: [
                      for (final f in [...files.take(pinnedOld ? _tabs - 1 : _tabs), if (pinnedOld) shown])
                        _Tab(file: f, selected: f.path == shown.path, onTap: () => setState(() => _picked = f.path)),
                    ],
                  ),
                ),
                if (files.length > _tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: Gap.sm),
                    child: PopupMenuButton<String>(
                      key: const Key('more-changed-files'),
                      tooltip: 'Older changed files',
                      onSelected: (path) => setState(() => _picked = path),
                      itemBuilder: (_) => [
                        for (final f in files.skip(_tabs - (pinnedOld ? 1 : 0)).where((f) => f.path != shown.path))
                          PopupMenuItem(value: f.path, child: Text(f.name, style: Type.meta(context, color: c.text, size: 12.5))),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
                        decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: context.round(8)),
                        child: Text('${files.length - _tabs} older', style: Type.meta(context, color: c.muted, size: 12.5)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(child: _FileBody(key: ValueKey('file-${shown.path}'), file: shown, follow: following)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.file, required this.selected, required this.onTap});

  final FileChange file;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: Gap.xs),
      child: InkWell(
        key: Key('change-tab-${file.path}'),
        borderRadius: context.round(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? c.raised : Colors.transparent,
            border: Border.all(color: selected ? c.accent.withValues(alpha: 0.6) : c.border),
            borderRadius: context.round(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (file.running) ...[const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)), const SizedBox(width: 6)],
              Text(file.name, style: Type.meta(context, color: selected ? c.text : c.muted, size: 12.5)),
              const SizedBox(width: Gap.sm),
              if (file.added > 0) Text('+${file.added}', style: Type.meta(context, color: c.success, size: 11.5)),
              if (file.removed > 0) ...[const SizedBox(width: 4), Text('−${file.removed}', style: Type.meta(context, color: c.danger, size: 11.5))],
            ],
          ),
        ),
      ),
    );
  }
}

class _FileBody extends StatefulWidget {
  const _FileBody({super.key, required this.file, required this.follow});

  final FileChange file;
  final bool follow;

  @override
  State<_FileBody> createState() => _FileBodyState();
}

class _FileBodyState extends State<_FileBody> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(_FileBody old) {
    super.didUpdateWidget(old);
    if (widget.follow && widget.file.chunks.length != old.file.chunks.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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
    final f = widget.file;
    return SelectionArea(
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(Gap.md),
        children: [
          Text(f.path, style: Type.meta(context, color: c.muted, size: 12)),
          const SizedBox(height: 2),
          Text('${f.chunks.length} ${f.chunks.length == 1 ? 'change' : 'changes'}  ·  +${f.added} −${f.removed}', style: Type.meta(context, color: c.faint, size: 11.5)),
          const SizedBox(height: Gap.md),
          for (final (i, k) in f.chunks.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: k.created ? _Written(chunk: k, lang: f.lang) : _Diff(chunk: k, lang: f.lang, number: i + 1, of: f.chunks.length),
            ),
        ],
      ),
    );
  }
}

/// One diff, each line coloured by what happened to it and its code
/// highlighted for the file's language.
class _Diff extends StatelessWidget {
  const _Diff({required this.chunk, required this.lang, required this.number, required this.of});

  final FileChunk chunk;
  final String lang;
  final int number, of;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = chunk.diff.split('\n').where((l) => !l.startsWith('+++') && !l.startsWith('---')).toList();
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    return Container(
      decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: context.round(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: c.surface,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 5),
            child: Row(
              children: [
                Text(of > 1 ? 'CHANGE $number OF $of' : 'CHANGE', style: Type.label(context, color: c.faint)),
                const Spacer(),
                if (chunk.running) const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)) else Text('+${chunk.added} −${chunk.removed}', style: Type.meta(context, color: c.faint, size: 11.5)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final l in lines) _line(context, l)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String l) {
    final c = context.colors;
    final style = monoStyle(context, size: 12, color: c.text);
    if (l.startsWith('@@')) {
      return Container(color: c.info.withValues(alpha: 0.08), padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 2), child: Text(l, style: style.copyWith(color: c.info)));
    }
    final sign = l.isEmpty ? ' ' : l[0];
    final code = l.isEmpty ? '' : l.substring(1);
    final spans = highlightCode(code, lang, c.syntax);
    return Container(
      color: sign == '+' ? c.diffAdd : (sign == '-' ? c.diffRemove : null),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 1),
      child: Text.rich(
        TextSpan(style: style, children: [
          TextSpan(text: '${sign == '+' || sign == '-' ? sign : ' '} ', style: TextStyle(color: sign == '+' ? c.success : (sign == '-' ? c.danger : c.faint))),
          if (spans != null) ...spans else TextSpan(text: code),
        ]),
      ),
    );
  }
}

/// A whole file that was written: its text with line numbers, highlighted.
class _Written extends StatelessWidget {
  const _Written({required this.chunk, required this.lang});

  final FileChunk chunk;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = chunk.diff.split('\n');
    final shown = lines.take(80).toList();
    final style = monoStyle(context, size: 12, color: c.text);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: context.round(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: c.surface,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 5),
            child: Row(children: [Text('WRITTEN', style: Type.label(context, color: c.faint)), const Spacer(), Text('${chunk.added} lines', style: Type.meta(context, color: c.faint, size: 11.5))]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
              child: Text.rich(
                TextSpan(style: style, children: [
                  for (final (i, l) in shown.indexed) ...[
                    TextSpan(text: '${(i + 1).toString().padLeft(3)}  ', style: TextStyle(color: c.faint)),
                    ...(highlightCode(l, lang, c.syntax) ?? [TextSpan(text: l)]),
                    const TextSpan(text: '\n'),
                  ],
                  if (lines.length > shown.length) TextSpan(text: '     … ${lines.length - shown.length} more lines', style: TextStyle(color: c.faint)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
