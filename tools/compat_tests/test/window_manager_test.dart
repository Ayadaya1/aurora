import 'package:aurora_window_manager/src/aurora_window_manager_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter/aurora-window-manager');

  for (final color in ['', 'invalid', '#00ff00']) {
    test('opens a dialog with theme color "$color" on the 3.41 channel', () async {
      MethodCall? createCall;
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getWindowMode': return 'foreground';
          case 'getCurrentTheme': return {
            'isDark': 0,
            'statusbarHeight': 0.0,
            'statusbarBaseline': 0.0,
            'highlightColor': color,
            'primaryColor': color,
            'secondaryColor': color,
            'secondaryHighlightColor': color,
          };
          case 'createWindow':
            createCall = call;
            return {'path': '/home/defaultuser/Pictures/formula.png'};
          default: throw StateError('Unexpected method: ${call.method}');
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final manager = AuroraWindowManagerImpl();
      final result = await manager.createWindow(
        entryPoint: 'selectImage', entryPointLibrary: 'package:picker/picker.dart',
        params: {'kind': 'image'},
      );
      expect(result['path'], endsWith('formula.png'));
      expect(createCall?.arguments['entryPoint'], 'selectImage');
      expect(createCall?.arguments['params'], {'kind': 'image'});
      expect(manager.getCurrentTheme().primaryColor,
          color == '#00ff00' ? const Color(0xff00ff00) : Colors.white);
    });
  }
}
