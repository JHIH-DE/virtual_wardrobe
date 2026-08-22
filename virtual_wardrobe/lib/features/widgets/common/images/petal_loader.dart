import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Tracks how many [LoadingOverlay]s are currently mounted anywhere in the
/// app. Independent [PetalLoader]s elsewhere on screen (e.g. image
/// placeholders) watch this to pause themselves while a full-screen
/// LoadingOverlay is already animating its own — otherwise the user would
/// be looking at a dozen small flowers pulsing away underneath the big one,
/// which reads as noisy rather than premium and wastes GPU work on content
/// that's mostly hidden behind the overlay's scrim/blur anyway.
class LoadingOverlayActivity {
  LoadingOverlayActivity._();

  static final ValueNotifier<int> activeCount = ValueNotifier(0);
}

/// LUMI's signature "blooming flower" loading animation: petals grow
/// outward from the center in sequence (staggered start, eased growth),
/// hold at full length briefly, then all retract together — then repeats.
///
/// Used both as [LoadingOverlay]'s own centerpiece and as the placeholder
/// for individual images loading elsewhere on screen (see
/// [RefreshableNetworkImage]) — [pausable] distinguishes the two: an
/// image's own loader should freeze while a LoadingOverlay is active
/// (rather than animate uselessly underneath it), but LoadingOverlay's own
/// instance obviously shouldn't pause itself just because it's the very
/// overlay that's active.
class PetalLoader extends StatefulWidget {
  final double size;
  final bool pausable;

  const PetalLoader({super.key, this.size = 48, this.pausable = true});

  @override
  State<PetalLoader> createState() => _PetalLoaderState();
}

class _PetalLoaderState extends State<PetalLoader>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1800);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    if (widget.pausable) {
      LoadingOverlayActivity.activeCount.addListener(_syncWithActivity);
      _syncWithActivity();
    } else {
      _controller.repeat();
    }
  }

  void _syncWithActivity() {
    final shouldPause = LoadingOverlayActivity.activeCount.value > 0;
    if (shouldPause) {
      if (_controller.isAnimating) _controller.stop();
    } else {
      if (!_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    if (widget.pausable) {
      LoadingOverlayActivity.activeCount.removeListener(_syncWithActivity);
    }
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
