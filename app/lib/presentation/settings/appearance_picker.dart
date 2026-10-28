import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../theme/palettes.dart';
import '../theme/theme.dart';
import '../widgets/markdown_view.dart';
import 'settings_cubit.dart';

const _sample = '''// Code colours follow the theme
func greet(name string) int {
	msg := "hello, " + name
	return len(msg) * 2
}''';

/// Theme, accent and a live code preview.
class AppearancePicker extends StatelessWidget {
  const AppearancePicker({super.key, required this.appearance});

  final Appearance appearance;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<SettingsCubit>();
    final brightness = Theme.of(context).brightness;
    final palette = paletteById(appearance.palette);
    final themeAccent = palette.of(brightness).accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in palettes)
              _PaletteChip(palette: p, colors: p.of(brightness), selected: p.id == palette.id, onTap: () => cubit.setPalette(p.id)),
          ],
        ),
        const SizedBox(height: 18),
        Text('Accent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Swatch(color: themeAccent, selected: appearance.accent == null, tooltip: "The theme's own", onTap: () => cubit.setAccent(null)),
            for (final a in accentChoices)
              _Swatch(color: a, selected: appearance.accent == a.toARGB32(), onTap: () => cubit.setAccent(a.toARGB32())),
          ],
        ),
        const SizedBox(height: 18),
        const CodeBox(code: _sample, lang: 'go'),
      ],
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({required this.palette, required this.colors, required this.selected, required this.onTap});

  final Palette palette;
  final TetherColors colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dots = [colors.accent, colors.syntax.keyword, colors.syntax.string, colors.syntax.function];
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: colors.canvas,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? c.accent : c.border, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Expanded(child: Text(palette.name, style: TextStyle(color: colors.text, fontSize: 13, fontWeight: FontWeight.w600))),
            for (final d in dots)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(color: d, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap, this.tooltip});

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final swatch = InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? context.colors.text : Colors.transparent, width: 2),
        ),
        child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
      ),
    );
    return tooltip == null ? swatch : Tooltip(message: tooltip!, child: swatch);
  }
}
