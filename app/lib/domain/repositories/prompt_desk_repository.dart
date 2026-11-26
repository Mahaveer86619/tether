import '../../core/result.dart';
import '../entities/prompt_desk.dart';

/// The hub's standing rules and its insights into how Tether is used.
abstract interface class PromptDeskRepository {
  Future<Result<List<Rule>>> rules();

  /// Adds [rule] when it has no id, replaces the one with its id otherwise.
  Future<Result<Rule>> saveRule(Rule rule);
  Future<Result<void>> deleteRule(String id);

  /// [days] 0 means all of history.
  Future<Result<InsightStats>> insightStats({int days = 30});

  /// Saved and running analyses, newest first.
  Future<Result<List<InsightReport>>> insightReports();

  /// Starts an analysis session; the report shows in [insightReports] when it is saved.
  Future<Result<InsightReport>> analyze({int days = 30});

  /// Starts a session that drafts a skill from a recommendation; returns its id.
  Future<Result<String>> draftSkillFrom(String title, String idea);
}
