import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tether/data/datasources/hub_rest_api.dart';
import 'package:tether/data/datasources/hub_socket.dart';
import 'package:tether/data/repositories/hub_repository_impl.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/gen/tether/v1/tether.pb.dart' as pb;

import '../helpers/fakes.dart';

pb.Chat wireChat(String id, {String title = 'Fix login'}) => pb.Chat(
      id: id,
      title: title,
      activeSession: 's1',
      target: pb.ChatTarget(mode: 'auto', node: 'laptop', cwd: '/src/tether', state: 'resolved', reason: 'matched "tether"'),
      sessions: [pb.ChatLink(session: 's1', role: 'main')],
    );

void main() {
  late FakeHubSocket socket;
  late HubRepositoryImpl repo;
  late List<(http.Request, Map<String, dynamic>)> requests;
  late MemoryHubCache cache;

  setUp(() {
    socket = FakeHubSocket();
    cache = MemoryHubCache();
    requests = [];
    final api = HubRestApi(
      MockClient((req) async {
        final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
        requests.add((req, body));
        final path = req.url.path;
        if (path.endsWith('/targets')) {
          final s = pb.TargetSuggestions(
            candidates: [pb.TargetCandidate(node: 'laptop', cwd: '/src/tether', label: 'tether', online: true, score: 10)],
            pick: pb.TargetCandidate(node: 'laptop', cwd: '/src/tether', label: 'tether', online: true, score: 10),
          );
          return http.Response(jsonEncode(s.toProto3Json()), 200);
        }
        if (path.endsWith('/context')) {
          final cx = pb.ChatContext(chat: wireChat('c1'), messages: [pb.ChatMessage(role: 'user', text: 'hi')], notes: [pb.ChatNote(kind: 'title', value: 'Hi')]);
          return http.Response(jsonEncode(cx.toProto3Json()), 200);
        }
        if (path.endsWith('/messages')) return http.Response('{"session":"s1"}', 200);
        final title = (body['title'] as String?) ?? 'Fix login';
        return http.Response(jsonEncode(wireChat('c1', title: title).toProto3Json()), 200);
      }),
      clientName: 'test',
    );
    repo = HubRepositoryImpl(api: api, socket: socket, cache: cache);
    repo.connect(const HubConnection(url: 'ws://100.64.0.1:7420/ws', token: 'tok'));
  });

  tearDown(() => repo.dispose());

  test('chats arrive with the welcome and as chat frames, and are cached', () async {
    socket.push(SocketFrame(pb.Frame(welcome: pb.Welcome(hubVersion: '0.16.0', chats: [wireChat('c1')]))));
    final c = repo.current.chats['c1']!;
    expect(repo.current.chatsSupported, isTrue);
    expect(c.target.node, 'laptop');
    expect(c.target.mode, TargetMode.auto);
    expect(c.links.single.role, 'main');
    expect(repo.current.chatOf('s1')?.id, 'c1');

    socket.push(SocketFrame(pb.Frame(chat: wireChat('c1', title: 'Renamed'))));
    expect(repo.current.chats['c1']!.title, 'Renamed');
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    expect(cache.state?.chats.single.title, 'Renamed');
    expect(cache.state?.hubVersion, '0.16.0');
  });

  test('creating, renaming and moving a chat send the right requests', () async {
    socket.push(SocketFrame(pb.Frame(welcome: pb.Welcome(hubVersion: '0.16.0'))));
    final made = await repo.createChat(const NewChatRequest(prompt: 'fix it', clientId: 'abc'));
    expect(made.valueOrNull?.id, 'c1');
    expect(repo.current.chats.containsKey('c1'), isTrue, reason: 'taken in before the broadcast');
    var (req, body) = requests.last;
    expect((req.method, req.url.path), ('POST', '/api/v1/chats'));
    expect((body['prompt'], body['clientId'], body.containsKey('target')), ('fix it', 'abc', false), reason: 'no target means auto');

    await repo.renameChat('c1', '');
    (req, body) = requests.last;
    expect((req.method, req.url.path), ('PATCH', '/api/v1/chats/c1'));
    expect(body, {'title': ''}, reason: 'an empty title is sent, to hand naming back');

    await repo.setChatArchived('c1', archived: true);
    expect(requests.last.$2, {'archived': true}, reason: 'only the archived flag, so the title stays');

    await repo.setChatTarget('c1', const ChatTarget(mode: TargetMode.manual, node: 'laptop', cwd: '/src/x'));
    (req, body) = requests.last;
    expect(req.url.path, '/api/v1/chats/c1/target');
    expect(body['move'], isTrue);
    final target = body['target'] as Map<String, dynamic>;
    expect((target['mode'], target['node'], target['cwd']), ('manual', 'laptop', '/src/x'));

    expect((await repo.sendToChat('c1', 'more')).valueOrNull, 's1');
    final s = (await repo.targetSuggestions('tether login')).valueOrNull!;
    expect(s.pick?.label, 'tether');
    expect(requests.last.$1.url.queryParameters['prompt'], 'tether login');
    final cx = (await repo.chatContext('c1')).valueOrNull!;
    expect(cx.notes['title'], 'Hi');
    expect(cx.markdown, contains('**You:** hi'));
  });
}
