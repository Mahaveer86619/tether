import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/gen/tether/v1/render.pbenum.dart' as rpbe;
import 'package:tether/presentation/theme/theme.dart';
import 'package:tether/presentation/widgets/changes_pane.dart';

rpb.TimelineItem edit(int n) => rpb.TimelineItem(
      itemId: 'i$n',
      ord: Int64(n),
      tool: rpb.ToolCard(
        toolUseId: 't$n',
        name: 'Edit',
        status: rpbe.ToolCard_Status.STATUS_SUCCEEDED,
        edit: rpb.EditCard(path: '/p/file$n.go', unifiedDiff: '@@ -1 +1 @@\n-a\n+b\n', added: 1, removed: 1),
      ),
    );

Widget pane(List<rpb.TimelineItem> items) =>
    MaterialApp(theme: buildTheme(Brightness.dark), home: Scaffold(body: SizedBox(width: 1500, height: 600, child: ChangesPane(items: items))));

void main() {
  testWidgets('the file Claude changed last is the first tab, and older ones are in a menu', (tester) async {
    await tester.pumpWidget(pane([for (var n = 1; n <= 9; n++) edit(n)]));
    await tester.pump();
    final newest = tester.getTopLeft(find.byKey(const Key('change-tab-/p/file9.go'))).dx;
    final before = tester.getTopLeft(find.byKey(const Key('change-tab-/p/file8.go'))).dx;
    expect(newest, lessThan(before), reason: 'newest first');
    expect(find.byKey(const Key('change-tab-/p/file1.go')), findsNothing, reason: 'the oldest are not tabs');
    expect(find.text('3 older'), findsOneWidget);
  });

  testWidgets('a file picked from the older menu stays on screen as a tab', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(pane([for (var n = 1; n <= 9; n++) edit(n)]));
    await tester.pump();
    await tester.tap(find.byKey(const Key('more-changed-files')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('file1.go').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('change-tab-/p/file1.go')), findsOneWidget);
    expect(find.text('pinned'), findsOneWidget);
  });

  testWidgets('with few files there is no menu', (tester) async {
    await tester.pumpWidget(pane([for (var n = 1; n <= 3; n++) edit(n)]));
    await tester.pump();
    expect(find.byKey(const Key('more-changed-files')), findsNothing);
  });
}
