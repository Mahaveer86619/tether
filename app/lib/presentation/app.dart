import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../injection.dart';
import 'home/shell.dart';
import 'artifacts/artifacts_cubit.dart';
import 'hub/hub_cubit.dart';
import 'settings/settings_cubit.dart';
import 'theme/palettes.dart';
import 'theme/theme.dart';

class TetherApp extends StatelessWidget {
  const TetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<HubCubit>()),
        BlocProvider(create: (_) => sl<ArtifactsCubit>()),
        BlocProvider(create: (_) => sl<SettingsCubit>()..start()),
      ],
      // Settings are shared through the hub: take what another device saved,
      // or offer ours when the hub has none yet.
      child: BlocListener<HubCubit, HubState>(
        listenWhen: (a, b) => a.hub.preferences != b.hub.preferences || a.hub.connected != b.hub.connected,
        listener: (context, s) {
          final settings = context.read<SettingsCubit>();
          if (s.hub.preferences case final shared?) {
            settings.applyShared(shared);
          } else if (s.hub.connected) {
            settings.share();
          }
        },
        child: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (a, b) => a.appearance != b.appearance || a.loaded != b.loaded,
        builder: (context, settings) {
          final look = settings.appearance;
          final palette = paletteById(look.palette);
          final accent = look.accent == null ? null : Color(look.accent!);
          return MaterialApp(
          title: 'Tether',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light, palette: palette, accent: accent),
          darkTheme: buildTheme(Brightness.dark, palette: palette, accent: accent),
          themeMode: look.mode,
          home: settings.loaded ? const Shell() : const Scaffold(body: SizedBox.shrink()),
          );
        },
        ),
      ),
    );
  }
}
