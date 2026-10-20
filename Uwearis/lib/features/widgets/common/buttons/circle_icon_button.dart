import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';

/// Glass-disc icon button for in-page round icon actions. The tap target is
/// padded to at least [AppDimens.minTouchTarget]; [discAlignment] places
/// the disc inside it (`centerRight` aligns it with a row's end).
///
/// A null [onPressed] keeps the active look without handling taps — e.g. as
/// an `AppPopupMenu` trigger, which handles the tap itself.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final String? tooltip;
  final Alignment discAlignment;

  /// Diameter of the disc; the glyph renders at half this unless
  /// [iconSize] is set.
  final double size;
  final double? iconSize;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.tooltip,
    this.discAlignment = Alignment.center,
    this.size = 32,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.icon : AppColors.hintText;
    final button = Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        // Near-misses only: the arena gives a direct hit to the inner
        // InkWell, so onPressed never fires twice.
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: SizedBox.square(
          dimension: math.max(size, AppDimens.minTouchTarget),
          child: Align(
            alignment: discAlignment,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Fade to clear *white*: Colors.transparent is clear black
                // and would grey the blend.
                gradient: RadialGradient(
                  colors: [
                    AppColors.iconButtonFillCenter,
                    AppColors.iconButtonFillCenter.withValues(alpha: 0),
                    AppColors.iconButtonFillEdge,
                  ],
                  stops: const [0, 0.7, 1],
                ),
                // Outer-only, so it doesn't grey the translucent fill.
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowResting,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                    blurStyle: BlurStyle.outer,
                  ),
                ],
              ),
              position: DecorationPosition.background,
              child: DecoratedBox(
                // Top sheen — reads on white too, since the edge under it
                // is darker than the card.
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.iconButtonRim,
                    width: 0.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.iconButtonSheen,
                      AppColors.iconButtonSheen.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.45],
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: enabled ? onPressed : null,
                    child: SizedBox.square(
                      dimension: size,
                      child: Center(
                        child: Icon(
                          icon,
                          size: iconSize ?? size / 2,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final label = tooltip;
    return label == null ? button : Tooltip(message: label, child: button);
  }
}
