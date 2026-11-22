import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../adaptive_side_layout.dart';

/// [valueLabel] names the pole [score] (0.0-1.0) leans toward.
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

/// Read-only radar chart of the learned style-taste dimensions, with each
/// axis's label just outside its vertex. When the labels at the current
/// text size would collide with the plot or each other, the vertices keep
/// only their icons and the labels move to a list under the chart.
class StyleTasteRadarChart extends StatelessWidget {
  final List<StyleTasteRadarAxis> axes;
  final double size;

  /// Leaves enough margin for the axis labels outside the plot.
  static const double _radiusFraction = 0.30;
  static const double _labelBlockWidth = 78;
  static const double _labelGap = 10;
  static const double _iconSize = 18;
  static const double _iconGap = 3;

  static const TextStyle _titleStyle = AppTextStyle.bold12;

  const StyleTasteRadarChart({
    super.key,
    required this.axes,
    required this.size,
  });

  double get _chartRadius => size * _radiusFraction;
  Offset get _center => Offset(size / 2, size / 2);

  double _angleOf(int index) =>
      -math.pi / 2 + index * (2 * math.pi / axes.length);

  Offset _vertexAt(int index, double radius) {
    final angle = _angleOf(index);
    return _center + Offset(math.cos(angle), math.sin(angle)) * radius;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final blockWidth = scaler.scale(_labelBlockWidth);
    final blocks = _labelBlocks(scaler, blockWidth);
    if (blocks != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            _buildPlot(_chartRadius),
            for (var i = 0; i < axes.length; i++)
              Positioned.fromRect(
                rect: blocks[i],
                child: _buildAxisLabel(axes[i]),
              ),
          ],
        ),
      );
    }
    return _buildStacked();
  }

  /// Each label's rect beside its vertex, or null when any would overlap
  /// the plot or another label, or a title word doesn't fit the block.
  List<Rect>? _labelBlocks(TextScaler scaler, double blockWidth) {
    final rects = <Rect>[];
    for (var i = 0; i < axes.length; i++) {
      final axis = axes[i];
      if (longestLatinWordWidth(axis.title, _titleStyle, scaler) > blockWidth) {
        return null;
      }
      final title = _layoutText(axis.title, scaler, blockWidth, maxLines: 2);
      final value = _layoutText(axis.valueLabel, scaler, blockWidth);
      if (title.didExceedMaxLines || value.didExceedMaxLines) {
        title.dispose();
        value.dispose();
        return null;
      }
      final height = _iconSize + _iconGap + title.height + value.height;
      title.dispose();
      value.dispose();
      if (blockWidth > size || height > size) return null;

      final angle = _angleOf(i);
      final direction = Offset(math.cos(angle), math.sin(angle));
      final anchor = _vertexAt(i, _chartRadius) + direction * _labelGap;
      final left = _outwardOffset(
        anchor.dx,
        direction.dx,
        blockWidth,
      ).clamp(0.0, size - blockWidth);
      final top = _outwardOffset(
        anchor.dy,
        direction.dy,
        height,
      ).clamp(0.0, size - height);
      rects.add(Rect.fromLTWH(left, top, blockWidth, height));
    }
    final plot = Rect.fromCircle(center: _center, radius: _chartRadius);
    for (var i = 0; i < rects.length; i++) {
      if (_overlapsPlot(rects[i], plot)) return null;
      for (var j = i + 1; j < rects.length; j++) {
        if (rects[i].overlaps(rects[j])) return null;
      }
    }
    return rects;
  }

  /// Allows a label to graze the outer ring's corner the way the 1.0×
  /// layout always has, not to reach into the plot.
  bool _overlapsPlot(Rect label, Rect plot) {
    final inner = plot.deflate(plot.width * 0.12);
    return label.overlaps(inner);
  }

  TextPainter _layoutText(
    String text,
    TextScaler scaler,
    double width, {
    int maxLines = 1,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: _titleStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: scaler,
      maxLines: maxLines,
    )..layout(maxWidth: width);
  }

  /// Grows the label away from the vertex so it never overlaps the chart.
  /// [align] (-1..1): +1 starts at the anchor, -1 ends there, 0 centers.
  double _outwardOffset(double anchor, double align, double blockExtent) {
    return anchor - (blockExtent / 2) * (1 - align);
  }

  Widget _buildPlot(double radius) {
    return Positioned(
      left: _center.dx - radius,
      top: _center.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: CustomPaint(
        painter: _RadarGridPainter([for (final axis in axes) axis.score]),
      ),
    );
  }

  Widget _buildAxisLabel(StyleTasteRadarAxis axis) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(axis.icon, size: _iconSize, color: AppColors.textPrimary),
        const SizedBox(height: _iconGap),
        Text(
          axis.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: _titleStyle,
        ),
        Text(
          axis.valueLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: _titleStyle.copyWith(color: AppColors.accent),
        ),
      ],
    );
  }

  /// Icons at the vertices; titles and values listed underneath.
  Widget _buildStacked() {
    const iconInset = _iconSize + _labelGap;
    final radius = size / 2 - iconInset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              _buildPlot(radius),
              for (var i = 0; i < axes.length; i++)
                Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center: _vertexAt(i, radius + _iconSize / 2 + 4),
                    width: _iconSize,
                    height: _iconSize,
                  ),
                  child: Icon(
                    axes[i].icon,
                    size: _iconSize,
                    color: AppColors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final axis in axes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(axis.icon, size: _iconSize, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    children: [
                      Text(axis.title, style: _titleStyle),
                      Text(
                        axis.valueLabel,
                        style: _titleStyle.copyWith(color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
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
