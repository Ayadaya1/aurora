// SPDX-FileCopyrightText: Copyright 2025 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'aurora_window_manager.dart' show WindowMode, WindowType;
import 'aurora_window_manager_platform.dart';
import 'window_theme.dart';

// Platform plugin keys channels
const channelMethods = "flutter/aurora-window-manager";

// Platform channel plugin methods
enum Methods {
  fullscreen,
  maximizeWindow,
  minimizeWindow,
  activate,
  setBackgroundVisibility,
  getBackgroundVisibility,
  getCurrentTheme,
  getWindowMode,
  getWindowType,
  createWindow,
  getWindowPayload,
  closeWindow,
}

enum Handlers { onWindowModeChanged, onThemeChanged }

/// An implementation of [AuroraWindowManagerPlatform] that uses method channels.
class AuroraWindowManagerImpl extends AuroraWindowManagerPlatform {
  /// The methods channel used to interact with the native platform.
  final _methodsChannel = const MethodChannel(channelMethods);

  final ValueNotifier<WindowMode> _windowMode = ValueNotifier<WindowMode>(
    WindowMode.foreground,
  );

  final ValueNotifier<WindowTheme> _theme = ValueNotifier<WindowTheme>(
    WindowTheme.empty(),
  );

  AuroraWindowManagerImpl() {
    _methodsChannel.setMethodCallHandler(_onMethodCall);
    _updateWindowMode();
    _updateTheme();
  }

  @override
  Future<void> fullscreen() {
    return _methodsChannel
        .invokeMethod<void>(Methods.fullscreen.name)
        .then<void>((_) => activate());
  }

  @override
  Future<void> maximizeWindow() {
    return _methodsChannel
        .invokeMethod<void>(Methods.maximizeWindow.name)
        .then<void>((_) => activate());
  }

  @override
  Future<void> minimizeWindow() {
    return _methodsChannel.invokeMethod<void>(Methods.minimizeWindow.name);
  }

  Future<void> activate() {
    return _methodsChannel.invokeMethod<void>(Methods.activate.name);
  }

  @override
  Future<void> setBackgroundVisibility(bool value) {
    return _methodsChannel.invokeMethod<void>(
      Methods.setBackgroundVisibility.name,
      value,
    );
  }

  @override
  Future<bool> getBackgroundVisibility() => _methodsChannel
      .invokeMethod<bool>(Methods.getBackgroundVisibility.name)
      .then((bool? value) {
        if (value is! bool) {
          throw Exception(
            'Expected value of type bool, got ${value.runtimeType} instead.',
          );
        }
        return value;
      });

  @override
  void addWindowModeListener(VoidCallback listener) {
    _windowMode.addListener(listener);
  }

  @override
  void removeWindowModeListener(VoidCallback listener) {
    _windowMode.removeListener(listener);
  }

  @override
  WindowMode getWindowMode() => _windowMode.value;

  @override
  Future<WindowType> getWindowType() => _methodsChannel
      .invokeMethod<String>(Methods.getWindowType.name)
      .then((String? value) {
        if (value is! String) {
          throw Exception(
            'Expected value of type String, got ${value.runtimeType} instead.',
          );
        }
        return WindowType.values.byName(value);
      });

  Future<bool?> _onMethodCall(MethodCall call) async {
    if (call.method == Handlers.onWindowModeChanged.name) {
      _updateWindowMode();
      return true;
    }
    if (call.method == Handlers.onThemeChanged.name) {
      _updateTheme();
      return true;
    }
    return false;
  }

  void _updateWindowMode() => _methodsChannel
      .invokeMethod<String>(Methods.getWindowMode.name)
      .then((String? value) {
        if (value is! String) {
          throw Exception(
            'Expected value of type String, got ${value.runtimeType} instead.',
          );
        }
        _windowMode.value = value == 'foreground'
            ? WindowMode.foreground
            : WindowMode.cover;
      });

  @override
  void addThemeListener(VoidCallback listener) {
    _theme.addListener(listener);
  }

  @override
  void removeThemeListener(VoidCallback listener) {
    _theme.removeListener(listener);
  }

  @override
  WindowTheme getCurrentTheme() => _theme.value;

  @override
  Future<Map<String, Object>> createWindow({
    required String entryPoint,
    String entryPointLibrary = '',
    Map<String, Object>? params,
  }) {
    return _methodsChannel
        .invokeMethod<Map<Object?, Object?>>(
          Methods.createWindow.name,
          <String, Object>{
            'entryPoint': entryPoint,
            'entryPointLibrary': entryPointLibrary,
            if (params != null) 'params': params,
          },
        )
        .then((Map<Object?, Object?>? value) {
          if (value is! Map<Object?, Object?>) {
            throw Exception(
              'Expected value of type Map<Object?, Object?>, got ${value.runtimeType} instead.',
            );
          }
          return {
            for (final it in value.entries)
              if (it.key is String && it.value != null)
                it.key as String: it.value!,
          };
        });
  }

  @override
  Future<Map<String, Object>> getWindowPayload() {
    return _methodsChannel
        .invokeMethod<Map<Object?, Object?>>(Methods.getWindowPayload.name)
        .then((Map<Object?, Object?>? value) {
          if (value is! Map<Object?, Object?>) {
            throw Exception(
              'Expected value of type Map<Object?, Object?>, got ${value.runtimeType} instead.',
            );
          }
          return {
            for (final it in value.entries)
              if (it.key is String && it.value != null)
                it.key as String: it.value!,
          };
        });
  }

  @override
  Future<void> closeWindow(Map<String, Object> value) {
    return _methodsChannel.invokeMethod<void>(Methods.closeWindow.name, value);
  }

  void _updateTheme() => _methodsChannel
      .invokeMethod<Map>(Methods.getCurrentTheme.name)
      .then((value) {
        _theme.value = _parseWindowTheme(value);
      });

  static WindowTheme _parseWindowTheme(dynamic data) {
    if (data is! Map<Object?, Object?>) {
      throw Exception(
        'Expected data to be of type Map<String, dynamic>, got ${data.runtimeType} instead',
      );
    }

    final isDark = (data['isDark'] as int) == 0;
    return WindowTheme(
      isDark: isDark,
      statusbarHeight: data['statusbarHeight'] as double,
      statusbarBaseline: data['statusbarBaseline'] as double,
      highlightColor: _decodeARGB(
        data['highlightColor'] as String,
        const Color(0xFF14ACC5),
      ),
      primaryColor: _decodeARGB(
        data['primaryColor'] as String,
        isDark ? Colors.white : Colors.black,
      ),
      secondaryColor: _decodeARGB(
        data['secondaryColor'] as String,
        isDark ? Colors.white70 : Colors.black54,
      ),
      secondaryHighlightColor: _decodeARGB(
        data['secondaryHighlightColor'] as String,
        const Color(0xFF86D6E2),
      ),
    );
  }

  static Color _decodeARGB(String argbString, Color fallback) {
    // Some Aurora themes expose empty color fields.
    if (argbString.trim().isEmpty) return fallback;
    vm.Vector4 colorVector = vm.Vector4.zero();
    try {
      vm.Colors.fromHexString(argbString, colorVector);
    } on FormatException {
      return fallback;
    }

    return Color.fromARGB(
      (255 * colorVector.a).round(),
      (255 * colorVector.r).round(),
      (255 * colorVector.g).round(),
      (255 * colorVector.b).round(),
    );
  }
}

/// An stub implementation of [AuroraWindowManagerPlatform] for using in upstream flutter.
class StubAuroraWindowManagerImpl extends AuroraWindowManagerPlatform {
  @override
  Future<void> fullscreen() {
    log('Method fullscreen is not implemented for this platform.');
    return Future.value(null);
  }

  @override
  Future<void> maximizeWindow() {
    log('Method maximizeWindow is not implemented for this platform.');
    return Future.value(null);
  }

  @override
  Future<void> minimizeWindow() {
    log('Method minimizeWindow is not implemented for this platform.');
    return Future.value(null);
  }

  @override
  Future<void> setBackgroundVisibility(bool value) {
    log('Method setBackgroundVisibility is not implemented for this platform.');
    return Future.value(null);
  }

  @override
  Future<bool> getBackgroundVisibility() {
    log('Method getBackgroundVisibility is not implemented for this platform.');
    return Future.value(false);
  }

  @override
  WindowTheme getCurrentTheme() {
    log('Method getCurrentTheme is not implemented for this platform.');
    return WindowTheme.empty();
  }

  @override
  void addWindowModeListener(VoidCallback listener) {
    log('Method addWindowModeListener is not implemented for this platform.');
  }

  @override
  void removeWindowModeListener(VoidCallback listener) {
    log(
      'Method removeWindowModeListener is not implemented for this platform.',
    );
  }

  @override
  WindowMode getWindowMode() {
    log('Method getWindowMode is not implemented for this platform.');
    return WindowMode.foreground;
  }

  @override
  Future<WindowType> getWindowType() {
    log('Method getWindowType is not implemented for this platform.');
    return Future.value(WindowType.main);
  }

  @override
  void addThemeListener(VoidCallback listener) {
    log('Method addThemeListener is not implemented for this platform.');
  }

  @override
  void removeThemeListener(VoidCallback listener) {
    log('Method removeThemeListener is not implemented for this platform.');
  }

  @override
  Future<Map<String, Object>> createWindow({
    required String entryPoint,
    String entryPointLibrary = '',
    Map<String, Object>? params,
  }) {
    log('Method createWindow is not implemented for this platform.');
    return Future.value({});
  }

  @override
  Future<Map<String, Object>> getWindowPayload() {
    log('Method getWindowPayload is not implemented for this platform.');
    return Future.value({});
  }

  @override
  Future<void> closeWindow(Map<String, Object> value) {
    log('Method closeWindow is not implemented for this platform.');
    return Future.value(null);
  }
}
