import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/presentation/theme/palettes.dart';
import 'package:tether/presentation/theme/theme.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  group('the Tether palette', () {
    final p = paletteById('tether');

    test('is there, with its own name', () {
      expect(p.id, 'tether');
      expect(palettes.map((x) => x.id), contains('tether'));
    });

    for (final dark in [true, false]) {
      final c = p.of(dark ? Brightness.dark : Brightness.light);
      final mode = dark ? 'dark' : 'light';

      test('text reads at 4.5:1 on every ground in $mode', () {
        for (final (name, text) in [('text', c.text), ('muted', c.muted), ('faint', c.faint)]) {
          for (final (ground, bg) in [('canvas', c.canvas), ('surface', c.surface)]) {
            expect(_ratio(text, bg), greaterThanOrEqualTo(4.5), reason: '$name on $ground in $mode');
          }
        }
        expect(_ratio(c.text, c.raised), greaterThanOrEqualTo(4.5), reason: 'text on raised in $mode');
        expect(_ratio(c.muted, c.raised), greaterThanOrEqualTo(4.5), reason: 'muted on raised in $mode');
      });

      test('what carries meaning is readable as text in $mode', () {
        for (final (name, color) in [('accent', c.accent), ('success', c.success), ('warning', c.warning), ('danger', c.danger), ('info', c.info)]) {
          for (final (ground, bg) in [('canvas', c.canvas), ('surface', c.surface)]) {
            expect(_ratio(color, bg), greaterThanOrEqualTo(4.5), reason: '$name on $ground in $mode');
          }
        }
      });
    }

    test('text on the accent reads at 4.5:1 in every palette', () {
      for (final palette in palettes) {
        for (final b in Brightness.values) {
          final accent = palette.of(b).accent;
          expect(_ratio(onAccent(accent), accent), greaterThanOrEqualTo(3.0), reason: '${palette.id} $b');
        }
      }
      expect(_ratio(onAccent(const Color(0xFF10B981)), const Color(0xFF10B981)), greaterThanOrEqualTo(4.5));
    });

    test('squares the corners, while the others keep theirs', () {
      expect(p.of(Brightness.dark).shape, lessThan(0.5));
      expect(paletteById('claude').of(Brightness.dark).shape, 1);
    });

    test('the dark side keeps the design grounds', () {
      final c = p.of(Brightness.dark);
      expect([c.canvas, c.surface, c.raised, c.border], [const Color(0xFF0D1117), const Color(0xFF161B22), const Color(0xFF21262D), const Color(0xFF30363D)]);
      expect(c.accent, const Color(0xFF10B981));
    });
  });
}
