import 'package:flutter/material.dart';

import 'injection.dart';
import 'presentation/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(const TetherApp());
}
