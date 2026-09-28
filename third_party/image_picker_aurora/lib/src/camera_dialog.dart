// SPDX-FileCopyrightText: Copyright 2013 The Flutter Authors. All rights reserved.
// SPDX-FileCopyrightText: Copyright 2023 Alexander Syrykh
// SPDX-FileCopyrightText: Copyright 2024-2025 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import 'package:aurora_controls/aurora_controls.dart';
import 'package:aurora_window_manager/aurora_window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker_aurora/src/take_photo_page.dart';

enum CameraDialogRoutes {
  camera,
}

extension Routes on CameraDialogRoutes {
  static Map<CameraDialogRoutes, String> routesMap = {
    CameraDialogRoutes.camera: '/camera',
  };

  String get path {
    return routesMap[this]!;
  }
}

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> cameraDialogMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final params = await AuroraWindowManager.getWindowPayload();
  runApp(MyApp(params: params));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.params});

  final Map<String, Object> params;

  @override
  Widget build(BuildContext context) {
    return AuroraApp(
      navigatorKey: navigatorKey,
      title: 'Aurora Camera Dialog',
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: params['initialRoute'] as String,
      routes: <String, WidgetBuilder>{
        CameraDialogRoutes.camera.path: (BuildContext context) =>
            TakePhotoPage(data: TakePhotoPageData.fromMap(params)),
      },
    );
  }
}
