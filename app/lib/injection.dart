import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'data/datasources/file_downloads.dart';
import 'data/datasources/hub_cache.dart';
import 'data/datasources/hub_rest_api.dart';
import 'data/datasources/hub_socket.dart';
import 'data/datasources/hub_tls.dart';
import 'data/datasources/settings_local.dart';
import 'data/repositories/hub_repository_impl.dart';
import 'data/repositories/settings_repository_impl.dart';
import 'data/repositories/transfer_repository_impl.dart';
import 'domain/entities/entities.dart';
import 'domain/repositories/repositories.dart';
import 'domain/usecases/usecases.dart';
import 'presentation/artifacts/artifacts_cubit.dart';
import 'presentation/artifacts/pages_view.dart';
import 'presentation/settings/codebases_section.dart';
import 'presentation/hub/hub_cubit.dart';
import 'presentation/new_session/new_session_cubit.dart';
import 'presentation/session/session_bloc.dart';
import 'presentation/session/terminal_cubit.dart';
import 'presentation/settings/devices_cubit.dart';
import 'presentation/settings/settings_cubit.dart';
import 'presentation/settings/workspaces_section.dart';
import 'presentation/usage/usage_cubit.dart';

final sl = GetIt.instance;

/// Registers the object graph: data sources → repositories → use cases →
/// view models. Views get view models from here and never see the layers
/// below. Tests register fake repositories themselves and pass
/// `withData: false`.
void configureDependencies({bool withData = true}) {
  // Android reports "localhost" as its host name.
  final deviceName = Platform.isAndroid || Platform.localHostname.isEmpty ? '${_title(Platform.operatingSystem)} device' : Platform.localHostname;
  if (withData) {
    final client = '$deviceName (${Platform.operatingSystem})';
    sl
      ..registerLazySingleton(HubTls.new)
      ..registerLazySingleton<http.Client>(() => IOClient(sl<HubTls>().httpClient), dispose: (c) => c.close())
      ..registerLazySingleton(() => HubRestApi(sl(), clientName: client, tls: sl()))
      ..registerLazySingleton<HubSocket>(
        () => WebSocketHubSocket(clientName: client, platform: Platform.operatingSystem, httpClient: sl<HubTls>().httpClient),
      )
      ..registerLazySingleton(SettingsLocalDataSource.new)
      ..registerLazySingleton<HubCache>(FileHubCache.new)
      ..registerLazySingleton<HubRepository>(
        () => HubRepositoryImpl(api: sl(), socket: sl(), cache: sl()),
        dispose: (r) => r.dispose(),
      )
      ..registerLazySingleton<SettingsRepository>(() => SettingsRepositoryImpl(sl()))
      ..registerLazySingleton<FileDownloads>(BackgroundFileDownloads.new)
      ..registerLazySingleton<TransferRepository>(() => TransferRepositoryImpl(api: sl(), downloads: sl()), dispose: (r) => (r as TransferRepositoryImpl).dispose());
  }

  sl
    // Use cases
    ..registerLazySingleton(() => WatchHub(sl()))
    ..registerLazySingleton(() => WatchTimeline(sl()))
    ..registerLazySingleton(() => RetryConnection(sl()))
    ..registerLazySingleton(() => CreateSession(sl()))
    ..registerLazySingleton(() => SendMessage(sl()))
    ..registerLazySingleton(() => InterruptSession(sl()))
    ..registerLazySingleton(() => EndSession(sl()))
    ..registerLazySingleton(() => DecideApproval(sl()))
    ..registerLazySingleton(() => SetSessionArchived(sl()))
    ..registerLazySingleton(() => LoadConnection(sl()))
    ..registerLazySingleton(() => SaveConnection(sl(), sl()))
    ..registerLazySingleton(() => ThemeSettings(sl()))
    ..registerLazySingleton(() => PairThisDevice(sl(), sl(), name: deviceName, platform: Platform.operatingSystem))
    ..registerLazySingleton(() => CreatePairingInvite(sl()))
    ..registerLazySingleton(() => SharePreferences(sl()))
    ..registerLazySingleton(() => ConnectOverTailnet(sl(), sl()))
    ..registerLazySingleton(() => Drafts(sl()))
    ..registerLazySingleton(() => Outbox(sl()))
    ..registerLazySingleton(() => LoadTailnet(sl()))
    ..registerLazySingleton(() => ListClients(sl()))
    ..registerLazySingleton(() => LoadUsage(sl()))
    ..registerLazySingleton(() => LoadWorkspaces(sl()))
    ..registerLazySingleton(() => SetSessionGlobal(sl()))
    ..registerLazySingleton(() => ContinueOnHub(sl()))
    ..registerLazySingleton(() => Artifacts(sl()))
    ..registerLazySingleton(() => Transfers(sl()))
    ..registerLazySingleton(() => TerminalControl(sl()))
    ..registerLazySingleton(() => SetPermissionMode(sl()))
    ..registerFactoryParam<TerminalCubit, String, void>((sessionId, _) => TerminalCubit(sessionId: sessionId, terminal: sl()))
    ..registerLazySingleton(() => SetWorkspaceRoot(sl()))
    ..registerLazySingleton(() => ListDevices(sl()))
    ..registerLazySingleton(() => RevokeDevice(sl()))
    ..registerLazySingleton(() => DisconnectThisDevice(sl(), sl()))
    // View models
    ..registerFactory(() => HubCubit(watchHub: sl(), decideApproval: sl(), setArchived: sl(), retry: sl(), setMode: sl()))
    ..registerFactory(() => SettingsCubit(load: sl(), save: sl(), pair: sl(), theme: sl(), share: sl(), viaTailnet: sl()))
    ..registerFactory(() => UsageCubit(load: sl()))
    ..registerFactory(() => ArtifactsCubit(artifacts: sl(), transfers: sl()))
    ..registerFactory(() => PagesCubit(artifacts: sl()))
    ..registerLazySingleton(() => Codebases(sl()))
    ..registerFactory(() => CodebasesCubit(codebases: sl()))
    ..registerFactory(() => WorkspacesCubit(load: sl(), set: sl()))
    ..registerFactory(() => DevicesCubit(list: sl(), invite: sl(), revoke: sl(), tailnet: sl(), disconnect: sl(), clients: sl()))
    ..registerFactoryParam<SessionBloc, String, void>(
      (sessionId, _) =>
          SessionBloc(
        sessionId: sessionId,
        watchHub: sl(),
        watchTimeline: sl(),
        sendMessage: sl(),
        interrupt: sl(),
        endSession: sl(),
        drafts: sl(),
        setGlobal: sl(),
        continueOnHub: sl(),
        outbox: sl(),
      ),
    )
    ..registerFactoryParam<NewSessionCubit, HubSnapshot, String?>(
      (hub, preferredNode) => NewSessionCubit(
        hub: hub,
        createSession: sl(),
        drafts: sl(),
        loadWorkspaces: sl(),
        setRoot: sl(),
        preferredNode: preferredNode,
      ),
    );
}

String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
