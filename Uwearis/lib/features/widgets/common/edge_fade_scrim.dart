import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Overlays a short same-color scrim on each edge of [child] (a
/// horizontally-scrolling row) so content sliding past doesn't end
/// abruptly at the row's border. Uses a same-color gradient rather than a
/// ShaderMask blend — blending against the row's own colors made the fade
/// look washed out / flash white during scroll.
///
/// [leftVisible]/[rightVisible] let a scroll-position listener hide
/// whichever edge scrim has nothing left to fade (e.g. already scrolled all
/// the way to that edge) — both default to always-visible. [leftIcon]/
/// [rightIcon] optionally overlay a directional hint (e.g. a chevron)
/// centered in that edge's scrim.
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
