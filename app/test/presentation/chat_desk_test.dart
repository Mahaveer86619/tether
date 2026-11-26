import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/repositories/repositories.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/injection.dart';
import 'package:tether/presentation/app.dart';
import 'package:tether/presentation/chats/chat_desk_cubit.dart';

import '../helpers/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final tenPrompts = [for (var i = 1; i <= 10; i++) ChatPrompt(itemId: 'u$i', session: 's1', n: i, text: 'prompt $i')];

void main() {
  late FakeHubRepository repo;

  setUp(() async {
    await sl.reset();
    repo = FakeHubRepository(HubSnapshot(
      status: ConnectionStatus.connected,
      hubVersion: '0.17.0',
      hubNode: 'minipc',
      nodes: {'laptop': laptop, 'minipc': minipc},
      sessions: {'s1': session('s1', cwd: '/srv/app')},
      // Last active long ago, so opening it shows the recap.
      chats: {'c1': Chat(id: 'c1', title: 'Fix login', activeSession: 's1', links: const [ChatLink(session: 's1')], updated: DateTime(2026, 10, 11))},
    ))
      ..desk = ChatDesk(
        recap: const ChatRecap(asked: 'prompt 10', done: 'The login test passes now.', open: ['Fix signup'], prompt: 10),
        tokens: 42000,
        rules: const [DeskRule(id: 'r1', name: 'No comments', text: 'Never write code comments.')],
        prompts: tenPrompts,
      );
    sl
      ..registerSingleton<HubRepository>(repo)
      ..registerSingleton<TransferRepository>(FakeTransferRepository())
      ..registerSingleton<SettingsRepository>(FakeSettingsRepository()..saved = const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 't'))
      ..registerSingleton<UpdateRepository>(FakeUpdateRepository())
      ..registerSingleton<TailscaleRepository>(FakeTailscale())
      ..registerSingleton<HubProbe>(FakeHubProbe())
      ..registerSingleton<NotifyDevice>(FakeNotifyDevice())
      ..registerSingleton<DesktopUpdater>(FakeDesktopUpdater());
    configureDependencies(withData: false);
  });

  Future<void> openChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TetherApp());
    await settle(tester);
    await tester.tap(find.byKey(const Key('nav-chats')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('chat-c1')));
    await settle(tester);
  }

  String composerText(WidgetTester tester) =>
      tester.widget<EditableText>(find.descendant(of: find.byKey(const Key('composer')), matching: find.byType(EditableText), matchRoot: true)).controller.text;

  testWidgets('a chat opened after a gap shows its recap and its context size', (tester) async {
    await openChat(tester);
    expect(find.byKey(const Key('recap-card')), findsOneWidget);
    expect(find.textContaining('The login test passes now.', findRichText: true), findsOneWidget);
    expect(find.textContaining('Fix signup', findRichText: true), findsOneWidget);
    expect(find.text('42k'), findsOneWidget);
    expect(find.byKey(const Key('handoff-banner')), findsNothing, reason: 'well under the threshold');

    await tester.tap(find.byKey(const Key('recap-close')));
    await settle(tester);
    expect(find.byKey(const Key('recap-card')), findsNothing);
  });

  testWidgets('rewinding three back puts that prompt in the new session\'s composer', (tester) async {
    await openChat(tester);
    await tester.tap(find.byKey(const Key('context-meter')));
    await settle(tester);
    await tester.tap(find.text('Rewind to an earlier prompt…'));
    await settle(tester);
    expect(find.byKey(const Key('rewind-picker')), findsOneWidget);
    expect(find.byKey(const Key('rewind-back-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rewind-back-3')));
    await settle(tester);
    expect(find.text('Rewind to before prompt 8?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-rewind')));
    await settle(tester);

    expect(repo.deskCalls, ['rewind:c1:u8']);
    expect(composerText(tester), 'prompt 8');
  });

  testWidgets('a message of the user can be rewound to from its own menu', (tester) async {
    await openChat(tester);
    repo.emitTimeline('s1', [
      rpb.TimelineItem(itemId: 'u9', user: rpb.UserText(text: 'prompt 9')),
      rpb.TimelineItem(itemId: 'u10', user: rpb.UserText(text: 'prompt 10')),
    ]);
    await settle(tester);
    await tester.longPress(find.text('prompt 10').last);
    await settle(tester);
    await tester.tap(find.text('Rewind to before this'));
    await settle(tester);
    expect(find.text('Rewind to before prompt 10?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-rewind')));
    await settle(tester);
    expect(repo.deskCalls, ['rewind:c1:u10']);
  });

  testWidgets('a large context offers a handoff, and Remind shows the recap and rules', (tester) async {
    repo.desk = ChatDesk(recap: repo.desk.recap, tokens: 180000, rules: repo.desk.rules, prompts: tenPrompts);
    await openChat(tester);
    expect(find.byKey(const Key('handoff-banner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('handoff')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-handoff')));
    await settle(tester);
    expect(repo.deskCalls, ['handoff:c1']);

    expect(find.byKey(const Key('remind-chips')), findsNothing);
    await tester.tap(find.byKey(const Key('context-meter')));
    await settle(tester);
    await tester.tap(find.text('Remind me before sending'));
    await settle(tester);
    expect(repo.deskCalls.last, 'remind:c1:true');
    expect(find.byKey(const Key('remind-recap')), findsOneWidget);
    expect(find.byKey(const Key('remind-rule-r1')), findsOneWidget);
  });

  test('the recap shows only after twelve quiet hours', () {
    final cubit = ChatDeskCubit(chatId: 'c1', chats: sl());
    final now = DateTime(2026, 11, 25, 12);
    cubit.opened(now.subtract(const Duration(hours: 11)), now: now);
    expect(cubit.state.showRecap, isFalse);
    cubit.opened(now.subtract(const Duration(hours: 12)), now: now);
    expect(cubit.state.showRecap, isTrue);
    cubit.close();
  });
}
