import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Wraps a scrolling [child] (typically a horizontal `ListView`) and fades
/// its content to transparent at whichever edge still has off-screen
/// content — so a partly-scrolled card dissolves into the page instead of
/// being hard-clipped. The fade ramps in over the first [fadeWidth] px of
/// scroll past each edge.
///
/// Pass the child's [controller] so the fade stays correct after silent
/// position changes (content added/removed) that don't emit a scroll
/// notification.
///
/// Unlike [EdgeFadeScrim] (an opaque same-color veil, for rows on a solid
/// background), this is a `ShaderMask` alpha fade — right for a carousel
/// sitting directly on the page background with no fill of its own.
class EdgeFadeMask extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;

  /// Distance (px) over which each edge ramps from clear to fully faded.
  final double fadeWidth;

  /// Whether the leading (left) / trailing (right) edge fades at all. Turn
  /// the leading fade off when snapping already keeps the first card whole.
  final bool startFade;
  final bool endFade;

  const EdgeFadeMask({
    super.key,
    required this.child,
    this.controller,
    this.fadeWidth = 24,
    this.startFade = true,
    this.endFade = true,
  });

  @override
  State<EdgeFadeMask> createState() => _EdgeFadeMaskState();
}

class _EdgeFadeMaskState extends State<EdgeFadeMask> {
  // 0 = clear, 1 = fully faded, for the start (left) and end (right) edges.
  double _startAmount = 0;
  double _endAmount = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_syncFromController);
  }

  @override
  void didUpdateWidget(EdgeFadeMask oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_syncFromController);
      widget.controller?.addListener(_syncFromController);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_syncFromController);
    super.dispose();
  }

  void _syncFromController() {
    final controller = widget.controller;
    if (controller != null && controller.hasClients) {
      _apply(controller.position);
    }
  }

  void _apply(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return;
    final start = (metrics.extentBefore / widget.fadeWidth).clamp(0.0, 1.0);
    final end = (metrics.extentAfter / widget.fadeWidth).clamp(0.0, 1.0);
    if ((start - _startAmount).abs() <= 0.01 &&
        (end - _endAmount).abs() <= 0.01) {
      return;
    }
    void update() {
      if (mounted) {
        setState(() {
          _startAmount = start;
          _endAmount = end;
        });
      }
    }

    // A `ScrollMetricsNotification` (content grew/shrank) is dispatched during
    // layout, where `setState` is illegal — defer it to the frame's end.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => update());
    } else {
      update();
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFromController();
    });
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) {
        _apply(n.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          _apply(n.metrics);
          return false;
        },
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(end: Offset(_startAmount, _endAmount)),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          builder: (context, amounts, child) {
            final startT = widget.startFade ? amounts.dx.clamp(0.0, 1.0) : 0.0;
            final endT = widget.endFade ? amounts.dy.clamp(0.0, 1.0) : 0.0;
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) {
                final width = rect.width;
                final ramp = width <= 0
                    ? 0.0
                    : (widget.fadeWidth / width).clamp(0.0, 0.5);
                final startStop = startT * ramp;
                final endStop = (1.0 - endT * ramp).clamp(startStop, 1.0);
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    Color(0x00FFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0x00FFFFFF),
                  ],
                  stops: [0.0, startStop, endStop, 1.0],
                ).createShader(rect);
              },
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
