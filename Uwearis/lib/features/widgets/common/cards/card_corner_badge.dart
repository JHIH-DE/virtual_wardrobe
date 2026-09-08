import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';

/// Small circular icon badge (with shadow) meant to sit in the corner of a
/// card via [Positioned] — e.g. a remove / favorite / lock marker.
///
/// The visible disc stays [size] wide, but the tap target is padded out
/// (transparently). [discAlignment] places the disc inside that larger box:
/// pass the corner a `Positioned` badge is anchored to (`Alignment.topRight`
/// for a `top` + `right` badge) so the disc doesn't move and the extra
/// tappable band just grows inward.
///
/// [hitTargetSize] overrides the default square of
/// `max(size, AppDimens.minTouchTarget)` — pass a tall-but-narrow size for a
/// badge packed tightly beside another in a row, where there's vertical room
/// to grow but no horizontal room.
///
/// By default the disc carries a soft drop shadow (it usually sits on a
/// photo). Pass [border] + `boxShadow: const []` for a flatter badge on a
/// plain card, where a hairline edge reads better than a shadow.
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
        hitTargetSize ??
        Size.square(math.max(size, AppDimens.minTouchTarget));
    return GestureDetector(
      // opaque so the transparent band around the disc is tappable too.
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
