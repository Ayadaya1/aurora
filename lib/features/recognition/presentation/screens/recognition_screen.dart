import 'package:aurora/core/theme/app_colors.dart';
import 'package:aurora/features/recognition/domain/recognition_source.dart';
import 'package:aurora/features/recognition/presentation/controllers/recognition_controller.dart' hide DrawingCanvas, DrawingCanvasController, DrawingCanvasState;
import 'package:aurora/features/recognition/presentation/widgets/drawing_canvas.dart';
import 'package:aurora/features/recognition/presentation/widgets/latex_html_builder.dart';
import 'package:aurora/features/recognition/presentation/widgets/latex_result_view.dart';
import 'package:aurora/features/recognition/presentation/widgets/mode_switcher.dart';
import 'package:aurora/features/recognition/presentation/widgets/photo_input_view.dart';
import 'package:aurora/features/recognition/presentation/widgets/recognize_button.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RecognitionScreen extends StatefulWidget {
  const RecognitionScreen({super.key, required this.controller});

  final RecognitionController controller;

  @override
  State<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen> {
  final _picker = ImagePicker();
  final _drawingController = DrawingCanvasController();
  final _canvasKey = GlobalKey<DrawingCanvasState>();

  late final WebViewController _webView;
  double _strokeWidth = 4.0;
  bool _touchingCanvas = false;

  RecognitionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..loadHtmlString(LatexHtmlBuilder.build(null));

    _c.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
    if (_c.latex != null) {
      _webView.loadHtmlString(LatexHtmlBuilder.build(_c.latex));
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 95);
    if (file == null) return;
    _c.setPhoto(file.path);
  }

  Future<void> _recognize() async {
    final mode = _c.mode;

    if (mode == RecognitionMode.photo && _c.photoPath == null) {
      _snack('Выберите изображение или сделайте фото');
      return;
    }

    final canvasState = _canvasKey.currentState;
    if (mode == RecognitionMode.drawing && (canvasState == null || canvasState.isEmpty)) {
      _snack('Нарисуйте формулу на холсте');
      return;
    }

    final RecognitionSource source = switch (mode) {
      RecognitionMode.photo => PhotoSource(_c.photoPath!),
      RecognitionMode.drawing => DrawingSource(await _drawingController.capture()),
    };

    try {
      await _c.recognize(source);
    } catch (e) {
      if (mounted) _snack(e.toString());
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: _touchingCanvas
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModeSwitcher(
                mode: _c.mode,
                onChanged: (m) {
                  _c.setMode(m);
                  //_canvasKey.currentState?.clear();
                  //_webView.loadHtmlString(LatexHtmlBuilder.build(null));
                },
              ),
              const SizedBox(height: 12),
              if (_c.mode == RecognitionMode.photo)
                PhotoInputView(
                  imagePath: _c.photoPath,
                  onPickGallery: () => _pickPhoto(ImageSource.gallery),
                  onTakePhoto: () => _pickPhoto(ImageSource.camera),
                  onRemove: () => _c.setPhoto(null),
                )
              else
                _buildDrawingSection(),
              const SizedBox(height: 16),
              RecognizeButton(
                isLoading: _c.isRecognizing,
                onPressed: _recognize,
              ),
              const SizedBox(height: 16),
              _sectionLabel(Icons.functions, 'Результат'),
              const SizedBox(height: 8),
              LatexResultView(controller: _webView, latex: _c.latex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawingSection() {
    return Column(
      children: [
        DrawingCanvas(
          key: _canvasKey,
          controller: _drawingController,
          strokeWidth: _strokeWidth,
          onTouchChanged: (v) => setState(() => _touchingCanvas = v),
          strokes: _c.drawingStrokes,
          onStrokesChanged: _c.setDrawingStrokes,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _canvasKey.currentState?.clear(),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Очистить'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ink.withOpacity(0.65),
              ),
            ),
            const Spacer(),
            Icon(Icons.line_weight, size: 18, color: Colors.grey.shade500),
            SizedBox(
              width: 130,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.teal,
                  inactiveTrackColor: AppColors.teal.withOpacity(0.15),
                  thumbColor: AppColors.teal,
                  overlayColor: AppColors.teal.withOpacity(0.15),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: _strokeWidth,
                  min: 1,
                  max: 14,
                  onChanged: (v) => setState(() => _strokeWidth = v),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionLabel(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.teal),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          letterSpacing: 0.3,
        ),
      ),
    ],
  );
}