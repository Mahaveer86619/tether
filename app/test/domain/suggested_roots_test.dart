import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';

Session _s(String id, String node, String cwd, {int daysAgo = 1}) =>
    Session(id: id, node: node, cwd: cwd, updated: DateTime.now().subtract(Duration(days: daysAgo)));

HubSnapshot _hub(List<Session> list) => HubSnapshot(sessions: {for (final s in list) s.id: s});

void main() {
  test('roots come from where the projects are, not from home, scratch or app data', () {
    final hub = _hub([
      // The laptop: personal and work projects, the home folder, and noise.
      for (final (i, name) in ['tether', 'BMO', 'resume', 'syncthing'].indexed) _s('p$i', 'laptop', r'C:\Users\me\projects\personal\' + name),
      _s('p9', 'laptop', r'C:\Users\me\projects\personal\resume\Mahaveer'),
      for (final (i, name) in ['fk-cn', 'router-traffic-fw', 'ekart'].indexed) _s('w$i', 'laptop', r'C:\Users\me\projects\work\GitHub\' + name, daysAgo: 3),
      _s('h1', 'laptop', r'C:\Users\me'),
      _s('h2', 'laptop', r'C:\Users\me'),
      _s('h3', 'laptop', r'C:\Users\me'),
      _s('a1', 'laptop', r'C:\Users\me\AppData\Roaming\Claude\scratch-workspaces\x\y'),
      _s('d1', 'laptop', r'C:\Users\me\projects\personal'),
      _s('d2', 'laptop', r'C:\Users\me\projects\personal'),
      _s('d3', 'laptop', r'C:\Users\me\projects\personal'),
    ]);
    expect(hub.suggestedRoots('laptop'), [r'C:/Users/me/projects/personal', r'C:/Users/me/projects/work/GitHub']);
  });

  test('one project worked in often is enough; one used once is not', () {
    final often = _hub([for (var i = 0; i < 4; i++) _s('a$i', 'minipc', '/home/me/development/wvs')]);
    expect(often.suggestedRoots('minipc'), ['/home/me/development']);

    final once = _hub([_s('a', 'minipc', '/home/me/development/wvs'), _s('s', 'minipc', '/home/me/.tether/scratch/abc')]);
    expect(once.suggestedRoots('minipc'), isEmpty);
  });

  test('each device has its own', () {
    final hub = _hub([
      _s('1', 'laptop', '/a/x/p1'),
      _s('2', 'laptop', '/a/x/p2'),
      _s('3', 'minipc', '/b/y/q1'),
      _s('4', 'minipc', '/b/y/q2'),
    ]);
    expect(hub.suggestedRoots('laptop'), ['/a/x']);
    expect(hub.suggestedRoots('minipc'), ['/b/y']);
  });
}
