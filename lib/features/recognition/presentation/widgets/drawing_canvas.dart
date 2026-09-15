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
  });

  final DrawingCanvasController controller;
  final double strokeWidth;
  final ValueChanged<bool> onTouchChanged;

  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  final List<Stroke> _strokes = [];

  bool get isEmpty => _strokes.isEmpty;

  void clear() => setState(_strokes.clear);

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _strokes.add(
        Stroke(points: [d.localPosition], strokeWidth: widget.strokeWidth),
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.points.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails _) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.points.add(null));
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
