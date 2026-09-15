import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:aurora/core/di/dependencies.dart';
import 'package:aurora/core/theme/app_colors.dart';
import 'package:aurora/features/onboarding/presentation/onboarding_screen.dart';
import 'package:aurora/features/recognition/presentation/controllers/recognition_controller.dart';

import 'features/recognition/presentation/screens/recognition_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final RecognitionController _recognitionController = RecognitionController(
    recognizeFormula: Dependencies.recognizeFormula,
  );

  late final _router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/recognize',
        builder: (_, _) => RecognitionScreen(controller: _recognitionController),
      ),
    ],
  );

  @override
  void dispose() {
    _recognitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Formula OCR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.teal),
      ),
      routerConfig: _router,
    );
  }
}