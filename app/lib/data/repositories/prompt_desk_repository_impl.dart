import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/prompt_desk.dart';
import '../../domain/repositories/prompt_desk_repository.dart';
import '../datasources/hub_rest_api.dart';
import '../mappers/prompt_desk_mappers.dart';
import 'failure_mapper.dart';

class PromptDeskRepositoryImpl implements PromptDeskRepository {
  PromptDeskRepositoryImpl(this._api);

  final HubRestApi _api;

  Future<Result<T>> _call<T>(Future<T> Function() body) async {
    if (_api.endpoint == null) return const Err(NotConnectedFailure());
    return guard(body);
  }

  @override
  Future<Result<List<Rule>>> rules() => _call(() async => rulesFromJson(await _api.plainJson('GET', '/rules')));

  @override
  Future<Result<Rule>> saveRule(Rule rule) => _call(() async => ruleFromJson(await (rule.id.isEmpty
      ? _api.plainJson('POST', '/rules', body: ruleToJson(rule))
      : _api.plainJson('PUT', '/rules/${Uri.encodeComponent(rule.id)}', body: ruleToJson(rule)))));

  @override
  Future<Result<void>> deleteRule(String id) => _call(() => _api.plainJson('DELETE', '/rules/${Uri.encodeComponent(id)}'));

  @override
  Future<Result<InsightStats>> insightStats({int days = 30}) =>
      _call(() async => insightStatsFromJson(await _api.plainJson('GET', '/insights/stats', query: {'days': '$days'})));

  @override
  Future<Result<List<InsightReport>>> insightReports() => _call(() async => insightReportsFromJson(await _api.plainJson('GET', '/insights')));

  @override
  Future<Result<InsightReport>> analyze({int days = 30}) =>
      _call(() async => insightReportFromJson(await _api.plainJson('POST', '/insights/analyze', body: {'days': days})));

  @override
  Future<Result<String>> draftSkillFrom(String title, String idea) =>
      _call(() async => (await _api.plainJson('POST', '/skills/draft', body: {'example': title, 'idea': idea}))['session'] as String? ?? '');
}
