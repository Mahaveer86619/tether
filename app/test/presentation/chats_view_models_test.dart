import 'package:flutter_test/flutter_test.dart';
import 'package:tether/core/error/failures.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/presentation/chats/new_chat_cubit.dart';
import 'package:tether/presentation/nav/nav_cubit.dart';

import '../helpers/fakes.dart';

void main() {
  group('NavCubit', () {
    late FakeHubRepository repo;
    late NavCubit nav;
    setUp(() {
      repo = FakeHubRepository(snapshotWith([session('s1'), session('s2')]).copyWith(
        hubVersion: '0.16.0',
        chats: {'c1': const Chat(id: 'c1', activeSession: 's1', links: [ChatLink(session: 's1'), ChatLink(session: 's2', role: 'fork')])},
      ));
      nav = NavCubit(watchHub: WatchHub(repo));
    });
    tearDown(() => nav.close());

    test('starts on Chats with nothing to go back to', () {
      expect(nav.state.destination, Destination.home);
      expect(nav.state.atRoot, isTrue);
      expect(nav.back(), isFalse);
    });

    test('Back pops the screens opened on top, then goes Home, then leaves', () {
      nav.select(Destination.devices);
      nav.openSession('s2');
      nav.push(const NodeEntry('laptop'));
      expect(nav.state.stack, [const SessionEntry('s2'), const NodeEntry('laptop')]);
      expect(nav.state.selectedNode, 'laptop');

      nav.back();
      expect(nav.state.top, const SessionEntry('s2'));
      nav.back();
      expect(nav.state.destination, Destination.devices);
      expect(nav.state.stack, isEmpty);
      nav.back();
      expect(nav.state.atRoot, isTrue, reason: 'Back from a place with nothing open goes Home');
      expect(nav.back(), isFalse);
    });

    test('switching places leaves nothing to go back to: a chat, Settings, Home, then Back leaves', () {
      nav.openChat('c1');
      nav.select(Destination.settings);
      nav.select(Destination.home);
      expect(nav.state.atRoot, isTrue);
      expect(nav.back(), isFalse, reason: 'the chat opened first is not revisited');

      nav.openChat('c1');
      nav.select(Destination.chats);
      nav.select(Destination.devices);
      nav.back();
      expect(nav.state.destination, Destination.home);
    });

    test("a chat's active session opens as the chat; other sessions on their own", () {
      nav.openSession('s1');
      expect(nav.state.top, const ChatEntry('c1'));
      expect(nav.state.selectedChat, 'c1');
      nav.openSession('s2');
      expect(nav.state.top, const SessionEntry('s2'));
    });

    test('a new chat becomes its chat without a Back step; show replaces the stack', () {
      nav.newChat();
      nav.replaceTop(const ChatEntry('c9'));
      expect(nav.state.stack, [const ChatEntry('c9')]);
      nav.back();
      expect(nav.state.atRoot, isTrue, reason: 'Back skips the composer the chat came from');

      nav.openChat('c1');
      nav.push(const SessionEntry('s2'));
      nav.openChat('c2', replace: true);
      expect(nav.state.stack, [const ChatEntry('c2')]);
      nav.back();
      expect(nav.state.stack, isEmpty, reason: 'a screen swapped in sidebar-style replaces the whole stack');
    });

    test('opening what is already open adds no Back step', () {
      nav.openChat('c1');
      nav.openChat('c1');
      expect(nav.state.stack, [const ChatEntry('c1')]);
      nav.select(Destination.home);
      nav.select(Destination.home);
      expect(nav.state.atRoot, isTrue);
    });
  });

  group('Chats', () {
    test('on a hub without chats, starting one starts a plain session at the target', () async {
      final repo = FakeHubRepository(snapshotWith([]).copyWith(hubVersion: '0.15.0', hubNode: 'minipc'));
      final chats = Chats(repo);
      final r = await chats.start(const NewChatRequest(prompt: 'hello', target: ChatTarget(mode: TargetMode.manual, node: 'laptop', cwd: '/x')));
      expect(r.valueOrNull, (null, 'new-session'));
      expect(repo.chatsCreated, isEmpty);
      final req = repo.created.single;
      expect((req.node, req.cwd, req.scratch), ('laptop', '/x', false));

      await chats.start(const NewChatRequest(prompt: 'hello'));
      expect(repo.created.last.scratch, isTrue, reason: 'auto on an old hub falls back to a hub scratch session');
    });

    test('checks input and devices before asking the hub', () async {
      final repo = FakeHubRepository(snapshotWith([], nodes: [const Node(name: 'off', online: false)]).copyWith(hubVersion: '0.16.0'));
      final chats = Chats(repo);
      expect((await chats.start(const NewChatRequest(prompt: '  '))).failureOrNull, isA<ValidationFailure>());
      expect((await chats.start(const NewChatRequest(prompt: 'x', target: ChatTarget(node: 'off')))).failureOrNull, isA<NodeOfflineFailure>());
      expect((await chats.retarget('c', const ChatTarget())).failureOrNull, isA<ValidationFailure>());
      expect(repo.chatsCreated, isEmpty);
    });
  });

  group('NewChatCubit', () {
    test('previews what auto would pick, then starts the chat and clears the draft', () async {
      final repo = FakeHubRepository(snapshotWith([]).copyWith(hubVersion: '0.16.0'))
        ..suggestions = const TargetSuggestions(pick: TargetCandidate(node: 'laptop', cwd: '/src/tether', label: 'tether'));
      final settings = FakeSettingsRepository();
      final cubit = NewChatCubit(chats: Chats(repo), drafts: Drafts(settings), watchHub: WatchHub(repo));
      cubit.textChanged('the tether app');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(cubit.state.preview?.label, 'tether');
      expect(await settings.loadDraft('new-chat'), 'the tether app');

      await cubit.submit('the tether app');
      expect(cubit.state.chatId, 'chat-1');
      expect(cubit.state.sessionId, 'new-session-1');
      expect(repo.chatsCreated.single.clientId, hasLength(32));
      expect(await settings.loadDraft('new-chat'), '');
      await cubit.close();
    });

    test('opened from a device, it starts there in its latest folder', () async {
      final repo = FakeHubRepository(snapshotWith([session('s1', node: 'laptop', cwd: '/src/tether')]).copyWith(hubVersion: '0.16.0'));
      final cubit = NewChatCubit(chats: Chats(repo), drafts: Drafts(FakeSettingsRepository()), watchHub: WatchHub(repo), node: 'laptop');
      expect(cubit.state.target, const ChatTarget(mode: TargetMode.manual, node: 'laptop', cwd: '/src/tether'));
      cubit.textChanged('anything');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(repo.suggestionPrompts, isEmpty, reason: 'a chosen target needs no preview');
      await cubit.close();
    });
  });
}
