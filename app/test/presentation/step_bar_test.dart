import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/presentation/home/cards.dart';
import 'package:tether/presentation/theme/theme.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget bar) =>
      tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: Scaffold(body: SizedBox(width: 200, child: bar))));

  testWidgets('a step bar has one segment per step, up to its limit', (tester) async {
    await show(tester, const StepBar(done: 1, total: 4));
    expect(find.descendant(of: find.byType(StepBar), matching: find.byType(Expanded)), findsNWidgets(4));
    await show(tester, const StepBar(done: 3, total: 30, segments: 8));
    expect(find.descendant(of: find.byType(StepBar), matching: find.byType(Expanded)), findsNWidgets(8));
  });
}
