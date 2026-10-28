import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

class DevicesState extends Equatable {
  const DevicesState({
    this.devices = const [],
    this.tailnet = const [],
    this.clients,
    this.tailnetError,
    this.loading = false,
    this.invite,
    this.failure,
    this.failureId = 0,
  });

  final List<PairedDevice> devices;
  final List<TailnetDevice> tailnet;

  /// Apps connected now; null when the hub can't list them (before 0.15).
  final List<ConnectedClient>? clients;

  /// Why the tailnet couldn't be listed (e.g. no Tailscale on the hub).
  final String? tailnetError;
  final bool loading;

  /// The pairing code being shown, until it expires or is closed.
  final PairingInvite? invite;
  final Failure? failure;
  final int failureId;

  DevicesState copyWith({
    List<PairedDevice>? devices,
    List<TailnetDevice>? tailnet,
    List<ConnectedClient>? Function()? clients,
    String? Function()? tailnetError,
    bool? loading,
    PairingInvite? Function()? invite,
    Failure? failure,
    int? failureId,
  }) =>
      DevicesState(
        devices: devices ?? this.devices,
        tailnet: tailnet ?? this.tailnet,
        clients: clients == null ? this.clients : clients(),
        tailnetError: tailnetError == null ? this.tailnetError : tailnetError(),
        loading: loading ?? this.loading,
        invite: invite == null ? this.invite : invite(),
        failure: failure ?? this.failure,
        failureId: failureId ?? this.failureId,
      );

  @override
  List<Object?> get props => [devices, tailnet, clients, tailnetError, loading, invite, failure, failureId];
}

/// View model for paired devices: list, invite a new one, revoke another,
/// or disconnect this one.
class DevicesCubit extends Cubit<DevicesState> {
  DevicesCubit({
    required this._list,
    required this._invite,
    required this._revoke,
    required this._tailnet,
    required this._disconnect,
    required this._clients,
  }) : super(const DevicesState());

  final ListClients _clients;

  final LoadTailnet _tailnet;

  final ListDevices _list;
  final CreatePairingInvite _invite;
  final RevokeDevice _revoke;
  final DisconnectThisDevice _disconnect;

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final clients = await _clients();
    emit(state.copyWith(clients: () => clients.valueOrNull));
    final tailnet = await _tailnet();
    tailnet.fold(
      (f) => emit(state.copyWith(tailnetError: () => f.userMessage)),
      (devices) => emit(state.copyWith(tailnet: devices, tailnetError: () => null)),
    );
    final result = await _list();
    result.fold(
      (f) => emit(state.copyWith(loading: false, failure: f, failureId: state.failureId + 1)),
      (devices) => emit(state.copyWith(loading: false, devices: devices)),
    );
  }

  Future<void> invite() async {
    final result = await _invite();
    result.fold(
      (f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)),
      (invite) => emit(state.copyWith(invite: () => invite)),
    );
  }

  /// Closes the invite; the list is refreshed since someone may have paired.
  void closeInvite() {
    emit(state.copyWith(invite: () => null));
    unawaited(load());
  }

  Future<void> revoke(String id) async {
    final result = await _revoke(id);
    result.fold(
      (f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)),
      (_) => emit(state.copyWith(devices: state.devices.where((d) => d.id != id).toList())),
    );
  }

  Future<void> disconnectThisDevice() async {
    final result = await _disconnect();
    result.fold(
      (f) => emit(state.copyWith(failure: f, failureId: state.failureId + 1)),
      (_) => emit(state.copyWith(devices: const [], tailnet: const [])),
    );
  }
}
