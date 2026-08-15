import 'package:flutter/material.dart';

/// Paints a dashed rounded-rectangle border, e.g. for "add" placeholder tiles.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  const DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final sw = strokeWidth;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sw / 2, sw / 2, size.width - sw, size.height - sw),
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final segmentEnd = (distance + (draw ? 8.0 : 5.0)).clamp(
          0.0,
          metric.length,
        );
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, segmentEnd), paint);
        }
        distance = segmentEnd;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}
