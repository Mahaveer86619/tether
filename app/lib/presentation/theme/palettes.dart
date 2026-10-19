import 'package:flutter/material.dart';

import 'syntax.dart';
import 'theme.dart';

/// A named app theme: colours for light and dark, code colours included.
class Palette {
  const Palette(this.id, this.name, this.light, this.dark);

  final String id, name;
  final TetherColors light, dark;

  TetherColors of(Brightness b) => b == Brightness.light ? light : dark;
}

Palette paletteById(String id) => palettes.firstWhere((p) => p.id == id, orElse: () => palettes.first);

/// Accent colours offered on top of any palette.
const accentChoices = <Color>[
  Color(0xFFC2603E), Color(0xFFD08A2E), Color(0xFF3E8E5A), Color(0xFF2E8C8C), //
  Color(0xFF2F6FB0), Color(0xFF6A55C2), Color(0xFFB23A6A), Color(0xFF5B6472),
];

final palettes = <Palette>[
  const Palette('claude', 'Claude', TetherColors.light, TetherColors.dark),
  _tinted('ocean', 'Ocean', hue: 212, saturation: 0.18, accentLight: const Color(0xFF2A6FB0), accentDark: const Color(0xFF6AA8E8),
      syntaxHues: [275, 140, 28, 205, 175, 335, 220]),
  _tinted('forest', 'Forest', hue: 140, saturation: 0.12, accentLight: const Color(0xFF2F7D4F), accentDark: const Color(0xFF6CC08A),
      syntaxHues: [22, 95, 42, 165, 200, 330, 120]),
  _tinted('rose', 'Rose', hue: 340, saturation: 0.12, accentLight: const Color(0xFFB23A6A), accentDark: const Color(0xFFE87AA4),
      syntaxHues: [325, 150, 30, 255, 195, 12, 290]),
  _tinted('graphite', 'Graphite', hue: 220, saturation: 0.05, accentLight: const Color(0xFF4A5568), accentDark: const Color(0xFFA9B4C6),
      syntaxHues: [265, 150, 35, 210, 185, 340, 230], syntaxSaturation: 0.35),
  _solarized,
];

/// A palette whose neutrals are one hue at low saturation.
Palette _tinted(
  String id,
  String name, {
  required double hue,
  required double saturation,
  required Color accentLight,
  required Color accentDark,
  required List<double> syntaxHues,
  double syntaxSaturation = 0.55,
}) {
  TetherColors make(bool dark) {
    Color n(double l) => HSLColor.fromAHSL(1, hue, saturation, l).toColor();
    final base = dark ? TetherColors.dark : TetherColors.light;
    final faint = dark ? n(0.48) : n(0.60);
    return base.copyWith(
      canvas: dark ? n(0.145) : n(0.975),
      sidebar: dark ? n(0.115) : n(0.945),
      surface: dark ? n(0.185) : n(0.995),
      raised: dark ? n(0.215) : n(0.925),
      border: dark ? n(0.245) : n(0.87),
      text: dark ? n(0.92) : n(0.12),
      muted: dark ? n(0.67) : n(0.40),
      faint: faint,
      accent: dark ? accentDark : accentLight,
      codeBg: dark ? n(0.105) : n(0.955),
      userBubble: dark ? n(0.225) : n(0.925),
      syntax: SyntaxColors.fromHues(syntaxHues, dark: dark, comment: faint, saturation: syntaxSaturation),
    );
  }

  return Palette(id, name, make(false), make(true));
}

// Solarized keeps its own fixed colours in both modes.
const _solarSyntax = SyntaxColors(
  keyword: Color(0xFF859900),
  string: Color(0xFF2AA198),
  number: Color(0xFFD33682),
  comment: Color(0xFF93A1A1),
  function: Color(0xFF268BD2),
  type: Color(0xFFB58900),
  variable: Color(0xFF6C71C4),
  meta: Color(0xFFCB4B16),
);

final _solarized = Palette(
  'solarized',
  'Solarized',
  TetherColors.light.copyWith(
    canvas: const Color(0xFFFDF6E3),
    sidebar: const Color(0xFFEEE8D5),
    surface: const Color(0xFFFFFBEF),
    raised: const Color(0xFFEEE8D5),
    border: const Color(0xFFDDD6C1),
    text: const Color(0xFF073642),
    muted: const Color(0xFF586E75),
    faint: const Color(0xFF93A1A1),
    accent: const Color(0xFFCB4B16),
    codeBg: const Color(0xFFF5EEDB),
    userBubble: const Color(0xFFEEE8D5),
    syntax: _solarSyntax,
  ),
  TetherColors.dark.copyWith(
    canvas: const Color(0xFF002B36),
    sidebar: const Color(0xFF00212B),
    surface: const Color(0xFF073642),
    raised: const Color(0xFF0A4050),
    border: const Color(0xFF0E4A5A),
    text: const Color(0xFFEEE8D5),
    muted: const Color(0xFF93A1A1),
    faint: const Color(0xFF657B83),
    accent: const Color(0xFFE3733F),
    codeBg: const Color(0xFF00212B),
    userBubble: const Color(0xFF0A4050),
    syntax: _solarSyntax,
  ),
);
