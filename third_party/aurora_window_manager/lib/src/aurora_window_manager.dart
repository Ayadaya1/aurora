// SPDX-FileCopyrightText: Copyright 2025 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause
import 'dart:async';

import 'package:flutter/material.dart';

import '../aurora_window_manager.dart';
import 'aurora_window_manager_platform.dart';

enum WindowMode { foreground, cover }
enum WindowType { main, popup, cover }

class AuroraWindowManager {
  /// Deploy the application.
  static Future<void> fullscreen() => AuroraWindowManagerPlatform.instance.fullscreen();

  /// Minimize the application.
  static Future<void> minimizeWindow() => AuroraWindowManagerPlatform.instance.minimizeWindow();

  /// Deploy the application.
  static Future<void> maximizeWindow() => AuroraWindowManagerPlatform.instance.maximizeWindow();

  /// Update background visibility property. true enables native background.
  static Future<void> setBackgroundVisibility(bool value) =>
      AuroraWindowManagerPlatform.instance.setBackgroundVisibility(value);

  /// Current state of background visibility property.
  static Future<bool> getBackgroundVisibility() => AuroraWindowManagerPlatform.instance.getBackgroundVisibility();

  /// Add listener to be notified when WindowMode changed
  static void addWindowModeListener(VoidCallback listener) =>
      AuroraWindowManagerPlatform.instance.addWindowModeListener(listener);

  /// Remove WindowMode listener
  static void removeWindowModeListener(VoidCallback listener) =>
      AuroraWindowManagerPlatform.instance.removeWindowModeListener(listener);

  /// Current WindowMode
  static WindowMode getWindowMode() => AuroraWindowManagerPlatform.instance.getWindowMode();

  /// Current WindowType
  static Future<WindowType> getWindowType() => AuroraWindowManagerPlatform.instance.getWindowType();

  /// Add listener to be notified when WindowMode changed
  static void addThemeListener(VoidCallback listener) =>
      AuroraWindowManagerPlatform.instance.addThemeListener(listener);

  /// Remove WindowMode listener
  static void removeThemeListener(VoidCallback listener) =>
      AuroraWindowManagerPlatform.instance.removeThemeListener(listener);

  /// Current window theme
  static WindowTheme getCurrentTheme() => AuroraWindowManagerPlatform.instance.getCurrentTheme();

  /// Create new window
  static Future<Map<String, Object>> createWindow({required String entryPoint, String entryPointLibrary = '', Map<String, Object>? params}) =>
      AuroraWindowManagerPlatform.instance.createWindow(
        entryPoint: entryPoint,
        entryPointLibrary: entryPointLibrary,
        params: params,
      );

  static Future<Map<String, Object>> getWindowPayload() => AuroraWindowManagerPlatform.instance.getWindowPayload();

  /// Close current window
  static Future<void> closeWindow(Map<String, Object> value) => AuroraWindowManagerPlatform.instance.closeWindow(value);
}
