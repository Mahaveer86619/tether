import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tether/data/mappers/prompt_desk_mappers.dart';
import 'package:tether/domain/entities/prompt_desk.dart';

void main() {
  test('rules map both ways, and the scope decides which fields are sent', () {
    final list = rulesFromJson(jsonDecode('''
{"rules": [{"id": "a1", "name": "Docs", "text": "Keep docs current.", "scope": "project", "node": "laptop", "cwd": "/src/t", "on": true, "updatedMs": 1792900000000},
 {"id": "b2", "text": "Short.", "scope": "weird"}]}''') as Map<String, dynamic>);
    expect((list.first.scope, list.first.node, list.first.cwd, list.first.on), (RuleScope.project, 'laptop', '/src/t', true));
    expect(list.first.updated, DateTime.fromMillisecondsSinceEpoch(1792900000000));
    expect((list.last.scope, list.last.on), (RuleScope.everywhere, false));
    expect(ruleToJson(const Rule(text: 'x', scope: RuleScope.device, node: 'pc', cwd: '/ignored')), {'name': '', 'text': 'x', 'scope': 'device', 'node': 'pc', 'on': false});
  });

  test("the hub's stats and reports map, with quiet defaults for what is missing", () {
    final st = insightStatsFromJson(jsonDecode('''
{"days": 30, "chats": 2, "messages": 9, "prompts": 6,
 "messagesPerChat": {"count": 2, "median": 3, "p90": 6, "max": 6, "total": 9},
 "restartsBack": [{"back": 1, "count": 1}], "lineage": [{"label": "move", "count": 1}],
 "tokens": {"sessions": 2, "cacheRead": 2000000, "cacheReadShare": 0.4, "top": [{"session": "a1", "title": "T", "total": 3100000}]},
 "cost": {"estimate": true, "usd": 13.15, "unpriced": 1}, "approvals": {"allowed": 2, "denied": 1},
 "tools": [{"name": "Bash", "calls": 2, "errors": 1}], "models": [{"model": "claude-opus-5-5", "messages": 1}],
 "sample": {"chats": 2, "messages": 9}}''') as Map<String, dynamic>);
    expect((st.chats, st.messagesPerChat.p90, st.restartsBack.single, st.lineage.single), (2, 6, const Counted('1', 1), const Counted('move', 1)));
    expect((st.cacheReadShare, st.topSessions.single.total, st.costUsd, st.unpriced), (0.4, 3100000, 13.15, 1));
    expect((st.allowed, st.denied, st.tools.single, st.models.single.label), (2, 1, const ToolUse('Bash', 2, 1), 'claude-opus-5-5'));
    expect((st.sampleChats, st.sampleMessages, st.promptLength), (2, 9, const Spread()));

    final reports = insightReportsFromJson(jsonDecode('''
{"reports": [{"id": "r1", "session": "s", "status": "running", "startedMs": 1, "sample": {"chats": 2, "messages": 9}, "recommendations": []},
 {"id": "r0", "status": "saved", "title": "T", "summary": "S", "recommendations": [{"kind": "skill", "title": "x", "text": "y"}, {"kind": "?", "title": "a", "text": "b"}]}]}''')
        as Map<String, dynamic>);
    expect((reports.first.running, reports.first.sampleMessages), (true, 9));
    expect([for (final r in reports.last.recommendations) r.kind], [RecommendationKind.skill, RecommendationKind.context]);
  });
}
