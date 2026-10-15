import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Edge fades for a horizontal scroll row. A same-color gradient, not a
/// ShaderMask: blending made the fade look washed out and flash white.
/// [leftVisible]/[rightVisible] hide an edge with nothing left to scroll.
class EdgeFadeScrim extends StatelessWidget {
  final Widget child;
  final double edgeWidth;
  final bool leftVisible;
  final bool rightVisible;
  final IconData? leftIcon;
  final IconData? rightIcon;

  const EdgeFadeScrim({
    super.key,
    required this.child,
    this.edgeWidth = 24,
    this.leftVisible = true,
    this.rightVisible = true,
    this.leftIcon,
    this.rightIcon,
  });

  Widget _scrim(Alignment begin, Alignment end, IconData? icon, bool visible) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: visible ? 1 : 0,
        child: Container(
          width: edgeWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [
                AppColors.surface,
                AppColors.surface.withValues(alpha: 0),
              ],
            ),
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: 28,
                  color: AppColors.icon.withValues(alpha: 0.4),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: _scrim(
            Alignment.centerLeft,
            Alignment.centerRight,
            leftIcon,
            leftVisible,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: _scrim(
            Alignment.centerRight,
            Alignment.centerLeft,
            rightIcon,
            rightVisible,
          ),
        ),
      ],
    );
  }
}
