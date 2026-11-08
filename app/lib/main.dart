import 'package:flutter/material.dart';

import 'data/datasources/local_agent.dart';
import 'injection.dart';
import 'presentation/app.dart';
import 'startup_marker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  startLocalAgent();
  configureDependencies();
  runApp(const TetherApp());
  reportUpdateOk();
}
