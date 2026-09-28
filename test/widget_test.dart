import 'package:aurora/features/recognition/presentation/widgets/latex_result_view.dart';
import 'package:aurora/app.dart';
import 'package:aurora/core/di/dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:aurora/features/recognition/presentation/widgets/drawing_canvas.dart';

class FailingImagePicker extends ImagePickerPlatform {
  int calls = 0;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    calls++;
    throw StateError('Picker unavailable');
  }
}

void main() {
  setUpAll(Dependencies.init);
  testWidgets('picker failure is visible and the user can retry', (
    tester,
  ) async {
    final original = ImagePickerPlatform.instance;
    final failing = FailingImagePicker();
    ImagePickerPlatform.instance = failing;
    addTearDown(() => ImagePickerPlatform.instance = original);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const App(onboardingCompleted: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось открыть галерею'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();
    expect(failing.calls, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('drawing accepts strokes and can be cleared', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const App(onboardingCompleted: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Рисование'));
    await tester.pumpAndSettle();
    final canvas = find.byType(DrawingCanvas);
    await tester.dragFrom(
      tester.getTopLeft(canvas) + const Offset(40, 40),
      const Offset(80, 60),
    );
    await tester.pumpAndSettle();
    expect(tester.state<DrawingCanvasState>(canvas).isEmpty, false);
    await tester.ensureVisible(find.text('Очистить'));
    await tester.tap(find.text('Очистить'));
    await tester.pumpAndSettle();
    expect(tester.state<DrawingCanvasState>(canvas).isEmpty, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'finishing onboarding opens recognition and persists completion',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Пропустить'));
      await tester.pumpAndSettle();
      expect(find.byType(LatexResultView), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool('onboarding_completed'),
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const App(onboardingCompleted: true));
      await tester.pumpAndSettle();
      expect(find.text('Пропустить'), findsNothing);
      expect(find.byType(LatexResultView), findsOneWidget);
    },
  );
  Widget result(String? latex) => MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 320, child: LatexResultView(latex: latex)),
    ),
  );

  testWidgets('renders common formulas without platform views', (tester) async {
    for (final latex in [
      r'x+1=2',
      r'\frac{x+1}{x-1}',
      r'\int_0^1 x^2\,dx=\frac{1}{3}',
      r'\sum_{n=1}^{\infty}\frac{1}{n^2}',
      r'\begin{pmatrix}a&b\\c&d\end{pmatrix}',
    ]) {
      await tester.pumpWidget(result(latex));
      await tester.pumpAndSettle();
      expect(find.byType(Math), findsOneWidget);
      expect(
        find.text(latex),
        findsNothing,
        reason: 'Should render, not fall back: $latex',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('invalid LaTeX remains visible and copyable', (tester) async {
    const latex = r'\unknowncommand{x}';
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData')
          copied = call.arguments['text'] as String;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(result(latex));
    expect(find.text(latex), findsOneWidget);
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pump();
    expect(copied, latex);
    expect(find.text('LaTeX скопирован'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long formula scrolls without overflowing', (tester) async {
    await tester.pumpWidget(result(List.filled(30, 'x^2').join('+')));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(200, 110), const Offset(-180, 0));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).last);
    expect(scroll.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
