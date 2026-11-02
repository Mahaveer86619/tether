import 'package:flutter_test/flutter_test.dart';
import 'package:tether/data/mappers/hub_mappers.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/gen/tether/v1/tether.pb.dart' as pb;

void main() {
  test('pasted-content tags come out of user messages; their ids are kept', () {
    final it = rpb.TimelineItem(
      itemId: 'u1',
      user: rpb.UserText(text: '\n\n<pasted_content id="c669">\nlooks fine, recalculate?\n</pasted_content id="c669">\n', source: 'terminal'),
    );
    final out = unpastedItem(it);
    expect(out.user.text, 'looks fine, recalculate?');
    expect(out.user.pastedIds, ['c669']);
    expect(out.user.source, 'terminal');
    expect(it.user.text, startsWith('\n\n<pasted_content'), reason: 'the original is left alone');

    final mixed = unpaste('see:\n<pasted_content id="a">\none\n</pasted_content id="a">\nand\n<pasted_content id="b">\ntwo\n</pasted_content>');
    expect(mixed.$1, 'see:\none\nand\ntwo');
    expect(mixed.$2, ['a', 'b']);

    final plain = rpb.TimelineItem(itemId: 'u2', user: rpb.UserText(text: 'just typed'));
    expect(identical(unpastedItem(plain), plain), isTrue);
  });

  test('session titles and last prompts lose the tags too', () {
    final s = sessionFromPb(pb.SessionInfo(id: 's', title: '<pasted_content id="x">\nFix it\n</pasted_content id="x">', lastPrompt: '<pasted_content id="y">\nmore\n</pasted_content id="y">'));
    expect((s.title, s.lastPrompt), ('Fix it', 'more'));
  });
}
