// SPDX-FileCopyrightText: Copyright 2025 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import 'package:aurora_platform/aurora_platform.dart';
import 'package:aurora_window_manager/aurora_window_manager.dart';
import 'package:flutter/material.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'aurora_window_manager_impl.dart';

abstract class AuroraWindowManagerPlatform extends PlatformInterface {
  AuroraWindowManagerPlatform() : super(token: _token);

  static final Object _token = Object();

  static AuroraWindowManagerPlatform _instance = kIsAurora ? AuroraWindowManagerImpl() : StubAuroraWindowManagerImpl();

  /// The default instance of [ServicesAuroraPlatform] to use.
  static AuroraWindowManagerPlatform get instance => _instance;

  static set instance(AuroraWindowManagerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> fullscreen();
  Future<void> maximizeWindow();
  Future<void> minimizeWindow();
  Future<void> setBackgroundVisibility(bool value);
  Future<bool> getBackgroundVisibility();
  void addWindowModeListener(VoidCallback listener);
  void removeWindowModeListener(VoidCallback listener);
  WindowMode getWindowMode();
  Future<WindowType> getWindowType();
  void addThemeListener(VoidCallback listener);
  void removeThemeListener(VoidCallback listener);
  WindowTheme getCurrentTheme();
  Future<Map<String, Object>> createWindow({required String entryPoint, String entryPointLibrary = '', Map<String, Object>? params});
  Future<Map<String, Object>> getWindowPayload();
  Future<void> closeWindow(Map<String, Object> value);
}
