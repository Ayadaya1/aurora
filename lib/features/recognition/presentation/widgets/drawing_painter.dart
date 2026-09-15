import 'package:flutter/material.dart';

import 'package:aurora/core/theme/app_colors.dart';

class Stroke {
  Stroke({required this.points, required this.strokeWidth});
  final List<Offset?> points;
  final double strokeWidth;
}

class DrawingPainter extends CustomPainter {
  const DrawingPainter({required this.strokes});

  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final dotPaint = Paint()..color = AppColors.ink.withOpacity(0.06);
    const spacing = 22.0;
    for (double y = spacing; y < size.height; y += spacing) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    for (final stroke in strokes) {
      final paint = Paint()
        ..color = AppColors.ink
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (var i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        if (p1 != null && p2 != null) {
          canvas.drawLine(p1, p2, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}