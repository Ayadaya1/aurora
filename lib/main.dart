import 'package:aurora/app.dart';
import 'package:flutter/material.dart';

import 'core/di/dependencies.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Dependencies.init();
  runApp(const App());
}
