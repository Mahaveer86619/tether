import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/prompt_desk.dart';
import 'package:tether/domain/usecases/prompt_desk_usecases.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/presentation/rules/rules_cubit.dart';
import 'package:tether/presentation/rules/rules_page.dart';
import 'package:tether/presentation/theme/theme.dart';

import '../helpers/fakes.dart';

void main() {
  late FakePromptDeskRepository desk;
  late RulesCubit cubit;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hub = FakeHubRepository(snapshotWith([session('s1', cwd: '/srv/app'), session('s2', node: 'laptop', cwd: '/home/me')]));
    cubit = RulesCubit(rules: Rules(desk), watchHub: WatchHub(hub));
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: BlocProvider.value(value: cubit..load(), child: const RulesView())),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() => desk = FakePromptDeskRepository(rules: [const Rule(id: 'r0', name: 'Tabs', text: 'Use tabs.', on: true)]));

  testWidgets('a suggested rule is added with a tap, switched off, and leaves the suggestions', (tester) async {
    await open(tester);
    expect(find.text('Tabs'), findsOneWidget);
    expect(find.byKey(const Key('suggest-Read the logs first')), findsOneWidget);
    await tester.tap(find.byKey(const Key('suggest-Read the logs first')));
    await tester.pumpAndSettle();
    final added = desk.rules_.last;
    expect((added.text, added.on, added.scope), ('Read the logs before proposing a fix.', false, RuleScope.everywhere));
    expect(find.byKey(const Key('suggest-Read the logs first')), findsNothing);
    expect(tester.widget<Switch>(find.byKey(Key('rule-on-${added.id}'))).value, isFalse);
  });

  testWidgets('a rule is switched off and deleted', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('rule-on-r0')));
    await tester.pumpAndSettle();
    expect(desk.rules_.single.on, isFalse);
    await tester.tap(find.byKey(const Key('rule-delete-r0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-delete-confirm')));
    await tester.pumpAndSettle();
    expect(desk.rules_, isEmpty);
    expect(find.text('No rules yet'), findsOneWidget);
  });

  testWidgets('a project rule is written with a device and a folder picked from the ones the hub knows', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('add-rule')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rule-text')), 'Keep docs/ current.');
    await tester.tap(find.text('A project'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-device')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('minipc').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rule-folder-/home/me')), findsNothing, reason: 'a home folder is not a project, and it is on another device');
    await tester.tap(find.byKey(const Key('rule-folder-/srv/app')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-save')));
    await tester.pumpAndSettle();
    final r = desk.rules_.last;
    expect((r.text, r.scope, r.node, r.cwd, r.on), ('Keep docs/ current.', RuleScope.project, 'minipc', '/srv/app', true));
    expect(find.byKey(const Key('rule-editor')), findsNothing);
    expect(find.text('minipc · /srv/app'), findsOneWidget);
  });

  testWidgets('a device rule without its device is refused and the editor stays open', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('add-rule')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rule-text')), 'Something.');
    await tester.tap(find.text('A device'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-save')));
    await tester.pumpAndSettle();
    expect(desk.rules_.length, 1);
    expect(find.byKey(const Key('rule-editor')), findsOneWidget);
    expect(find.text('Pick the device it applies to.'), findsOneWidget);
  });
}
