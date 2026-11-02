import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show Node, highlight;
import 'package:highlight/languages/all.dart' show allLanguages;

/// Colours for code tokens. Each theme has its own, for light and dark.
@immutable
class SyntaxColors {
  const SyntaxColors({
    required this.keyword,
    required this.string,
    required this.number,
    required this.comment,
    required this.function,
    required this.type,
    required this.variable,
    required this.meta,
  });

  /// One hue per role, at a lightness that reads on a light or dark background.
  factory SyntaxColors.fromHues(List<double> hues, {required bool dark, required Color comment, double saturation = 0.55}) {
    Color c(int i) => HSLColor.fromAHSL(1, hues[i], saturation, dark ? 0.72 : 0.38).toColor();
    return SyntaxColors(
      keyword: c(0),
      string: c(1),
      number: c(2),
      function: c(3),
      type: c(4),
      variable: c(5),
      meta: c(6),
      comment: comment,
    );
  }

  final Color keyword, string, number, comment, function, type, variable, meta;

  /// The style for a highlight.js token class, or null to inherit.
  TextStyle? styleFor(String? className) => switch (className) {
        'keyword' || 'selector-tag' || 'doctag' || 'operator' => TextStyle(color: keyword),
        'string' || 'regexp' || 'char' || 'template-string' || 'link' => TextStyle(color: string),
        'number' || 'literal' || 'bullet' => TextStyle(color: number),
        'comment' || 'quote' => TextStyle(color: comment, fontStyle: FontStyle.italic),
        'title' || 'function' || 'section' => TextStyle(color: function),
        'built_in' || 'type' || 'class' || 'builtin-name' => TextStyle(color: type),
        'attr' || 'attribute' || 'variable' || 'params' || 'property' || 'template-variable' || 'symbol' => TextStyle(color: variable),
        'meta' || 'meta-keyword' || 'tag' || 'name' || 'selector-id' || 'selector-class' || 'subst' => TextStyle(color: meta),
        'emphasis' => const TextStyle(fontStyle: FontStyle.italic),
        'strong' => const TextStyle(fontWeight: FontWeight.w600),
        _ => null,
      };
}

// Fence names people write, mapped to highlight.js language ids.
const _aliases = {
  'sh': 'bash', 'shell': 'bash', 'zsh': 'bash', 'console': 'bash', 'shellsession': 'bash', //
  'ps1': 'powershell', 'pwsh': 'powershell', 'ps': 'powershell',
  'py': 'python', 'js': 'javascript', 'jsx': 'javascript', 'mjs': 'javascript',
  'ts': 'typescript', 'tsx': 'typescript', 'yml': 'yaml', 'kt': 'kotlin', 'kts': 'kotlin',
  'rs': 'rust', 'md': 'markdown', 'golang': 'go', 'html': 'xml', 'svg': 'xml', 'jsonc': 'json',
  'c++': 'cpp', 'cc': 'cpp', 'hpp': 'cpp', 'h': 'cpp', 'rb': 'ruby', 'docker': 'dockerfile',
  'proto': 'protobuf', 'tf': 'json', 'gradle': 'groovy', 'patch': 'diff',
};

// Parsed code, newest last; the parse is the slow part and code repeats on rebuilds.
final _parsed = <String, List<Node>?>{};

/// [code] as coloured spans for [lang], or null when the language is unknown.
List<InlineSpan>? highlightCode(String code, String lang, SyntaxColors colors) {
  final id = _aliases[lang.toLowerCase()] ?? lang.toLowerCase();
  if (!allLanguages.containsKey(id) || code.length > 60000) return null;
  final key = '$id\u0000$code';
  final nodes = _parsed.containsKey(key) ? _parsed[key] : _parse(code, id);
  if (!_parsed.containsKey(key)) {
    if (_parsed.length > 200) _parsed.remove(_parsed.keys.first);
    _parsed[key] = nodes;
  }
  if (nodes == null) return null;
  List<InlineSpan> spans(List<Node> ns) => [
        for (final n in ns)
          TextSpan(text: n.value, style: colors.styleFor(n.className), children: n.children == null ? null : spans(n.children!)),
      ];
  return spans(nodes);
}

List<Node>? _parse(String code, String lang) {
  try {
    return highlight.parse(code, language: lang).nodes;
  } catch (_) {
    return null; // an unknown language
  }
}
