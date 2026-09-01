import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Full-screen blocking overlay for long-running AI/generation waits (a
/// few seconds or more) — a blurred scrim with the branded "blooming
/// flower" animation and a label. Brief network reads (list fetches, page
/// loads) should use `AppSpinner` instead; using this everywhere made
/// short reads feel slower than they actually are. The flower animation
/// itself is private to this file on purpose, so it can't be reused
/// standalone elsewhere and drift back into that same overuse.
class LoadingOverlay extends StatefulWidget {
  final String label;

  const LoadingOverlay({super.key, required this.label});

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> {
  static const _dotInterval = Duration(milliseconds: 400);
  // Wide enough for 3 dots at AppTextStyle.bold16 — reserved so the dots
  // growing/shrinking never shifts the label text next to them.
  static const _dotsWidth = 18.0;

  late final Timer _timer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      _dotInterval,
      (_) => setState(() => _dotCount = (_dotCount + 1) % 4),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Labels come from l10n already ending in "…" (or "..."), so this
  /// strips that off — the trailing dots are re-added below, animated.
  String get _baseLabel {
    final text = widget.label.trimRight();
    if (text.endsWith('…')) return text.substring(0, text.length - 1);
    if (text.endsWith('...')) return text.substring(0, text.length - 3);
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTextStyle.bold16.copyWith(
      color: AppColors.textOnPrimary,
      decoration: TextDecoration.none,
    );
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Container(
        color: AppColors.overlayScrim,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PetalLoader(size: 90),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_baseLabel, style: textStyle),
                const SizedBox(width: 1),
                SizedBox(
                  width: _dotsWidth,
                  child: Text('.' * _dotCount, style: textStyle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Uwearis's signature "blooming flower" loading animation: petals grow
/// outward from the center in sequence (staggered start, eased growth),
/// hold at full length briefly, then all retract together — then repeats.
/// Private to [LoadingOverlay], the only place it's meant to appear.
class _PetalLoader extends StatefulWidget {
  final double size;

  const _PetalLoader({required this.size});

  @override
  State<_PetalLoader> createState() => _PetalLoaderState();
}

class _PetalLoaderState extends State<_PetalLoader>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1800);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _PetalLoaderPainter(progress: _controller.value),
          ),
        ),
      ),
    );
  }
}

class _PetalLoaderPainter extends CustomPainter {
  const _PetalLoaderPainter({required this.progress});

  final double progress;

  static const int petalCount = 8;
  static const _color = AppColors.accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final unit = size.shortestSide / 160;

    final centerRadius = 16 * unit;
    final petalWidth = 20 * unit;
    final petalLength = 34 * unit;
    final petalRadius = 20 * unit;

    final centerPaint = Paint()
      ..color = _color
      ..style = PaintingStyle.fill;

    final petalPaint = Paint()
      ..color = _color
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Center circle
    canvas.drawCircle(Offset.zero, centerRadius, centerPaint);

    // 8 outer petals
    for (int index = 0; index < petalCount; index++) {
      final angle = (math.pi * 2 / petalCount) * index;

      final petalProgress = _calculatePetalProgress(index);
      final easedProgress = Curves.easeOutCubic.transform(petalProgress);

      // Grow each petal outward from the end nearest the center
      final currentLength = petalLength * easedProgress;

      if (currentLength <= 0.01) continue;

      canvas.save();
      canvas.rotate(angle);

      // Tapered petal: narrow where it meets the center, widening toward
      // the outer tip — a trapezoid body unioned with a circle at the tip
      // so the wide end reads as a rounded cap rather than a hard corner.
      final innerHalfWidth = petalWidth * 0.28;
      final outerHalfWidth = petalWidth * 0.5;
      final yInner = -petalRadius;
      final tipCenterY = -(petalRadius + currentLength) + outerHalfWidth;

      final body = Path()
        ..moveTo(-innerHalfWidth, yInner)
        ..lineTo(-outerHalfWidth, tipCenterY)
        ..lineTo(outerHalfWidth, tipCenterY)
        ..lineTo(innerHalfWidth, yInner)
        ..close();
      final tipCap = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(0, tipCenterY),
            radius: outerHalfWidth,
          ),
        );

      canvas.drawPath(
        Path.combine(PathOperation.union, body, tipCap),
        petalPaint,
      );

      canvas.restore();
    }

    canvas.restore();
  }

  double _calculatePetalProgress(int index) {
    // First 60%: petals grow in sequence
    // Middle 15%: hold fully grown
    // Last 25%: all retract together
    const growEnd = 0.60;
    const holdEnd = 0.75;

    if (progress < growEnd) {
      final stagger = index / petalCount;
      final localStart = stagger * 0.42;
      const growthDuration = 0.28;

      final localProgress = ((progress - localStart) / growthDuration).clamp(
        0.0,
        1.0,
      );

      return localProgress;
    }

    if (progress < holdEnd) {
      return 1;
    }

    final retractProgress = ((progress - holdEnd) / (1 - holdEnd)).clamp(
      0.0,
      1.0,
    );

    return 1 - Curves.easeInCubic.transform(retractProgress);
  }

  @override
  bool shouldRepaint(covariant _PetalLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
