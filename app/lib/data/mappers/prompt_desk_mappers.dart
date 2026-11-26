import '../../domain/entities/prompt_desk.dart';

// The hub's rules and insights are plain JSON; missing fields get quiet defaults.

int _int(Object? v) => v is num ? v.toInt() : 0;
double _double(Object? v) => v is num ? v.toDouble() : 0;
String _str(Object? v) => v is String ? v : '';
List<Map<String, dynamic>> _list(Object? v) => v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
Map<String, dynamic> _map(Object? v) => v is Map<String, dynamic> ? v : const {};
DateTime? _time(Object? ms) => _int(ms) > 0 ? DateTime.fromMillisecondsSinceEpoch(_int(ms)) : null;

Rule ruleFromJson(Map<String, dynamic> j) => Rule(
      id: _str(j['id']),
      name: _str(j['name']),
      text: _str(j['text']),
      scope: RuleScope.fromWire(_str(j['scope'])),
      node: _str(j['node']),
      cwd: _str(j['cwd']),
      on: j['on'] == true,
      updated: _time(j['updatedMs']),
    );

Map<String, Object?> ruleToJson(Rule r) => {
      'name': r.name,
      'text': r.text,
      'scope': r.scope.wire,
      if (r.scope != RuleScope.everywhere) 'node': r.node,
      if (r.scope == RuleScope.project) 'cwd': r.cwd,
      'on': r.on,
    };

List<Rule> rulesFromJson(Map<String, dynamic> j) => [for (final r in _list(j['rules'])) ruleFromJson(r)];

Spread _spread(Object? v) {
  final j = _map(v);
  return Spread(count: _int(j['count']), median: _int(j['median']), p90: _int(j['p90']), max: _int(j['max']), total: _int(j['total']));
}

List<Counted> _counted(Object? v) => [for (final x in _list(v)) Counted(_str(x['label']), _int(x['count']))];

InsightStats insightStatsFromJson(Map<String, dynamic> j) {
  final tokens = _map(j['tokens']);
  final cost = _map(j['cost']);
  final approvals = _map(j['approvals']);
  final sample = _map(j['sample']);
  return InsightStats(
    days: _int(j['days']),
    chats: _int(j['chats']),
    messages: _int(j['messages']),
    prompts: _int(j['prompts']),
    messagesPerChat: _spread(j['messagesPerChat']),
    promptsPerChat: _spread(j['promptsPerChat']),
    promptLength: _spread(j['promptLength']),
    promptLengths: _counted(j['promptLengths']),
    longAsFile: _int(j['longAsFile']),
    multiSessionChats: _int(j['multiSessionChats']),
    lineage: _counted(j['lineage']),
    repeatedPrompts: _int(j['repeatedPrompts']),
    restarts: _int(j['restarts']),
    restartsBack: [for (final x in _list(j['restartsBack'])) Counted('${_int(x['back'])}', _int(x['count']))],
    input: _int(tokens['input']),
    output: _int(tokens['output']),
    cacheWrite: _int(tokens['cacheWrite']),
    cacheRead: _int(tokens['cacheRead']),
    cacheReadShare: _double(tokens['cacheReadShare']),
    tokenSessions: _int(tokens['sessions']),
    perSession: _spread(tokens['perSession']),
    topSessions: [
      for (final s in _list(tokens['top']))
        SessionTokens(session: _str(s['session']), title: _str(s['title']), model: _str(s['model']), total: _int(s['total']), cacheRead: _int(s['cacheRead']), messages: _int(s['messages'])),
    ],
    costUsd: _double(cost['usd']),
    costNote: _str(cost['note']),
    unpriced: _int(cost['unpriced']),
    toolCalls: _int(j['toolCalls']),
    toolErrors: _int(j['toolErrors']),
    tools: [for (final t in _list(j['tools'])) ToolUse(_str(t['name']), _int(t['calls']), _int(t['errors']))],
    allowed: _int(approvals['allowed']),
    denied: _int(approvals['denied']),
    phrases: [
      for (final p in _list(j['phrases'])) RepeatedPhrase(label: _str(p['label']), rule: _str(p['rule']), prompts: _int(p['prompts']), chats: _int(p['chats'])),
    ],
    models: [for (final m in _list(j['models'])) Counted(_str(m['model']), _int(m['messages']))],
    sampleChats: _int(sample['chats']),
    sampleMessages: _int(sample['messages']),
  );
}

InsightReport insightReportFromJson(Map<String, dynamic> j) {
  final sample = _map(j['sample']);
  return InsightReport(
    id: _str(j['id']),
    session: _str(j['session']),
    days: _int(j['days']),
    running: j['status'] == 'running',
    started: _time(j['startedMs']),
    saved: _time(j['savedMs']),
    sampleChats: _int(sample['chats']),
    sampleMessages: _int(sample['messages']),
    title: _str(j['title']),
    summary: _str(j['summary']),
    recommendations: [
      for (final r in _list(j['recommendations']))
        Recommendation(
          kind: RecommendationKind.values.firstWhere((k) => k.name == r['kind'], orElse: () => RecommendationKind.context),
          title: _str(r['title']),
          why: _str(r['why']),
          text: _str(r['text']),
        ),
    ],
  );
}

List<InsightReport> insightReportsFromJson(Map<String, dynamic> j) => [for (final r in _list(j['reports'])) insightReportFromJson(r)];
