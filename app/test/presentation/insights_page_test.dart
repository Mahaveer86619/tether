import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/prompt_desk.dart';
import 'package:tether/domain/usecases/prompt_desk_usecases.dart';
import 'package:tether/presentation/insights/insights_cubit.dart';
import 'package:tether/presentation/insights/insights_page.dart';
import 'package:tether/presentation/theme/theme.dart';

import '../helpers/fakes.dart';

const stats = InsightStats(
  chats: 13,
  messages: 1833,
  prompts: 531,
  messagesPerChat: Spread(count: 13, median: 78, p90: 462, max: 495),
  promptsPerChat: Spread(count: 13, median: 23, p90: 80, max: 90),
  promptLengths: [Counted('under 100', 400), Counted('100 to 499', 120)],
  multiSessionChats: 8,
  lineage: [Counted('move', 7), Counted('fork', 1)],
  restarts: 15,
  restartsBack: [Counted('1', 7), Counted('2', 3)],
  input: 1000,
  cacheRead: 99000,
  cacheReadShare: 0.98,
  tokenSessions: 2,
  topSessions: [SessionTokens(session: 's1', title: 'Big session', total: 80000)],
  costUsd: 12.5,
  toolCalls: 40,
  toolErrors: 3,
  tools: [ToolUse('Bash', 30, 3), ToolUse('Read', 10, 0)],
  allowed: 4,
  denied: 1,
  phrases: [RepeatedPhrase(label: "Don't commit or push", rule: 'Do not commit or push unless I ask.', prompts: 60, chats: 9)],
  sampleChats: 13,
  sampleMessages: 220,
);

const saved = InsightReport(
  id: 'rep0',
  session: 's9',
  title: 'Contexts run long',
  summary: 'Most cost is cache reads.',
  recommendations: [
    Recommendation(kind: RecommendationKind.rule, title: 'No pushing', why: '60 prompts', text: 'Never push.'),
    Recommendation(kind: RecommendationKind.skill, title: 'Release check', text: 'Checks the release.'),
    Recommendation(kind: RecommendationKind.context, title: 'Hand off', text: 'Offer a fresh session at 200k tokens.'),
  ],
);

void main() {
  late FakePromptDeskRepository desk;
  late InsightsCubit cubit;
  late List<String> opened;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    opened = [];
    cubit = InsightsCubit(insights: Insights(desk), poll: const Duration(milliseconds: 100));
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: BlocProvider.value(value: cubit..load(), child: InsightsView(onSession: opened.add))),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() => desk = FakePromptDeskRepository(stats: stats, reports: [saved]));

  testWidgets('the stats show as cards, and the window can be all of history', (tester) async {
    await open(tester);
    expect(find.descendant(of: find.byKey(const Key('stat-chats')), matching: find.text('13')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('stat-messages')), matching: find.text('78')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('stat-cache')), matching: find.text('98%')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('stat-cost')), matching: find.text(r'$12.50')), findsOneWidget);
    expect(find.byKey(const Key('bars-restarts')), findsOneWidget);
    expect(find.byKey(const Key('bars-tools')), findsOneWidget);
    await tester.tap(find.byKey(const Key('insights-all')));
    await tester.pumpAndSettle();
    expect(desk.statsAsked, [30, 0]);
  });

  testWidgets('Analyze says what will be sent before it starts, then shows the report once it is saved', (tester) async {
    desk.reports_.clear();
    await open(tester);
    await tester.tap(find.byKey(const Key('analyze')));
    await tester.pumpAndSettle();
    expect(find.textContaining('220 messages from the 13 most recent chats'), findsOneWidget);
    await tester.tap(find.byKey(const Key('analyze-confirm')));
    // A running analysis shows a spinner, so the frames never settle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(desk.analyzed, [30]);
    expect(find.text('Claude is analysing…'), findsOneWidget);

    desk.reports_[0] = const InsightReport(id: 'rep1', session: 'sx', title: 'Found it', summary: 'All good.');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.text('Found it'), findsOneWidget);
    expect(find.text('Claude is analysing…'), findsNothing);
  });

  testWidgets('a recommended rule is added switched off, a skill is drafted in a session that opens', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('rec-rule-No pushing')));
    await tester.pumpAndSettle();
    final rule = desk.rules_.single;
    expect((rule.name, rule.text, rule.on), ('No pushing', 'Never push.', false));
    expect(find.byKey(const Key('rec-done-No pushing')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rec-skill-Release check')));
    await tester.pumpAndSettle();
    expect(desk.drafted, [('Release check', 'Checks the release.')]);
    expect(opened, ['draft-session']);
    expect(find.byKey(const Key('rec-copy-Hand off')), findsOneWidget);
  });

  testWidgets('a repeated instruction becomes a rule, switched off', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key("phrase-rule-Don't commit or push")));
    await tester.pumpAndSettle();
    expect((desk.rules_.single.text, desk.rules_.single.on), ('Do not commit or push unless I ask.', false));
  });
}
