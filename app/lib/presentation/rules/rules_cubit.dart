import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/prompt_desk.dart';
import '../../domain/usecases/prompt_desk_usecases.dart';
import '../../domain/usecases/usecases.dart';

class RulesState extends Equatable {
  const RulesState({
    this.rules = const [],
    this.loading = true,
    this.busy = const {},
    this.devices = const [],
    this.folders = const {},
    this.added = '',
    this.addedId = 0,
    this.failure,
    this.failureId = 0,
  });

  final List<Rule> rules;
  final bool loading;

  /// Rule ids (or suggested texts) with a request under way.
  final Set<String> busy;

  /// The devices the hub knows, and the project folders seen on each, to pick a scope from.
  final List<String> devices;
  final Map<String, List<String>> folders;

  /// The name of a rule just added; [addedId] counts them.
  final String added;
  final int addedId;
  final Failure? failure;
  final int failureId;

  /// Suggested rules not added yet.
  List<({String name, String text})> get suggestions => [
        for (final s in suggestedRules)
          if (!rules.any((r) => r.text.trim() == s.text)) s,
      ];

  RulesState copyWith({
    List<Rule>? rules,
    bool? loading,
    Set<String>? busy,
    List<String>? devices,
    Map<String, List<String>>? folders,
    String? added,
    int? addedId,
    Failure? failure,
    int? failureId,
  }) =>
      RulesState(
        rules: rules ?? this.rules,
        loading: loading ?? this.loading,
        busy: busy ?? this.busy,
        devices: devices ?? this.devices,
        folders: folders ?? this.folders,
        added: added ?? this.added,
        addedId: addedId ?? this.addedId,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [rules, loading, busy, devices, folders, added, addedId, failure, failureId];
}

/// View model for the Rules page: the standing instructions every session
/// they cover is given, and starters to add. Nothing is switched on for the
/// user: a rule added from a suggestion starts off.
class RulesCubit extends Cubit<RulesState> {
  RulesCubit({required this._rules, required this._watchHub}) : super(const RulesState());

  final Rules _rules;
  final WatchHub _watchHub;

  Future<void> load() async {
    final hub = _watchHub.current;
    final folders = <String, Set<String>>{};
    for (final s in hub.sessions.values) {
      if (isProjectFolder(s.cwd)) (folders[s.node] ??= {}).add(s.cwd);
    }
    emit(state.copyWith(
      loading: true,
      devices: {...hub.nodes.keys, ...folders.keys}.toList()..sort(),
      folders: {for (final e in folders.entries) e.key: e.value.toList()..sort()},
    ));
    final r = await _rules.list();
    if (isClosed) return;
    emit(state.copyWith(loading: false, rules: r.valueOrNull, failure: r.failureOrNull, failureId: _next(r)));
  }

  int _next(Result<Object?> r) => r.failureOrNull == null ? state.failureId : state.failureId + 1;

  /// Adds a new rule or saves changes to one; true when it was saved.
  Future<bool> save(Rule rule) async {
    final key = rule.id.isEmpty ? rule.text : rule.id;
    emit(state.copyWith(busy: {...state.busy, key}));
    final r = await _rules.save(rule);
    if (isClosed) return false;
    final saved = r.valueOrNull;
    emit(state.copyWith(
      busy: {...state.busy}..remove(key),
      rules: saved == null ? null : _merged(saved),
      added: rule.id.isEmpty && saved != null ? saved.name : null,
      addedId: rule.id.isEmpty && saved != null ? state.addedId + 1 : null,
      failure: r.failureOrNull,
      failureId: _next(r),
    ));
    return saved != null;
  }

  Future<bool> addSuggested(({String name, String text}) s) => save(Rule(name: s.name, text: s.text));

  Future<void> setOn(Rule rule, bool on) async {
    emit(state.copyWith(busy: {...state.busy, rule.id}, rules: _merged(rule.copyWith(on: on))));
    final r = await _rules.setOn(rule, on);
    if (isClosed) return;
    emit(state.copyWith(
      busy: {...state.busy}..remove(rule.id),
      rules: _merged(r.valueOrNull ?? rule),
      failure: r.failureOrNull,
      failureId: _next(r),
    ));
  }

  Future<void> delete(Rule rule) async {
    emit(state.copyWith(busy: {...state.busy, rule.id}));
    final r = await _rules.delete(rule.id);
    if (isClosed) return;
    emit(state.copyWith(
      busy: {...state.busy}..remove(rule.id),
      rules: r.isOk ? [for (final x in state.rules) if (x.id != rule.id) x] : null,
      failure: r.failureOrNull,
      failureId: _next(r),
    ));
  }

  List<Rule> _merged(Rule rule) {
    final i = state.rules.indexWhere((x) => x.id == rule.id);
    if (i < 0) return [...state.rules, rule];
    return [...state.rules]..[i] = rule;
  }
}
