import 'package:equatable/equatable.dart';

/// Where a standing rule applies.
enum RuleScope {
  everywhere('all'),
  device('device'),
  project('project');

  const RuleScope(this.wire);

  /// The hub's name for it.
  final String wire;

  static RuleScope fromWire(String s) => values.firstWhere((v) => v.wire == s, orElse: () => everywhere);
}

/// A standing instruction the hub adds to the prompt of every session it
/// covers. See docs/plans/prompt-desk.md#rules.
class Rule extends Equatable {
  const Rule({this.id = '', this.name = '', required this.text, this.scope = RuleScope.everywhere, this.node = '', this.cwd = '', this.on = false, this.updated});

  final String id, name, text, node, cwd;
  final RuleScope scope;
  final bool on;
  final DateTime? updated;

  /// Where it applies, for a line under the rule.
  String get where => switch (scope) {
        RuleScope.everywhere => 'Everywhere',
        RuleScope.device => 'On $node',
        RuleScope.project => '$node · $cwd',
      };

  Rule copyWith({String? name, String? text, RuleScope? scope, String? node, String? cwd, bool? on}) => Rule(
        id: id,
        name: name ?? this.name,
        text: text ?? this.text,
        scope: scope ?? this.scope,
        node: node ?? this.node,
        cwd: cwd ?? this.cwd,
        on: on ?? this.on,
        updated: updated,
      );

  @override
  List<Object?> get props => [id, name, text, scope, node, cwd, on, updated];
}

/// Rules worth starting with, from the instructions the owner's own chats
/// repeated most (docs/plans/prompt-desk.md#what-the-data-says).
const suggestedRules = <({String name, String text})>[
  (name: "Don't commit or push", text: 'Do not commit or push unless I ask; commit locally only when asked.'),
  (name: 'Read the logs first', text: 'Read the logs before proposing a fix.'),
  (name: 'Docs with the change', text: 'Update docs/ and the README in the same change as the behaviour.'),
  (name: 'Keep replies short', text: 'Keep replies short.'),
  (name: 'Read-only on copies', text: 'For a read-only task, work on copies and never change the original.'),
  (name: 'Verify before done', text: 'Verify (run the build and tests) before saying it is done.'),
  (name: 'Never restart services', text: 'Never restart a running service unless told to.'),
];

/// Count, median, 90th percentile and largest of a distribution.
class Spread extends Equatable {
  const Spread({this.count = 0, this.median = 0, this.p90 = 0, this.max = 0, this.total = 0});

  final int count, median, p90, max, total;

  @override
  List<Object?> get props => [count, median, p90, max, total];
}

class Counted extends Equatable {
  const Counted(this.label, this.count);

  final String label;
  final int count;

  @override
  List<Object?> get props => [label, count];
}

class SessionTokens extends Equatable {
  const SessionTokens({required this.session, this.title = '', this.model = '', this.total = 0, this.cacheRead = 0, this.messages = 0});

  final String session, title, model;
  final int total, cacheRead, messages;

  @override
  List<Object?> get props => [session, title, model, total, cacheRead, messages];
}

class ToolUse extends Equatable {
  const ToolUse(this.name, this.calls, this.errors);

  final String name;
  final int calls, errors;

  @override
  List<Object?> get props => [name, calls, errors];
}

class RepeatedPhrase extends Equatable {
  const RepeatedPhrase({required this.label, required this.rule, this.prompts = 0, this.chats = 0});

  final String label, rule;
  final int prompts, chats;

  @override
  List<Object?> get props => [label, rule, prompts, chats];
}

/// What the hub measured over its saved data, without a model.
class InsightStats extends Equatable {
  const InsightStats({
    this.days = 30,
    this.chats = 0,
    this.messages = 0,
    this.prompts = 0,
    this.messagesPerChat = const Spread(),
    this.promptsPerChat = const Spread(),
    this.promptLength = const Spread(),
    this.promptLengths = const [],
    this.longAsFile = 0,
    this.multiSessionChats = 0,
    this.lineage = const [],
    this.repeatedPrompts = 0,
    this.restarts = 0,
    this.restartsBack = const [],
    this.input = 0,
    this.output = 0,
    this.cacheWrite = 0,
    this.cacheRead = 0,
    this.cacheReadShare = 0,
    this.tokenSessions = 0,
    this.perSession = const Spread(),
    this.topSessions = const [],
    this.costUsd = 0,
    this.costNote = '',
    this.unpriced = 0,
    this.toolCalls = 0,
    this.toolErrors = 0,
    this.tools = const [],
    this.allowed = 0,
    this.denied = 0,
    this.phrases = const [],
    this.models = const [],
    this.sampleChats = 0,
    this.sampleMessages = 0,
  });

  final int days, chats, messages, prompts;
  final Spread messagesPerChat, promptsPerChat, promptLength;
  final List<Counted> promptLengths;
  final int longAsFile, multiSessionChats;

  /// Moves, forks and continues, by kind.
  final List<Counted> lineage;
  final int repeatedPrompts, restarts;

  /// Restarts by how many prompts back they went, labelled "1", "2"...
  final List<Counted> restartsBack;
  final int input, output, cacheWrite, cacheRead;
  final double cacheReadShare;
  final int tokenSessions;
  final Spread perSession;
  final List<SessionTokens> topSessions;

  /// An estimate from list prices, never a bill.
  final double costUsd;
  final String costNote;
  final int unpriced;
  final int toolCalls, toolErrors;
  final List<ToolUse> tools;
  final int allowed, denied;
  final List<RepeatedPhrase> phrases;

  /// Assistant messages per model.
  final List<Counted> models;

  /// What Analyze would send: the masked sample's size.
  final int sampleChats, sampleMessages;

  @override
  List<Object?> get props => [
        days, chats, messages, prompts, messagesPerChat, promptsPerChat, promptLength, promptLengths, longAsFile, multiSessionChats, lineage,
        repeatedPrompts, restarts, restartsBack, input, output, cacheWrite, cacheRead, cacheReadShare, tokenSessions, perSession, topSessions,
        costUsd, costNote, unpriced, toolCalls, toolErrors, tools, allowed, denied, phrases, models, sampleChats, sampleMessages,
      ];
}

enum RecommendationKind { rule, skill, context }

class Recommendation extends Equatable {
  const Recommendation({required this.kind, required this.title, this.why = '', required this.text});

  final RecommendationKind kind;
  final String title, why, text;

  @override
  List<Object?> get props => [kind, title, why, text];
}

/// An analysis by a Claude session, saved through save_insight.
class InsightReport extends Equatable {
  const InsightReport({
    required this.id,
    this.session = '',
    this.days = 30,
    this.running = false,
    this.started,
    this.saved,
    this.sampleChats = 0,
    this.sampleMessages = 0,
    this.title = '',
    this.summary = '',
    this.recommendations = const [],
  });

  final String id, session;
  final int days;

  /// Started and not saved yet.
  final bool running;
  final DateTime? started, saved;
  final int sampleChats, sampleMessages;
  final String title, summary;
  final List<Recommendation> recommendations;

  @override
  List<Object?> get props => [id, session, days, running, started, saved, sampleChats, sampleMessages, title, summary, recommendations];
}
