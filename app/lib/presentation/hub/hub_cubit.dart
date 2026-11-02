import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import '../widgets/common.dart';

class HubState extends Equatable {
  const HubState({this.hub = const HubSnapshot(), this.deciding = const {}, this.failure, this.failureId = 0});

  final HubSnapshot hub;

  /// Approvals with an answer in flight.
  final Set<String> deciding;

  /// The latest action failure; [failureId] changes each time so the same
  /// failure twice still shows twice.
  final Failure? failure;
  final int failureId;

  HubState copyWith({HubSnapshot? hub, Set<String>? deciding, Failure? failure, int? failureId}) => HubState(
        hub: hub ?? this.hub,
        deciding: deciding ?? this.deciding,
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [hub, deciding, failure, failureId];
}

/// App-wide view model: connection, devices, sessions and approvals.
class HubCubit extends Cubit<HubState> {
  HubCubit({
    required WatchHub watchHub,
    required DecideApproval decideApproval,
    required this._setArchived,
    required this._retry,
    required this._setMode,
    required this._presence,
  })  : _decide = decideApproval,
        super(const HubState()) {
    _sub = watchHub().listen((hub) => emit(state.copyWith(hub: hub)));
  }

  final DecideApproval _decide;
  final SetSessionArchived _setArchived;
  final SetPermissionMode _setMode;
  final ReportPresence _presence;

  void setActive({required bool active}) => _presence(active: active);
  final RetryConnection _retry;
  late final StreamSubscription<HubSnapshot> _sub;

  Future<void> decide(String approvalId, {required bool allow, String message = '', Map<String, String> answers = const {}, int option = 0}) async {
    if (state.deciding.contains(approvalId)) return;
    emit(state.copyWith(deciding: {...state.deciding, approvalId}));
    final result = await _decide(approvalId, allow: allow, message: message, answers: answers, option: option);
    final deciding = {...state.deciding}..remove(approvalId);
    result.fold(
      (f) => emit(state.copyWith(deciding: deciding, failure: f, failureId: state.failureId + 1)),
      (_) => emit(state.copyWith(deciding: deciding)),
    );
  }

  Future<void> setArchived(String sessionId, {required bool archived}) async {
    final result = await _setArchived(sessionId, archived: archived);
    result.fold((f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)), (_) {});
  }

  Future<void> setMode(String sessionId, PermissionMode mode, {Duration? revertAfter}) async {
    final result = await _setMode(sessionId, mode, revertAfter: revertAfter);
    result.fold((f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)), (_) {});
  }

  /// Allows a tool request and switches the session's mode with it, e.g.
  /// approving a plan and letting the edits go ahead.
  Future<void> decideWithMode(String approvalId, String sessionId, PermissionMode mode) async {
    await decide(approvalId, allow: true);
    await setMode(sessionId, mode);
  }

  void retry() => _retry();

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}

/// [ConnectionLine] for the hub this app is connected to, with Retry.
class HubConnectionLine extends StatelessWidget {
  const HubConnectionLine({super.key});

  @override
  Widget build(BuildContext context) {
    final (status, retryAt, attempts, error) = context.select<HubCubit, (ConnectionStatus, DateTime?, int, String?)>(
      (h) => (h.state.hub.status, h.state.hub.retryAt, h.state.hub.attempts, h.state.hub.lastError),
    );
    return ConnectionLine(status: status, retryAt: retryAt, attempts: attempts, error: error, onRetry: context.read<HubCubit>().retry);
  }
}
