import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../entities/prompt_desk.dart';
import '../repositories/prompt_desk_repository.dart';

/// The standing rules: list, add, change, switch, remove.
class Rules {
  const Rules(this._desk);
  final PromptDeskRepository _desk;

  Future<Result<List<Rule>>> list() => _desk.rules();

  Future<Result<Rule>> save(Rule rule) async {
    final text = rule.text.trim();
    if (text.isEmpty) return const Err(ValidationFailure('A rule needs its text.'));
    if (text.length > 2000) return const Err(ValidationFailure('A rule is at most 2,000 characters; split it in two.'));
    if (rule.scope != RuleScope.everywhere && rule.node.isEmpty) return const Err(ValidationFailure('Pick the device it applies to.'));
    if (rule.scope == RuleScope.project && rule.cwd.trim().isEmpty) return const Err(ValidationFailure('Pick the project folder.'));
    return _desk.saveRule(rule.copyWith(text: text, name: rule.name.trim(), cwd: rule.cwd.trim()));
  }

  Future<Result<Rule>> setOn(Rule rule, bool on) => _desk.saveRule(rule.copyWith(on: on));
  Future<Result<void>> delete(String id) => _desk.deleteRule(id);
}

/// What the hub measures, and the analyses Claude makes of it.
class Insights {
  const Insights(this._desk);
  final PromptDeskRepository _desk;

  Future<Result<InsightStats>> stats({int days = 30}) => _desk.insightStats(days: days);
  Future<Result<List<InsightReport>>> reports() => _desk.insightReports();
  Future<Result<InsightReport>> analyze({int days = 30}) => _desk.analyze(days: days);

  /// A recommended rule is added switched off, for the user to read first.
  Future<Result<Rule>> addRule(Recommendation r) => _desk.saveRule(Rule(name: r.title, text: r.text));
  Future<Result<String>> draftSkill(Recommendation r) => _desk.draftSkillFrom(r.title, r.text);
}
