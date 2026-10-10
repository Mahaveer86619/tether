import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../injection.dart';
import 'home/shell.dart';
import 'hub/hub_cubit.dart';
import 'settings/settings_cubit.dart';
import 'theme/theme.dart';

class TetherApp extends StatelessWidget {
  const TetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<HubCubit>()),
        BlocProvider(create: (_) => sl<SettingsCubit>()..start()),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (a, b) => a.themeMode != b.themeMode || a.loaded != b.loaded,
        builder: (context, settings) => MaterialApp(
          title: 'Tether',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          home: settings.loaded ? const Shell() : const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
  }
}
