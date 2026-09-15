import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aurora/features/recognition/domain/recognition_source.dart';
import 'package:aurora/features/recognition/domain/use_cases/recognize_formula.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:aurora/core/theme/app_colors.dart';
import 'package:aurora/features/recognition/presentation/widgets/drawing_painter.dart';

enum RecognitionMode { photo, drawing }

class DrawingCanvasController {
  final GlobalKey boundaryKey = GlobalKey();

  Future<Uint8List> capture() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    if (bytes == null) {
      throw StateError('Не удалось создать PNG');
    }

    return bytes.buffer.asUint8List();
  }
}

class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({
    super.key,
    required this.controller,
    required this.strokeWidth,
    required this.onTouchChanged,
    required this.strokes,
    required this.onStrokesChanged,
  });

  final DrawingCanvasController controller;
  final double strokeWidth;
  final ValueChanged<bool> onTouchChanged;
  final List<Stroke> strokes;
  final ValueChanged<List<Stroke>> onStrokesChanged;

  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  late List<Stroke> _strokes;

  bool get isEmpty => _strokes.isEmpty;

  @override
  void initState() {
    super.initState();
    _strokes = List.from(widget.strokes);
  }

  @override
  void didUpdateWidget(covariant DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.strokes != widget.strokes) {
      _strokes = List.from(widget.strokes);
    }
  }

  void _notifyStrokesChanged() {
    widget.onStrokesChanged(List.from(_strokes));
  }

  void clear() {
    setState(_strokes.clear);
    _notifyStrokesChanged();
  }

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _strokes.add(
        Stroke(points: [d.localPosition], strokeWidth: widget.strokeWidth),
      );
    });

    _notifyStrokesChanged();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_strokes.isEmpty) return;

    setState(() {
      _strokes.last.points.add(d.localPosition);
    });

    _notifyStrokesChanged();
  }

  void _onPanEnd(DragEndDetails _) {
    if (_strokes.isEmpty) return;

    setState(() {
      _strokes.last.points.add(null);
    });

    _notifyStrokesChanged();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: widget.controller.boundaryKey,
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Listener(
          onPointerDown: (_) => widget.onTouchChanged(true),
          onPointerUp: (_) => widget.onTouchChanged(false),
          onPointerCancel: (_) => widget.onTouchChanged(false),
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              size: Size.infinite,
              painter: DrawingPainter(strokes: _strokes),
            ),
          ),
        ),
      ),
    );
  }
}

class RecognitionController extends ChangeNotifier {
  RecognitionController({required RecognizeFormula recognizeFormula})
    : _recognizeFormula = recognizeFormula;

  final RecognizeFormula _recognizeFormula;

  RecognitionMode _mode = RecognitionMode.photo;

  String? _photoPath;
  String? _photoLatex;

  List<Stroke> _drawingStrokes = [];
  String? _drawingLatex;

  bool _isRecognizing = false;

  RecognitionMode get mode => _mode;

  String? get photoPath => _photoPath;

  String? get photoLatex => _photoLatex;

  List<Stroke> get drawingStrokes => List.unmodifiable(_drawingStrokes);

  String? get drawingLatex => _drawingLatex;

  bool get isRecognizing => _isRecognizing;

  String? get latex {
    return switch (_mode) {
      RecognitionMode.photo => _photoLatex,
      RecognitionMode.drawing => _drawingLatex,
    };
  }

  void setMode(RecognitionMode mode) {
    if (_mode == mode) return;

    _mode = mode;
    notifyListeners();
  }

  void setPhoto(String? path) {
    _photoPath = path;
    _photoLatex = null;
    notifyListeners();
  }

  void setDrawingStrokes(List<Stroke> strokes) {
    _drawingStrokes = strokes
        .map(
          (stroke) => Stroke(
            points: List<Offset?>.from(stroke.points),
            strokeWidth: stroke.strokeWidth,
          ),
        )
        .toList();

    _drawingLatex = null;
    notifyListeners();
  }

  void clearDrawing() {
    _drawingStrokes = [];
    _drawingLatex = null;
    notifyListeners();
  }

  Future<void> recognize(RecognitionSource source) async {
    final recognitionMode = _mode;

    _isRecognizing = true;
    notifyListeners();

    try {
      final result = await _recognizeFormula(source);

      if (recognitionMode == RecognitionMode.photo) {
        _photoLatex = result;
      } else {
        _drawingLatex = result;
      }
    } finally {
      _isRecognizing = false;
      notifyListeners();
    }
  }
}
