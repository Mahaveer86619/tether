import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class TeamState extends Equatable {
  const TeamState({this.users = const [], this.loading = false, this.invite, this.failure, this.failureId = 0});

  final List<TeamUser> users;
  final bool loading;

  /// The invite code being shown, until it is closed.
  final PairingInvite? invite;
  final Failure? failure;
  final int failureId;

  TeamState copyWith({List<TeamUser>? users, bool? loading, PairingInvite? Function()? invite, Failure? failure, int? failureId}) => TeamState(
        users: users ?? this.users,
        loading: loading ?? this.loading,
        invite: invite == null ? this.invite : invite(),
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [users, loading, invite, failure, failureId];
}

/// View model for the team: who is on the hub, inviting and removing them,
/// and sharing this user's devices with them.
class TeamCubit extends Cubit<TeamState> {
  TeamCubit({required this._team}) : super(const TeamState());

  final ManageTeam _team;

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final r = await _team.users();
    r.fold(
      (f) => emit(state.copyWith(loading: false, failure: f, failureId: state.failureId + 1)),
      (users) => emit(state.copyWith(loading: false, users: users)),
    );
  }

  Future<void> invite() async {
    final r = await _team.invite();
    r.fold(
      (f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)),
      (invite) => emit(state.copyWith(invite: () => invite)),
    );
  }

  /// Closes the invite; someone may have joined with it.
  Future<void> closeInvite() async {
    emit(state.copyWith(invite: () => null));
    await load();
  }

  Future<void> remove(String id) async {
    final r = await _team.remove(id);
    r.fold(
      (f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)),
      (_) => emit(state.copyWith(users: [for (final u in state.users) if (u.id != id) u])),
    );
  }

  /// Returns whether it worked; the device's new grants come with its status.
  Future<bool> share(String node, String user, DeviceAccess access) => _done(_team.share(node, user, access));

  Future<bool> unshare(String node, String user) => _done(_team.unshare(node, user));

  Future<bool> _done(Future<Result<void>> call) async {
    final r = await call;
    return r.fold(
      (f) {
        emit(state.copyWith(failure: f, failureId: state.failureId + 1));
        return false;
      },
      (_) => true,
    );
  }
}
