import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/presentation/nav/nav_cubit.dart';
import 'package:tether/presentation/theme/theme.dart';
import 'package:tether/presentation/widgets/task_report_card.dart';
import 'package:tether/presentation/widgets/timeline_item_view.dart';

import '../helpers/fakes.dart';

rpb.Span span(String t) => rpb.Span(text: t);
rpb.Block para(String t) => rpb.Block(paragraph: rpb.Paragraph(spans: [span(t)]));
rpb.Block table() => rpb.Block(
      table: rpb.Table(
        header: [for (final h in ['Path', 'Class', 'What it is']) rpb.TableCell(spans: [span(h)])],
        rows: [
          rpb.TableRow(cells: [for (final c in ['cmd/scripts/v2sync/main.go', '(b)', 'older local copy']) rpb.TableCell(spans: [span(c)])]),
        ],
      ),
    );

void main() {
  late NavCubit nav;

  setUp(() => nav = NavCubit(watchHub: WatchHub(FakeHubRepository())));

  Future<void> show(WidgetTester tester, rpb.TaskReport r) => tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: BlocProvider.value(value: nav, child: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 700, child: TaskReportCard(report: r))))),
      ));

  rpb.TaskReport report({bool failed = false, List<rpb.Block>? blocks, bool clipped = false, String detail = ''}) =>
      rpb.TaskReport(failed: failed, title: 'Clean up the repo', node: 'laptop', folder: 'fk-ims-wvs', session: 't1', blocks: blocks ?? [para('All done.')], clipped: clipped, detail: detail);

  testWidgets('a short report shows who did it, where, and what it said, with nothing to unfold', (tester) async {
    await show(tester, report());
    expect(find.text('TASK FINISHED'), findsOneWidget);
    expect(find.text('Clean up the repo'), findsOneWidget);
    expect(find.text('laptop'), findsOneWidget);
    expect(find.text('fk-ims-wvs'), findsOneWidget);
    expect(find.textContaining('All done.', findRichText: true), findsOneWidget);
    expect(find.byKey(const Key('task-report-more')), findsNothing);
  });

  testWidgets('a report with a table folds, shows the table when opened, and says when it was cut', (tester) async {
    await show(tester, report(blocks: [para('Here is what I found.'), table()], clipped: true));
    expect(find.byKey(const Key('task-report-more')), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);
    expect(find.textContaining('Cut short'), findsNothing);

    await tester.tap(find.byKey(const Key('task-report-more')));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    expect(find.textContaining('cmd/scripts/v2sync/main.go', findRichText: true), findsOneWidget, reason: 'the table is drawn as a table, not run into a line');
    expect(find.textContaining('Cut short'), findsOneWidget);

    await tester.tap(find.byKey(const Key('task-report-more')));
    await tester.pumpAndSettle();
    expect(find.text('Show all'), findsOneWidget);
  });

  testWidgets('a failed task is marked and says why', (tester) async {
    await show(tester, report(failed: true, blocks: [], detail: 'the agent went away'));
    expect(find.text('TASK FAILED'), findsOneWidget);
    expect(find.text('the agent went away'), findsOneWidget);
  });

  testWidgets('Open goes to the task\'s own session', (tester) async {
    await show(tester, report());
    await tester.tap(find.byKey(const Key('task-report-open')));
    expect(nav.state.top, const SessionEntry('t1'));
  });

  testWidgets('the timeline draws a report item as the card', (tester) async {
    final item = rpb.TimelineItem(itemId: 'task:t1:m1', taskReport: report());
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: BlocProvider.value(value: nav, child: Scaffold(body: TimelineItemView(item: item))),
    ));
    expect(find.byType(TaskReportCard), findsOneWidget);
  });
}
