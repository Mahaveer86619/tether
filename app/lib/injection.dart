import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import 'data/datasources/hub_cache.dart';
import 'data/datasources/hub_rest_api.dart';
import 'data/datasources/hub_socket.dart';
import 'data/datasources/settings_local.dart';
import 'data/repositories/hub_repository_impl.dart';
import 'data/repositories/settings_repository_impl.dart';
import 'domain/entities/entities.dart';
import 'domain/repositories/repositories.dart';
import 'domain/usecases/usecases.dart';
import 'presentation/hub/hub_cubit.dart';
import 'presentation/new_session/new_session_cubit.dart';
import 'presentation/session/session_bloc.dart';
import 'presentation/settings/settings_cubit.dart';

final sl = GetIt.instance;

/// Registers the object graph: data sources → repositories → use cases →
/// view models. Views get view models from here and never see the layers
/// below. Tests register fake repositories themselves and pass
/// `withData: false`.
void configureDependencies({bool withData = true}) {
  if (withData) {
    final client =
        '${Platform.localHostname.isEmpty ? Platform.operatingSystem : Platform.localHostname} (${Platform.operatingSystem})';
    sl
      ..registerLazySingleton<http.Client>(http.Client.new, dispose: (c) => c.close())
      ..registerLazySingleton(() => HubRestApi(sl(), clientName: client))
      ..registerLazySingleton<HubSocket>(
        () => WebSocketHubSocket(clientName: client, platform: Platform.operatingSystem),
      )
      ..registerLazySingleton(SettingsLocalDataSource.new)
      ..registerLazySingleton<HubCache>(FileHubCache.new)
      ..registerLazySingleton<HubRepository>(
        () => HubRepositoryImpl(api: sl(), socket: sl(), cache: sl()),
        dispose: (r) => r.dispose(),
      )
      ..registerLazySingleton<SettingsRepository>(() => SettingsRepositoryImpl(sl()));
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
    ..registerLazySingleton(() => LoadConnection(sl()))
    ..registerLazySingleton(() => SaveConnection(sl(), sl()))
    ..registerLazySingleton(() => ThemeSettings(sl()))
    // View models
    ..registerFactory(() => HubCubit(watchHub: sl(), decideApproval: sl(), retry: sl()))
    ..registerFactory(() => SettingsCubit(load: sl(), save: sl(), theme: sl()))
    ..registerFactoryParam<SessionBloc, String, void>(
      (sessionId, _) =>
          SessionBloc(
        sessionId: sessionId,
        watchHub: sl(),
        watchTimeline: sl(),
        sendMessage: sl(),
        interrupt: sl(),
        endSession: sl(),
      ),
    )
    ..registerFactoryParam<NewSessionCubit, HubSnapshot, String?>(
      (hub, preferredNode) => NewSessionCubit(hub: hub, createSession: sl(), preferredNode: preferredNode),
    );
}
