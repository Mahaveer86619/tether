import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tether/data/mappers/hub_mappers.dart';

void main() {
  test('the hub\'s routine report maps to entities, and missing parts get quiet defaults', () {
    final json = jsonDecode('''
{"generatedMs": 1793000000000, "sessions": 74, "tasks": 546, "candidates": [
  {"example": "progress?", "requests": ["progress?", "check the v2 sync progress"], "runs": 5, "sessions": 3,
   "nodes": ["minipc"], "cwds": ["/srv/wvs"], "mutating": false, "clean": 0.8, "firstMs": 1792000000000, "lastMs": 1792900000000,
   "steps": [{"key": "Bash:curl", "detail": "curl -s http://<ip>/api/state", "mutating": false, "share": 0.6}]},
  {"example": "install latest apps"}
]}''') as Map<String, dynamic>;
    final report = routineReportFromJson(json);
    expect((report.sessions, report.tasks, report.routines.length), (74, 546, 2));
    final r = report.routines.first;
    expect((r.example, r.runs, r.sessions, r.clean), ('progress?', 5, 3, 0.8));
    expect(r.nodes, ['minipc']);
    expect(r.last, DateTime.fromMillisecondsSinceEpoch(1792900000000));
    expect((r.steps.single.key, r.steps.single.share, r.steps.single.mutating), ('Bash:curl', 0.6, false));
    final bare = report.routines.last;
    expect((bare.runs, bare.first, bare.clean), (0, null, 1));
    expect(bare.steps, isEmpty);
  });

  test('the skills library maps: a list, and one skill with all its versions', () {
    final list = skillsFromJson(jsonDecode('''
{"skills": [{"name": "v2-sync-progress", "description": "Use when asked how far the sync is.", "status": "proposed", "mutating": true,
  "source": "progress?", "version": 2, "updatedMs": 1792900000000}]}''') as Map<String, dynamic>);
    expect(list.single.name, 'v2-sync-progress');
    expect((list.single.proposed, list.single.mutating, list.single.version), (true, true, 2));
    expect(list.single.updated, DateTime.fromMillisecondsSinceEpoch(1792900000000));

    final detail = skillDetailFromJson(jsonDecode('''
{"name": "v2-sync-progress", "description": "d", "status": "active", "mutating": false, "source": "progress?", "updatedMs": 1,
 "versions": [{"n": 1, "md": "first", "note": "first draft", "by": "Claude", "atMs": 1}, {"n": 2, "md": "second", "note": "fixed", "by": "Claude", "atMs": 2}]}''')
        as Map<String, dynamic>);
    expect((detail.info.active, detail.info.version, detail.versions.length), (true, 2, 2));
    expect(detail.latest?.text, 'second');
    expect(detail.versions.first.note, 'first draft');
  });
}
