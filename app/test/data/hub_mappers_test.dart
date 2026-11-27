import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/data/mappers/hub_mappers.dart';
import 'package:tether/data/mappers/job_mappers.dart';
import 'package:tether/domain/entities/entities.dart';
import 'package:tether/gen/tether/v1/render.pb.dart' as rpb;
import 'package:tether/gen/tether/v1/tether.pb.dart' as pb;
import 'package:tether/gen/tether/v1/tether.pbenum.dart' as pbe;

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

  test('a node carries its grants, hours and booked slots', () {
    final n = pb.NodeStatus(
      node: 'desk',
      online: true,
      owner: 'u1',
      grants: [pb.DeviceGrant(user: 'u2', access: 'jobs', startHour: 20, endHour: 8, days: 'mon,tue', timezone: 'UTC')],
      slots: [pb.DeviceSlot(id: 's1', node: 'desk', user: 'u2', startMs: Int64(1000), endMs: Int64(2000), notes: 'train')],
    );
    final out = nodeFromPb(n);
    expect(out.owner, 'u1');
    final g = out.grants.single;
    expect((g.startHour, g.endHour, g.days, g.timezone), (20, 8, 'mon,tue', 'UTC'));
    expect(g.windowLabel, '20:00–08:00 mon, tue');
    expect(const DeviceGrant(user: 'u3', access: DeviceAccess.jobs, days: 'mon,wed').windowLabel, 'any time mon, wed');
    final s = out.slots.single;
    expect((s.id, s.user, s.notes), ('s1', 'u2', 'train'));
    expect(s.start.millisecondsSinceEpoch, 1000);
  });

  test('queued jobs and scheduling map in both directions', () {
    final j = pb.Job(
      id: 'j1',
      state: pbe.JobState.JOB_STATE_QUEUED,
      spec: pb.JobSpec(node: 'desk', cwd: '/w', command: 'x', schedule: 'next_free', queueWhenBusy: true),
    );
    final out = jobFromPb(j);
    expect(out.state, JobState.queued);
    expect(out.schedule, 'next_free');
    expect(out.queueWhenBusy, isTrue);

    final spec = jobSpecToPb(const NewJobRequest(node: 'desk', cwd: '/w', command: 'x', schedule: 's1', queueWhenBusy: true));
    expect(spec.schedule, 's1');
    expect(spec.queueWhenBusy, isTrue);
  });
}
