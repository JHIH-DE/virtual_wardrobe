import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Full-screen blocking overlay for long AI/generation waits. Brief reads
/// should use `AppSpinner`: this one makes short waits feel slower.
class LoadingOverlay extends StatefulWidget {
  final String label;

  const LoadingOverlay({super.key, required this.label});

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> {
  static const _dotInterval = Duration(milliseconds: 400);

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

  /// Strips the label's own "…"/"..." so the dots can be animated.
  String get _baseLabel {
    final text = widget.label.trimRight();
    if (text.endsWith('…')) return text.substring(0, text.length - 1);
    if (text.endsWith('...')) return text.substring(0, text.length - 3);
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTextStyle.bold16.copyWith(
      color: AppColors.accent,
      decoration: TextDecoration.none,
    );
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Container(
        // Non-null color makes it a hit target, blocking taps underneath.
        color: Colors.transparent,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SpokeSpinner(size: 90),
            const SizedBox(height: 4),
            // Hidden dots are painted transparent so the width never jitters.
            Text.rich(
              TextSpan(
                style: textStyle,
                children: [
                  TextSpan(text: _baseLabel),
                  TextSpan(text: '.' * _dotCount),
                  TextSpan(
                    text: '.' * (3 - _dotCount),
                    style: const TextStyle(color: Color(0x00000000)),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Private to [LoadingOverlay] on purpose, so it isn't reused for brief
/// loads.
class _SpokeSpinner extends StatefulWidget {
  final double size;

  const _SpokeSpinner({required this.size});

  @override
  State<_SpokeSpinner> createState() => _SpokeSpinnerState();
}

class _SpokeSpinnerState extends State<_SpokeSpinner>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1000);

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
            painter: _SpokeSpinnerPainter(progress: _controller.value),
          ),
        ),
      ),
    );
  }
}

class _SpokeSpinnerPainter extends CustomPainter {
  const _SpokeSpinnerPainter({required this.progress});

  /// 0..1, one full revolution per cycle.
  final double progress;

  static const _color = AppColors.accent;
  static const _spokeCount = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final unit = size.shortestSide;

    final innerRadius = unit * 0.2;
    final outerRadius = unit * 0.3;
    final strokeWidth = unit * 0.075;

    // The bright spoke steps (doesn't glide) one slot per 1/12 cycle.
    final active = (progress * _spokeCount).floor() % _spokeCount;

    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _spokeCount; i++) {
      // How many slots this spoke sits behind the bright one (0 = bright).
      final behind = (active - i) % _spokeCount;
      final opacity = 1.0 - 0.83 * (behind / (_spokeCount - 1));

      final angle = (i / _spokeCount) * 2 * math.pi - math.pi / 2;
      final dir = Offset(math.cos(angle), math.sin(angle));

      canvas.drawLine(
        center + dir * innerRadius,
        center + dir * outerRadius,
        paint..color = _color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpokeSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
