import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One slice of a [StyleProfilePieChart] — [color] should come from
/// `AppColors.chartCategorical` (or `AppColors.chartOther` for a folded
/// "everything else" bucket), never an ad hoc hue.
class StyleProfileSlice {
  final String label;
  final int count;
  final Color color;

  const StyleProfileSlice({
    required this.label,
    required this.count,
    required this.color,
  });
}

/// Read-only donut chart for Style Taste's "outfits per style" breakdown —
/// part-to-whole at a glance only (see the dataviz skill's guidance: a
/// donut is for that, not for comparing close values). Exact counts belong
/// in a legend next to it, not on the chart itself — a slice's color is
/// never the only way to identify it.
class StyleProfilePieChart extends StatelessWidget {
  final List<StyleProfileSlice> slices;
  final double size;

  /// Rendered in the donut's hollow center (e.g. the total count).
  final Widget? center;

  const StyleProfilePieChart({
    super.key,
    required this.slices,
    required this.size,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(slices: slices),
          ),
          ?center,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<StyleProfileSlice> slices;

  // Ring thickness as a fraction of the chart's radius.
  static const double _strokeFraction = 0.32;
  // Angular surface gap between adjacent slices — the curved-stroke
  // approximation of the mark spec's 2px surface gap between fills.
  static const double _gapRadians = 4 * math.pi / 180;

  const _DonutPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.count);
    if (total <= 0) return;

    final radius = size.shortestSide / 2;
    final strokeWidth = radius * _strokeFraction;
    final arcRect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius - strokeWidth / 2,
    );

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      if (slice.count <= 0) continue;
      final sweep = (slice.count / total) * 2 * math.pi;
      // A single slice spanning the full circle has no neighbor to gap
      // against; anything else gets a flat cut on each side.
      final visibleSweep = slices.length == 1
          ? sweep
          : (sweep - _gapRadians).clamp(0.0, sweep);
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        arcRect,
        startAngle + _gapRadians / 2,
        visibleSweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}
