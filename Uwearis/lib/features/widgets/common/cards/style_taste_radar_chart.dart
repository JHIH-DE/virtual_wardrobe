import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// One axis of a [StyleTasteRadarChart] — an icon, the dimension's title,
/// the label for whichever pole [score] currently leans toward, and the
/// score itself (0.0-1.0).
class StyleTasteRadarAxis {
  final IconData icon;
  final String title;
  final String valueLabel;
  final double score;

  const StyleTasteRadarAxis({
    required this.icon,
    required this.title,
    required this.valueLabel,
    required this.score,
  });
}

/// Read-only radar/spider chart plotting every learned preference dimension
/// at once (rather than five disconnected bars), so the shape itself reads
/// as "this is your style taste" at a glance. Each axis gets an icon,
/// title, and current-pole label positioned just outside its vertex.
class StyleTasteRadarChart extends StatelessWidget {
  final List<StyleTasteRadarAxis> axes;
  final double size;

  /// Chart radius as a fraction of [size] — deliberately sized so the plot
  /// itself reads as the focal point, with just enough margin left over for
  /// the axis labels to sit outside it without crowding.
  static const double _radiusFraction = 0.30;
  static const double _labelBlockWidth = 78;
  static const double _labelBlockHeight = 56;
  static const double _labelGap = 10;

  const StyleTasteRadarChart({
    super.key,
    required this.axes,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final axisCount = axes.length;
    final chartRadius = size * _radiusFraction;
    final chartDiameter = chartRadius * 2;
    final center = Offset(size / 2, size / 2);

    Offset vertexAt(int index) {
      final angle = -math.pi / 2 + index * (2 * math.pi / axisCount);
      return center + Offset(math.cos(angle), math.sin(angle)) * chartRadius;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: center.dx - chartRadius,
            top: center.dy - chartRadius,
            width: chartDiameter,
            height: chartDiameter,
            child: CustomPaint(
              painter: _RadarGridPainter([for (final axis in axes) axis.score]),
            ),
          ),
          for (var i = 0; i < axisCount; i++)
            _buildAxisLabel(i, axisCount, vertexAt(i)),
        ],
      ),
    );
  }

  /// Anchors the label so it grows *away* from the vertex instead of being
  /// centered on it — a block centered on a mostly-horizontal vertex would
  /// otherwise hang half over the chart itself (the bug this fixes).
  /// [align] is the axis direction's component (-1..1) for one dimension;
  /// at +1 the block starts exactly at the anchor and grows outward, at -1
  /// it ends there and grows the other way, at 0 it's centered on it.
  double _outwardOffset(double anchor, double align, double blockExtent) {
    return anchor - (blockExtent / 2) * (1 - align);
  }

  Widget _buildAxisLabel(int index, int axisCount, Offset vertex) {
    final angle = -math.pi / 2 + index * (2 * math.pi / axisCount);
    final direction = Offset(math.cos(angle), math.sin(angle));
    final axis = axes[index];
    final anchor = vertex + direction * _labelGap;

    final left = _outwardOffset(
      anchor.dx,
      direction.dx,
      _labelBlockWidth,
    ).clamp(0.0, size - _labelBlockWidth);
    final top = _outwardOffset(
      anchor.dy,
      direction.dy,
      _labelBlockHeight,
    ).clamp(0.0, size - _labelBlockHeight);

    return Positioned(
      left: left,
      top: top,
      width: _labelBlockWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(axis.icon, size: 18, color: AppColors.textPrimary),
          const SizedBox(height: 3),
          Text(
            axis.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.bold12,
          ),
          Text(
            axis.valueLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.bold12.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  final List<double> scores;

  static const int _ringCount = 4;

  _RadarGridPainter(this.scores);

  @override
  void paint(Canvas canvas, Size size) {
    final axisCount = scores.length;
    if (axisCount < 3) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    double angleOf(int index) =>
        -math.pi / 2 + index * (2 * math.pi / axisCount);

    Offset pointAt(int index, double fraction) {
      final angle = angleOf(index);
      return center +
          Offset(math.cos(angle), math.sin(angle)) * radius * fraction;
    }

    Path polygonAt(double fraction) {
      final path = Path();
      for (var i = 0; i < axisCount; i++) {
        final p = pointAt(i, fraction);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      return path;
    }

    final gridPaint = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var ring = 1; ring <= _ringCount; ring++) {
      canvas.drawPath(polygonAt(ring / _ringCount), gridPaint);
    }
    for (var i = 0; i < axisCount; i++) {
      canvas.drawLine(center, pointAt(i, 1), gridPaint);
    }

    final dataPath = Path();
    for (var i = 0; i < axisCount; i++) {
      final p = pointAt(i, scores[i].clamp(0.0, 1.0));
      i == 0 ? dataPath.moveTo(p.dx, p.dy) : dataPath.lineTo(p.dx, p.dy);
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppColors.accentTint
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final dotPaint = Paint()..color = AppColors.accent;
    for (var i = 0; i < axisCount; i++) {
      canvas.drawCircle(pointAt(i, scores[i].clamp(0.0, 1.0)), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) =>
      oldDelegate.scores != scores;
}
