import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';

/// Circular icon badge for a card corner. The tap target is padded out to
/// [hitTargetSize] (default: `max(size, AppDimens.minTouchTarget)` square);
/// set [discAlignment] to the anchored corner so the padding grows inward.
/// The default drop shadow suits photos; pass [border] and
/// `boxShadow: const []` for a flat badge on a plain card.
class CardCornerBadge extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Alignment discAlignment;
  final Size? hitTargetSize;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const CardCornerBadge({
    super.key,
    required this.icon,
    this.backgroundColor = AppColors.surface,
    this.iconColor = AppColors.icon,
    this.onTap,
    this.size = 24,
    this.iconSize = 14,
    this.discAlignment = Alignment.center,
    this.hitTargetSize,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final target =
        hitTargetSize ?? Size.square(math.max(size, AppDimens.minTouchTarget));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.fromSize(
        size: target,
        child: Align(
          alignment: discAlignment,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: border,
              boxShadow:
                  boxShadow ??
                  [BoxShadow(color: AppColors.shadowSoft, blurRadius: 4)],
            ),
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }
}
