import 'package:aurora/app.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Dependencies.init();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    App(
      onboardingCompleted: preferences.getBool('onboarding_completed') ?? false,
    ),
  );
}
