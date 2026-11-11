import 'dart:async';

import 'package:flutter/material.dart';

import 'data/datasources/local_agent.dart';
import 'injection.dart';
import 'presentation/app.dart';
import 'domain/repositories/repositories.dart' show DesktopUpdater;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  startLocalAgent();
  configureDependencies();
  runApp(const TetherApp());
  // Windows: the updater that checks the signed feed on GitHub.
  unawaited(sl<DesktopUpdater>().start());
}
