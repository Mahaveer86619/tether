import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/injection.dart';
import 'package:tether/presentation/home/device_sharing.dart';
import 'package:tether/presentation/settings/team_cubit.dart';
import 'package:tether/presentation/settings/team_section.dart';
import 'package:tether/presentation/theme/theme.dart';

import '../helpers/fakes.dart';
import 'jobs_test.dart' show hubCubitFor;

const owner = TeamUser(id: 'u1', name: 'Owner', role: 'admin');
const mate = TeamUser(id: 'u2', name: 'Teammate');

HubSnapshot team({TeamUser me = owner}) => const HubSnapshot(
      status: ConnectionStatus.connected,
      users: {'u1': owner, 'u2': mate},
      nodes: {
        'laptop': Node(name: 'laptop', online: true, owner: 'u1', grants: [DeviceGrant(user: 'u2', access: DeviceAccess.jobs)]),
        'desktop': Node(name: 'desktop', online: true, owner: 'u2'),
      },
      sessions: {'s1': Session(id: 's1', node: 'desktop', owner: 'u1')},
    ).copyWith(me: () => me);

Future<FakeHubRepository> pump(WidgetTester tester, Widget child, {TeamUser me = owner}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeHubRepository(team(me: me));
  sl.registerFactory(() => TeamCubit(team: ManageTeam(repo)));
  addTearDown(() => sl.unregister<TeamCubit>());
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(
      body: BlocProvider(lazy: false, create: (_) => hubCubitFor(repo), child: SingleChildScrollView(child: child)),
    ),
  ));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  test('a node owned by someone else is named by its owner', () {
    final hub = team(me: mate);
    expect(hub.ownerOf('laptop'), 'Owner');
    expect(hub.ownerOf('desktop'), '');
    expect(team().ownerOf('desktop'), 'Teammate');
  });

  testWidgets('Team lists the users, invites with a code and removes a member', (tester) async {
    final repo = await pump(tester, const TeamSection());
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('user-u1')), findsOneWidget);
    expect(find.byKey(const Key('user-u2')), findsOneWidget);
    expect(find.byKey(const Key('remove-u1')), findsNothing);

    await tester.tap(find.byKey(const Key('invite-teammate')));
    await tester.pumpAndSettle();
    expect(find.text('TEAM1-INVIT'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('remove-u2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-remove')));
    await tester.pumpAndSettle();
    expect(repo.team.map((u) => u.id), ['u1']);
    expect(find.byKey(const Key('user-u2')), findsNothing);
  });

  testWidgets('a member sees no invite or remove buttons', (tester) async {
    await pump(tester, const TeamSection(), me: mate);
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-teammate')), findsNothing);
    expect(find.byKey(const Key('remove-u2')), findsNothing);
  });

  testWidgets('Devices shows owners and grants, and shares with a warning for full access', (tester) async {
    final repo = await pump(tester, const DeviceSharingSection());
    expect(find.text('Yours'), findsOneWidget);
    expect(find.text("Teammate's, shared with you"), findsOneWidget);
    expect(find.byKey(const Key('grant-laptop-u2')), findsOneWidget);
    expect(find.byKey(const Key('share-desktop')), findsNothing);

    await tester.tap(find.byKey(const Key('share-laptop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('share-warning')), findsNothing);
    await tester.tap(find.byKey(const Key('share-user')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teammate').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-full')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('share-warning')), findsOneWidget);
    await tester.tap(find.byKey(const Key('share-confirm')));
    await tester.pumpAndSettle();
    expect(repo.shares.single, ('laptop', 'u2', DeviceAccess.full));

    await tester.tap(find.byTooltip('Stop sharing'));
    await tester.pumpAndSettle();
    expect(repo.shares.last, ('laptop', 'u2', null));
  });

  testWidgets('an owner can set sharing hours and book time on a device', (tester) async {
    final repo = await pump(tester, const DeviceSharingSection());

    await tester.tap(find.byKey(const Key('share-laptop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-user')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teammate').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-start-hour')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('01:00').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-end-hour')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('02:00').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('share-days')), 'mon,tue');
    await tester.enterText(find.byKey(const Key('share-timezone')), 'UTC');
    await tester.tap(find.byKey(const Key('share-confirm')));
    await tester.pumpAndSettle();
    expect(repo.shareWindows.single, (1, 2, 'mon,tue', 'UTC'));

    await tester.tap(find.byKey(const Key('book-laptop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('slot-confirm')));
    await tester.pumpAndSettle();
    final b = repo.bookings.single;
    expect((b.$1, b.$2, b.$5), ('laptop', 'u1', ''));
    expect(b.$4.isAfter(b.$3), isTrue);
  });
}
