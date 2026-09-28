import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:aurora/core/theme/app_colors.dart';
import 'package:aurora/features/recognition/presentation/widgets/drawing_painter.dart';

class DrawingCanvasController {
  final GlobalKey boundaryKey = GlobalKey();

  Future<Uint8List> capture() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    final image = await boundary.toImage(pixelRatio: 2.0);

    const crop = 12.0;
    const padding = 20.0;

    final width = image.width - (crop * 2 * 2).round().toDouble();
    final height = image.height - (crop * 2 * 2).round().toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint();

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width + padding * 2, height + padding * 2),
      Paint()..color = Colors.white,
    );

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(crop * 2, crop * 2, width, height),
      Rect.fromLTWH(padding, padding, width, height),
      paint,
    );

    final result = await recorder.endRecording().toImage(
      (width + padding * 2).round(),
      (height + padding * 2).round(),
    );

    final bytes = await result.toByteData(format: ui.ImageByteFormat.png);

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
  int? _activePointer;

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

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    widget.onTouchChanged(true);
    setState(() {
      _strokes.add(
        Stroke(points: [event.localPosition], strokeWidth: widget.strokeWidth),
      );
    });

    _notifyStrokesChanged();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer || _strokes.isEmpty) return;

    setState(() {
      _strokes.last.points.add(event.localPosition);
    });

    _notifyStrokesChanged();
  }

  void _onPointerEnd(PointerEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    widget.onTouchChanged(false);
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
        // Track the pointer directly: changing the parent's scroll physics on
        // pointer-down can cancel a GestureDetector's pending pan recognition.
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: CustomPaint(
            size: Size.infinite,
            painter: DrawingPainter(strokes: _strokes),
          ),
        ),
      ),
    );
  }
}
